//! Sample browser folders: parallel scans of their audio files and file system watches that
//! rescan only the part of a folder that changed.

use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    fs::{canonicalize, read_dir},
    io,
    path::{Path, PathBuf},
    sync::Arc,
    time::Duration,
};

use ignore::{DirEntry, ParallelVisitor, ParallelVisitorBuilder, WalkBuilder, WalkState};
use notify_debouncer_full::{
    DebounceEventResult, Debouncer, RecommendedCache, new_debouncer,
    notify::{self, EventKind, RecommendedWatcher, RecursiveMode},
};
use parking_lot::Mutex;
use thiserror::Error;

/// File extensions, lowercase, of the audio files listed by the sample browser.
pub const SUPPORTED_EXTENSIONS: [&str; 9] = [
    "aac", "flac", "m4a", "mp3", "mp4", "ogg", "opus", "wav", "wave",
];

/// How long file system events settle before the affected folders are rescanned, so a copy of
/// many files triggers one rescan.
const WATCH_DEBOUNCE: Duration = Duration::from_millis(250);

/// An audio file inside a sample folder.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SampleFile {
    /// File name, shown in the browser.
    pub name: String,
    /// Absolute path.
    pub path: PathBuf,
}

/// A folder and every audio file below it. Hidden entries are left out.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SampleTree {
    /// Folder name, shown in the browser.
    pub name: String,
    /// Absolute path without symbolic links.
    pub path: PathBuf,
    /// Child folders, sorted by name ignoring case.
    pub directories: Vec<SampleTree>,
    /// Audio files directly inside this folder, sorted by name ignoring case.
    pub samples: Vec<SampleFile>,
}

/// A change to a watched sample folder.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SampleFolderEvent {
    /// The folder's contents changed; carries the whole updated folder.
    Scanned(SampleTree),
    /// The folder was removed or can no longer be read, and is no longer watched.
    Unavailable(PathBuf),
}

/// Why a sample folder cannot be scanned or watched.
#[derive(Debug, Error)]
pub enum SampleBrowserError {
    /// The folder does not exist or cannot be read.
    #[error("Sample folder {path} cannot be read: {source}")]
    Unreadable {
        /// The folder as given.
        path: PathBuf,
        /// The file system error.
        #[source]
        source: io::Error,
    },
    /// The path exists but is not a folder.
    #[error("{path} is not a folder")]
    NotAFolder {
        /// The path as given.
        path: PathBuf,
    },
    /// The file system watcher could not be started or could not watch the folder.
    #[error("Cannot watch sample folder {path}: {source}")]
    Watch {
        /// The folder, or empty when the watcher itself failed to start.
        path: PathBuf,
        /// The watcher error.
        #[source]
        source: notify::Error,
    },
}

/// Scans `path` and every folder below it in parallel.
///
/// Unreadable child folders are skipped instead of failing the whole scan.
pub fn scan_folder(path: &Path) -> Result<SampleTree, SampleBrowserError> {
    let root = readable_folder(path)?;
    Ok(walk(&root))
}

/// Sample folders watched for changes.
///
/// Each debounced batch of file system events rescans only the deepest folders that changed,
/// splices them into the cached tree, and reports every folder whose tree actually changed.
pub struct SampleLibrary {
    folders: Arc<Mutex<BTreeMap<PathBuf, SampleTree>>>,
    debouncer: Debouncer<RecommendedWatcher, RecommendedCache>,
}

impl SampleLibrary {
    /// Starts the watcher. `on_event` runs on the watcher's thread for every changed folder.
    pub fn new(
        on_event: impl Fn(SampleFolderEvent) + Send + 'static,
    ) -> Result<Self, SampleBrowserError> {
        let folders = Arc::new(Mutex::new(BTreeMap::new()));
        let watched = Arc::clone(&folders);
        let debouncer =
            new_debouncer(
                WATCH_DEBOUNCE,
                None,
                move |result: DebounceEventResult| match result {
                    Ok(events) => {
                        let paths = events
                            .iter()
                            .filter(|event| !matches!(event.kind, EventKind::Access(_)))
                            .flat_map(|event| event.paths.iter().map(PathBuf::as_path));
                        for event in refresh(&mut watched.lock(), paths) {
                            on_event(event);
                        }
                    }
                    Err(errors) => {
                        for error in errors {
                            tracing::warn!("Sample folder watcher error: {error}");
                        }
                    }
                },
            )
            .map_err(|source| SampleBrowserError::Watch {
                path: PathBuf::new(),
                source,
            })?;
        Ok(Self { folders, debouncer })
    }

