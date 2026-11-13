//! Sample browser folders: Rust scans and watches them, Flutter renders the trees it receives.

use std::path::PathBuf;

use anyhow::anyhow;
use flutter_rust_bridge::frb;
use karbeat_core_api::sample_browser_api::{
    SampleFile, SampleFolderEvent, SampleLibrary, SampleTree,
};
use parking_lot::Mutex;

use crate::{api::settings, frb_generated::StreamSink};

/// The watched sample folders, once [`watch_sample_folders`] has run.
static SAMPLE_LIBRARY: Mutex<Option<SampleLibrary>> = Mutex::new(None);

/// An audio file in the sample browser.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiSampleFile {
    pub name: String,
    pub path: String,
}

/// A sample browser folder with its child folders and audio files, each sorted by name.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiSampleTree {
    pub name: String,
    pub path: String,
    pub directories: Vec<UiSampleTree>,
    pub samples: Vec<UiSampleFile>,
}

/// A change to the sample browser's folders.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub enum UiSampleFolderEvent {
    /// A folder was scanned, at startup or after its files changed.
    Scanned { tree: UiSampleTree },
    /// A folder is missing or unreadable and is not shown; it stays saved for later sessions.
    Unavailable { path: String },
    /// Every saved folder has been scanned once.
    Restored,
}

impl From<SampleFile> for UiSampleFile {
    fn from(file: SampleFile) -> Self {
        Self {
            name: file.name,
            path: file.path.to_string_lossy().into_owned(),
        }
    }
}

impl From<SampleTree> for UiSampleTree {
    fn from(tree: SampleTree) -> Self {
        Self {
            name: tree.name,
            path: tree.path.to_string_lossy().into_owned(),
            directories: tree.directories.into_iter().map(Into::into).collect(),
            samples: tree.samples.into_iter().map(Into::into).collect(),
        }
    }
}

impl From<SampleFolderEvent> for UiSampleFolderEvent {
    fn from(event: SampleFolderEvent) -> Self {
        match event {
            SampleFolderEvent::Scanned(tree) => Self::Scanned { tree: tree.into() },
            SampleFolderEvent::Unavailable(path) => Self::Unavailable {
                path: path.to_string_lossy().into_owned(),
            },
        }
    }
}

fn send(sink: &StreamSink<UiSampleFolderEvent>, event: UiSampleFolderEvent) {
    if sink.add(event).is_err() {
        tracing::debug!("The sample browser stream has no listener");
    }
}

/// Scans every saved sample folder, then watches them and streams each folder whose files
/// change. Subscribing again replaces the previous stream and watches.
pub fn watch_sample_folders(sink: StreamSink<UiSampleFolderEvent>) -> anyhow::Result<()> {
    let folders = settings::sample_folders()?;
    let watcher_sink = sink.clone();
    let library = SampleLibrary::new(move |event| send(&watcher_sink, event.into()))?;

    let mut slot = SAMPLE_LIBRARY.lock();
    let library = slot.insert(library);
    for folder in folders {
        match library.add_folder(&folder) {
            Ok(tree) => send(&sink, UiSampleFolderEvent::Scanned { tree: tree.into() }),
            Err(error) => {
                // Kept saved: removable or network storage may return.
                tracing::warn!("Saved sample folder is unavailable: {error}");
                send(
                    &sink,
                    UiSampleFolderEvent::Unavailable {
                        path: folder.to_string_lossy().into_owned(),
                    },
                );
            }
        }
    }
    send(&sink, UiSampleFolderEvent::Restored);
    Ok(())
}

/// Scans, watches and saves `path`, returning its tree. Later changes arrive on the stream of
/// [`watch_sample_folders`], which must be running.
pub fn add_sample_folder(path: String) -> anyhow::Result<UiSampleTree> {
    let tree = SAMPLE_LIBRARY
        .lock()
        .as_mut()
        .ok_or_else(|| anyhow!("The sample browser is not watching folders yet"))?
        .add_folder(&PathBuf::from(path))?;
    settings::remember_sample_folder(tree.path.clone())?;
    Ok(tree.into())
}