    /// Scans `path`, starts watching it, and returns its tree. Adding a folder again rescans it.
    pub fn add_folder(&mut self, path: &Path) -> Result<SampleTree, SampleBrowserError> {
        let root = readable_folder(path)?;
        // Held across watch and scan so no event slips between them unprocessed.
        let mut folders = self.folders.lock();
        let is_new = !folders.contains_key(&root);
        if is_new {
            self.debouncer
                .watch(&root, RecursiveMode::Recursive)
                .map_err(|source| SampleBrowserError::Watch {
                    path: root.clone(),
                    source,
                })?;
        }
        let tree = walk(&root);
        folders.insert(root, tree.clone());
        Ok(tree)
    }
}

fn readable_folder(path: &Path) -> Result<PathBuf, SampleBrowserError> {
    let unreadable = |source| SampleBrowserError::Unreadable {
        path: path.to_path_buf(),
        source,
    };
    let root = canonicalize(path).map_err(unreadable)?;
    if !root.is_dir() {
        return Err(SampleBrowserError::NotAFolder {
            path: path.to_path_buf(),
        });
    }
    read_dir(&root).map_err(unreadable)?;
    Ok(root)
}

/// Applies one batch of changed `paths` to the watched `folders`.
fn refresh<'a>(
    folders: &mut BTreeMap<PathBuf, SampleTree>,
    paths: impl Iterator<Item = &'a Path>,
) -> Vec<SampleFolderEvent> {
    let mut targets: BTreeMap<PathBuf, BTreeSet<PathBuf>> = BTreeMap::new();
    for path in paths {
        // Nested sample folders both list the changed file.
        for root in folders.keys().filter(|root| path.starts_with(root)) {
            if let Some(target) = changed_directory(root, path) {
                targets.entry(root.clone()).or_default().insert(target);
            }
        }
    }

    let mut events = Vec::new();
    for (root, targets) in targets {
        let Some(tree) = folders.get_mut(&root) else {
            continue;
        };
        if !root.is_dir() {
            tracing::warn!("Sample folder {} is no longer available", root.display());
            folders.remove(&root);
            events.push(SampleFolderEvent::Unavailable(root));
            continue;
        }
        let previous = tree.clone();
        for target in outermost(targets) {
            let target = existing_ancestor(&root, &target);
            let subtree = walk(&target);
            if !splice(tree, subtree) {
                *tree = walk(&root);
                break;
            }
        }
        if *tree != previous {
            events.push(SampleFolderEvent::Scanned(tree.clone()));
        }
    }
    events
}

/// The folder to rescan for a change at `path` inside `root`, or `None` when the change cannot
/// alter the browser: hidden entries and files that are not audio.
fn changed_directory(root: &Path, path: &Path) -> Option<PathBuf> {
    let relative = path.strip_prefix(root).ok()?;
    let hidden = relative
        .components()
        .any(|component| component.as_os_str().to_string_lossy().starts_with('.'));
    if hidden || (path.is_file() && !is_supported_audio(path)) {
        return None;
    }
    if path == root {
        return Some(root.to_path_buf());
    }
    path.parent().map(Path::to_path_buf)
}

/// Drops every folder that lies inside another one of `targets`; its rescan covers them.
fn outermost(targets: BTreeSet<PathBuf>) -> Vec<PathBuf> {
    let mut kept: Vec<PathBuf> = Vec::new();
    // Sorted order puts every folder right after its ancestors.
    for target in targets {
        if !kept.last().is_some_and(|last| target.starts_with(last)) {
            kept.push(target);
        }
    }
    kept
}

/// `target`, or its nearest ancestor that still exists, never above `root`.
fn existing_ancestor(root: &Path, target: &Path) -> PathBuf {
    target
        .ancestors()
        .take_while(|ancestor| ancestor.starts_with(root))
        .find(|ancestor| ancestor.is_dir())
        .unwrap_or(root)
        .to_path_buf()
}

/// Replaces the node of `tree` at `subtree.path`; `false` when that node is not in `tree`.
fn splice(tree: &mut SampleTree, subtree: SampleTree) -> bool {
    if tree.path == subtree.path {
        *tree = subtree;
        return true;
    }
    match tree
        .directories
        .iter_mut()
        .find(|child| subtree.path.starts_with(&child.path))
    {
        Some(child) => splice(child, subtree),
        None => false,
    }
}

fn is_supported_audio(path: &Path) -> bool {
    path.extension()
        .map(|extension| extension.to_string_lossy().to_lowercase())
        .is_some_and(|extension| SUPPORTED_EXTENSIONS.contains(&extension.as_str()))
}

/// A folder or audio file found by a walk.
struct WalkedEntry {
    path: PathBuf,
    is_dir: bool,
}

/// Collects one walker thread's entries locally and hands them over once, when the thread ends.
struct EntryCollector<'a> {
    shared: &'a Mutex<Vec<WalkedEntry>>,
    local: Vec<WalkedEntry>,
}

impl ParallelVisitor for EntryCollector<'_> {
    fn visit(&mut self, entry: Result<DirEntry, ignore::Error>) -> WalkState {
        let entry = match entry {
            Ok(entry) => entry,
            Err(error) => {
                tracing::debug!("Skipping an unreadable sample folder entry: {error}");
                return WalkState::Continue;
            }
        };
        if entry.depth() == 0 {
            return WalkState::Continue;
        }
        let is_dir = entry
            .file_type()
            .is_some_and(|file_type| file_type.is_dir());
        if is_dir || is_supported_audio(entry.path()) {
            self.local.push(WalkedEntry {
                path: entry.into_path(),
                is_dir,
            });
        }
        WalkState::Continue
    }
}

impl Drop for EntryCollector<'_> {
    fn drop(&mut self) {
        self.shared.lock().append(&mut self.local);
    }
}

struct EntryCollectorBuilder<'a>(&'a Mutex<Vec<WalkedEntry>>);

impl<'s, 'a: 's> ParallelVisitorBuilder<'s> for EntryCollectorBuilder<'a> {
    fn build(&mut self) -> Box<dyn ParallelVisitor + 's> {
        Box::new(EntryCollector {
            shared: self.0,
            local: Vec::new(),
        })
    }
}

/// Walks `root` on every core, without following links or reading ignore files.
fn walk(root: &Path) -> SampleTree {
    let entries = Mutex::new(Vec::new());
    WalkBuilder::new(root)
        .standard_filters(false)
        .hidden(true)
        .follow_links(false)
        .build_parallel()
        .visit(&mut EntryCollectorBuilder(&entries));
    build_tree(root, entries.into_inner())
}

#[derive(Default)]
struct FolderContents {
    directories: Vec<PathBuf>,
    samples: Vec<SampleFile>,
}

fn build_tree(root: &Path, entries: Vec<WalkedEntry>) -> SampleTree {
    let mut contents: HashMap<PathBuf, FolderContents> = HashMap::new();
    for entry in entries {
        let Some(parent) = entry.path.parent() else {
            continue;
        };
        let folder = contents.entry(parent.to_path_buf()).or_default();
        if entry.is_dir {
            folder.directories.push(entry.path);
        } else {
            folder.samples.push(SampleFile {
                name: file_name(&entry.path),
                path: entry.path,
            });
        }
    }
    assemble(root, &mut contents)
}

fn assemble(path: &Path, contents: &mut HashMap<PathBuf, FolderContents>) -> SampleTree {
    let FolderContents {
        directories,
        mut samples,
    } = contents.remove(path).unwrap_or_default();
    let mut directories: Vec<SampleTree> = directories
        .iter()
        .map(|directory| assemble(directory, contents))
        .collect();
    directories.sort_by_cached_key(|directory| sort_key(&directory.name));
    samples.sort_by_cached_key(|sample| sort_key(&sample.name));
    SampleTree {
        name: file_name(path),
        path: path.to_path_buf(),
        directories,
        samples,
    }
}

fn sort_key(name: &str) -> (String, String) {
    (name.to_lowercase(), name.to_owned())
}

fn file_name(path: &Path) -> String {
    path.file_name().map_or_else(
        || path.to_string_lossy().into_owned(),
        |name| name.to_string_lossy().into_owned(),
    )
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::indexing_slicing,
    clippy::panic,
    reason = "tests fail immediately when temporary file I/O breaks"
)]
mod tests {
    use std::{
        fs::{create_dir, create_dir_all, remove_dir, remove_file, write},
        sync::mpsc::{Receiver, channel},
    };

    use tempfile::tempdir;

    use super::*;

    fn names(tree: &SampleTree) -> (Vec<&str>, Vec<&str>) {
        (
            tree.directories.iter().map(|d| d.name.as_str()).collect(),
            tree.samples.iter().map(|s| s.name.as_str()).collect(),
        )
    }

    fn next_scan(events: &Receiver<SampleFolderEvent>) -> SampleTree {
        match events.recv_timeout(Duration::from_secs(10)).unwrap() {
            SampleFolderEvent::Scanned(tree) => tree,
            other => panic!("expected a rescan, got {other:?}"),
        }
    }

    #[test]
    fn scans_audio_files_sorted_and_skips_hidden_and_other_files() {
        let root = tempdir().unwrap();
        create_dir_all(root.path().join("Drums/Kicks")).unwrap();
        create_dir(root.path().join(".cache")).unwrap();
        for file in [
            "zeta.WAV",
            "Alpha.flac",
            "notes.txt",
            ".hidden.wav",
            ".cache/cached.wav",
            "Drums/Kicks/kick.mp3",
        ] {
            write(root.path().join(file), b"").unwrap();
        }

        let tree = scan_folder(root.path()).unwrap();

        assert_eq!(tree.path, canonicalize(root.path()).unwrap());
        assert_eq!(
            names(&tree),
            (vec!["Drums"], vec!["Alpha.flac", "zeta.WAV"])
        );
        let kicks = &tree.directories[0].directories[0];
        assert_eq!(names(kicks), (vec![], vec!["kick.mp3"]));
        assert_eq!(
            kicks.samples[0].path,
            tree.path.join("Drums/Kicks/kick.mp3")
        );
    }

    #[test]
    fn rejects_missing_folders_and_files() {
        let root = tempdir().unwrap();
        let file = root.path().join("kick.wav");
        write(&file, b"").unwrap();

        assert!(matches!(
            scan_folder(&root.path().join("missing")),
            Err(SampleBrowserError::Unreadable { .. })
        ));
        assert!(matches!(
            scan_folder(&file),
            Err(SampleBrowserError::NotAFolder { .. })
        ));
    }

    #[test]
    fn refresh_rescans_only_changed_folders_and_ignores_other_files() {
        let root = tempdir().unwrap();
        create_dir(root.path().join("Drums")).unwrap();
        let tree = scan_folder(root.path()).unwrap();
        let root_path = tree.path.clone();
        let mut folders = BTreeMap::from([(root_path.clone(), tree)]);

        let notes = root_path.join("Drums/notes.txt");
        write(&notes, b"").unwrap();
        assert!(refresh(&mut folders, [notes.as_path()].into_iter()).is_empty());

        let kick = root_path.join("Drums/kick.wav");
        write(&kick, b"").unwrap();
        let events = refresh(&mut folders, [kick.as_path()].into_iter());
        let [SampleFolderEvent::Scanned(tree)] = events.as_slice() else {
            panic!("expected one rescan, got {events:?}");
        };
        assert_eq!(names(&tree.directories[0]), (vec![], vec!["kick.wav"]));

        // A folder created and filled in one batch is found through its parent.
        let snares = root_path.join("Snares");
        create_dir(&snares).unwrap();
        let snare = snares.join("snare.wav");
        write(&snare, b"").unwrap();
        let events = refresh(
            &mut folders,
            [snares.as_path(), snare.as_path()].into_iter(),
        );
        let [SampleFolderEvent::Scanned(tree)] = events.as_slice() else {
            panic!("expected one rescan, got {events:?}");
        };
        assert_eq!(names(tree), (vec!["Drums", "Snares"], vec![]));
        assert_eq!(names(&tree.directories[1]), (vec![], vec!["snare.wav"]));

        remove_file(&kick).unwrap();
        let events = refresh(&mut folders, [kick.as_path()].into_iter());
        let [SampleFolderEvent::Scanned(tree)] = events.as_slice() else {
            panic!("expected one rescan, got {events:?}");
        };
        assert!(tree.directories[0].samples.is_empty());
    }

    #[test]
    fn refresh_reports_a_removed_folder_as_unavailable() {
        let parent = tempdir().unwrap();
        let root = parent.path().join("Samples");
        create_dir(&root).unwrap();
        let tree = scan_folder(&root).unwrap();
        let root = tree.path.clone();
        let mut folders = BTreeMap::from([(root.clone(), tree)]);

        remove_dir(&root).unwrap();
        let events = refresh(&mut folders, [root.as_path()].into_iter());

        assert_eq!(events, [SampleFolderEvent::Unavailable(root)]);
        assert!(folders.is_empty());
    }

    #[test]
    fn watcher_reports_new_files() {
        let root = tempdir().unwrap();
        let (sender, events) = channel();
        let mut library = SampleLibrary::new(move |event| {
            sender.send(event).unwrap();
        })
        .unwrap();
        let tree = library.add_folder(root.path()).unwrap();
        assert!(tree.samples.is_empty());

        write(tree.path.join("kick.wav"), b"").unwrap();

        assert_eq!(names(&next_scan(&events)), (vec![], vec!["kick.wav"]));
    }
}
