use std::{
    collections::HashMap,
    fs::File,
    io::{BufReader, Read, Seek, Write},
    path::{Path, PathBuf},
    sync::Arc,
};

use anyhow::Context;
use rayon::prelude::*;
use zip::{CompressionMethod, ZipWriter, read::ZipArchive, write::SimpleFileOptions};

use crate::core::{
    file_manager::{app_cache_dir, audio_loader::load_audio_file, format::ProjectMigrator},
    project::{ApplicationState, AudioSourceId, AudioWaveform, CoverImage, ProjectMetadata},
};

/// Archive folder holding the embedded cover image.
const COVER_ARCHIVE_DIR: &str = "cover";

const KARBEAT_MAGIC_HEADER: &[u8; 8] = b"KARBEAT1";

pub fn save_daw_project(save_path: &Path, app_state: &ApplicationState) -> anyhow::Result<()> {
    let parent = save_path
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let mut temporary = tempfile::NamedTempFile::new_in(parent)?;
    let file = temporary.as_file_mut();
    file.write_all(KARBEAT_MAGIC_HEADER)?;

    // Clone the app state so we can modify file paths for embedded files
    let mut saveable_state = app_state.clone();
    let cover = app_state
        .metadata
        .cover
        .as_ref()
        .map(|cover| -> anyhow::Result<_> {
            let art = cover
                .load()
                .context("Failed to read the project cover image")?;
            let archive_path = format!("{COVER_ARCHIVE_DIR}/cover.{}", art.format().extension());
            // Point future loads at the file on this machine; a cover that was already
            // a fallback extraction keeps the link it came with
            let linked_path = cover
                .linked_path
                .clone()
                .or_else(|| Some(cover.path.clone()));
            Ok((art, archive_path, linked_path))
        })
        .transpose()?;
    if let Some((_, archive_path, linked_path)) = &cover {
        saveable_state.metadata.cover = Some(CoverImage {
            path: PathBuf::from(archive_path),
            linked_path: linked_path.clone(),
        });
    }
    let metadata_toml = toml::to_string(&saveable_state.metadata)?;

    let mut zip = ZipWriter::new(file);

    let deflated_options =
        SimpleFileOptions::default().compression_method(CompressionMethod::Deflated);
    let stored_options = SimpleFileOptions::default().compression_method(CompressionMethod::Stored);

    zip.start_file("metadata.toml", deflated_options)?;
    zip.write_all(metadata_toml.as_bytes())?;

    if let Some((art, archive_path, _)) = &cover {
        // JPEG and PNG are already compressed
        zip.start_file(archive_path.as_str(), stored_options)?;
        zip.write_all(art.bytes())?;
    }
    let library = &mut saveable_state.asset_library;

    zip.add_directory("audio/", stored_options)?;

    // Pre-filter and pre-allocate paths to keep the zip write loop as tight as possible.
    // Sources sharing a file (hard copies) embed it once and point at the first entry.
    let mut valid_sources = Vec::new();
    let mut shared_sources = Vec::new();
    let mut embedded_by_path: HashMap<PathBuf, String> = HashMap::new();
    for (id, audio_arc) in app_state.asset_library.source_map.iter() {
        let path = &audio_arc.file_path;
        if !path.as_os_str().is_empty() && path.is_file() {
            let canonical = std::fs::canonicalize(path).unwrap_or_else(|_| path.clone());
            if let Some(internal_name) = embedded_by_path.get(&canonical) {
                shared_sources.push((id, internal_name.clone()));
                continue;
            }
            let file_name = path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("sample.bin");
            let internal_name = format!("audio/{}_{}", id.to_u64(), file_name);
            embedded_by_path.insert(canonical, internal_name.clone());
            valid_sources.push((id, path.clone(), internal_name));
        }
    }

    // Write audio files to zip
    for (id, original_path, internal_name) in valid_sources {
        zip.start_file(&internal_name, stored_options)?;

        let source_audio_file = File::open(&original_path)
            .with_context(|| format!("Failed to open audio file: {}", original_path.display()))?;

        // Use a BufReader with a 128KB chunk size for much faster sequential disk reads
        let mut reader = BufReader::with_capacity(128 * 1024, source_audio_file);
        std::io::copy(&mut reader, &mut zip)?;

        // Rewrite the file path in the cloned state to use the zip-internal path
        if let Some(entry) = library.source_map.get_mut(id) {
            let waveform = Arc::make_mut(entry);
            waveform.file_path = internal_name.into();
        }
    }
    for (id, internal_name) in shared_sources {
        if let Some(entry) = library.source_map.get_mut(id) {
            Arc::make_mut(entry).file_path = internal_name.into();
        }
    }

    ProjectMigrator::write(&mut zip, &saveable_state, deflated_options)?;

    zip.finish()?.sync_all()?;
    temporary.persist(save_path).map_err(|error| error.error)?;
    Ok(())
}

pub fn load_daw_project(path: &Path, sample_rate: u32) -> anyhow::Result<ApplicationState> {
    let mut file =
        File::open(path).with_context(|| format!("Failed to open {}", path.display()))?;

    let mut magic = [0u8; 8];
    file.read_exact(&mut magic)?;
    if &magic != KARBEAT_MAGIC_HEADER {
        return Err(anyhow::anyhow!("Invalid or corrupted .karbeat file"));
    }

    let mut archive = ZipArchive::new(file)?;
    let mut app_state = ProjectMigrator::detect(&mut archive)?.load(&mut archive)?;

    let library = &mut app_state.asset_library;
    // Extracted sources are re-read when the project is saved, so the directory lives as long
    // as any project state that references it and is deleted with the last one.
    let session_dir = extraction_session_dir()?;
    let cache_dir = session_dir.path();

    app_state.metadata.cover = app_state
        .metadata
        .cover
        .take()
        .and_then(|cover| resolve_cover(&cover, &mut archive, cache_dir));

    // PHASE 1: Sequentially extract all audio files to disk (I/O Bound)
    // We collect the paths into a vector to process them concurrently later.
    let mut audio_tasks = Vec::with_capacity(archive.len());

    for i in 0..archive.len() {
        let mut entry = match archive.by_index(i) {
            Ok(e) => e,
            Err(_) => continue,
        };
        let name = entry.name().to_string();
        let Some((id, file_name)) = parse_embedded_audio_path(&name) else {
            continue;
        };
        if entry.is_dir() {
            continue;
        }

        let audio_folder = cache_dir.join(id.to_string());
        std::fs::create_dir_all(&audio_folder)?;

        let dest_path = audio_folder.join(&file_name);

        let mut dest_file = File::create(&dest_path).with_context(|| {
            format!(
                "Failed to create extracted audio file at {}",
                dest_path.display()
            )
        })?;

        std::io::copy(&mut entry, &mut dest_file).with_context(|| {
            format!("Failed to extract embedded audio from archive entry {name}")
        })?;

        // Queue for parallel decoding
        audio_tasks.push((id, name, file_name, dest_path));
    }

    // PHASE 2: Decode all audio files in parallel (CPU Bound)
    let decoded_waveforms: anyhow::Result<Vec<_>> = audio_tasks
        .into_par_iter()
        .map(|(id, entry_name, file_name, dest_path)| {
            let dest_path_str = dest_path.to_str().with_context(|| {
                format!(
                    "Embedded audio path is not valid UTF-8: {}",
                    dest_path.display()
                )
            })?;

            let waveform = load_audio_file(dest_path_str, Some(&file_name), sample_rate)
                .with_context(|| {
                    format!("Failed to decode embedded audio for source id {id} ({file_name})")
                })?;

            Ok((id, entry_name, waveform))
        })
        .collect();

    // Fill the decoded audio into the deserialized entries, which keep their saved settings
    // (envelope, sample mode, trim, ...) and their exact serialized slot and generation.
    let mut decoded_by_entry = HashMap::new();
    for (id, entry_name, decoded) in decoded_waveforms? {
        let source_id = AudioSourceId::from_u64(id);
        let entry = library
            .source_map
            .get_mut(source_id)
            .with_context(|| format!("Audio source key {id} missing from project arena"))?;
        let waveform = Arc::make_mut(entry);
        waveform.id = Some(source_id);
        adopt_decoded_audio(waveform, &decoded);
        decoded_by_entry.insert(entry_name, decoded);
    }
    // Sources that shared an embedded file (hard copies) share its decoded buffer.
    for (source_id, entry) in &mut library.source_map {
        if entry.buffer.is_some() {
            continue;
        }
        let Some(decoded) = entry
            .file_path
            .to_str()
            .and_then(|path| decoded_by_entry.get(path))
        else {
            continue;
        };
        let waveform = Arc::make_mut(entry);
        waveform.id = Some(source_id);
        adopt_decoded_audio(waveform, decoded);
    }
    library.session_dir = Some(Arc::new(session_dir));

    Ok(app_state)
}

/// Points the loaded cover at a readable file inside the session directory:
/// a symlink to the linked original when it exists on this machine, otherwise
/// the copy extracted from the archive. A missing or unreadable cover is dropped
/// with a warning rather than failing the whole project load.
fn resolve_cover<R: Read + Seek>(
    cover: &CoverImage,
    archive: &mut ZipArchive<R>,
    session_dir: &Path,
) -> Option<CoverImage> {
    let file_name = cover.path.file_name()?;
    let cover_dir = session_dir.join(COVER_ARCHIVE_DIR);
    let local_path = cover_dir.join(file_name);
    if let Err(error) = std::fs::create_dir_all(&cover_dir) {
        log::warn!("Project cover dropped, session folder unavailable: {error}");
        return None;
    }

    if let Some(linked) = cover.linked_path.as_ref().filter(|path| path.is_file()) {
        let path = match link_file(linked, &local_path) {
            Ok(()) => local_path,
            // Symlinks can need extra privileges (Windows); reading in place is equivalent
            Err(error) => {
                log::debug!(
                    "Cover symlink unavailable, using {}: {error}",
                    linked.display()
                );
                linked.clone()
            }
        };
        return Some(CoverImage {
            path,
            linked_path: Some(linked.clone()),
        });
    }

    let entry_name = cover.path.to_str()?.replace('\\', "/");
    let extracted = archive
        .by_name(&entry_name)
        .map_err(anyhow::Error::from)
        .and_then(|mut entry| {
            let mut file = File::create(&local_path)?;
            std::io::copy(&mut entry, &mut file)?;
            Ok(())
        });
    match extracted {
        Ok(()) => Some(CoverImage {
            path: local_path,
            linked_path: cover.linked_path.clone(),
        }),
        Err(error) => {
            log::warn!("Project cover dropped, embedded image unavailable: {error}");
            None
        }
    }
}

#[cfg(unix)]
fn link_file(target: &Path, link: &Path) -> std::io::Result<()> {
    std::os::unix::fs::symlink(target, link)
}

#[cfg(windows)]
fn link_file(target: &Path, link: &Path) -> std::io::Result<()> {
    std::os::windows::fs::symlink_file(target, link)
}

#[cfg(not(any(unix, windows)))]
fn link_file(_target: &Path, _link: &Path) -> std::io::Result<()> {
    Err(std::io::ErrorKind::Unsupported.into())
}

/// Creates the directory that holds one loaded project's extracted audio files.
///
/// It lives in the on-disk user cache because the system temporary directory is often
/// RAM-backed tmpfs on Linux.
fn extraction_session_dir() -> anyhow::Result<tempfile::TempDir> {
    let mut builder = tempfile::Builder::new();
    builder.prefix("session_");
    if let Some(directory) = app_cache_dir().map(|cache| cache.join("sessions")) {
        match std::fs::create_dir_all(&directory).and_then(|()| builder.tempdir_in(&directory)) {
            Ok(session) => return Ok(session),
            Err(error) => log::warn!(
                "Project session cache unavailable in {}, using the temporary directory: {error}",
                directory.display()
            ),
        }
    }
    builder
        .tempdir()
        .context("Failed to create temporary session cache directory")
}

pub fn peek_project_metadata(path: &Path) -> anyhow::Result<ProjectMetadata> {
    let mut file = File::open(path)?;

    let mut magic = [0u8; 8];
    file.read_exact(&mut magic)?;
    if &magic != KARBEAT_MAGIC_HEADER {
        return Err(anyhow::anyhow!("Invalid or corrupted .karbeat file"));
    }

    let mut archive = ZipArchive::new(file)?;
    let mut entry = archive
        .by_name("metadata.toml")
        .context("metadata.toml missing from .karbeat archive")?;
    let mut buf = String::new();
    entry.read_to_string(&mut buf)?;
    let metadata: ProjectMetadata = toml::from_str(&buf)?;

    Ok(metadata)
}

/// Copies the fields decoding determines into a waveform loaded from the project file.
fn adopt_decoded_audio(waveform: &mut AudioWaveform, decoded: &AudioWaveform) {
    waveform.buffer.clone_from(&decoded.buffer);
    waveform.file_path.clone_from(&decoded.file_path);
    waveform.sample_rate = decoded.sample_rate;
    waveform.original_sample_rate = decoded.original_sample_rate;
    waveform.channels = decoded.channels;
    waveform.duration = decoded.duration;
}

/// Parses `audio/{id}_{file_name}` as produced by [`save_karbeat_project`].
fn parse_embedded_audio_path(zip_name: &str) -> Option<(u64, String)> {
    let rest = zip_name.strip_prefix("audio/")?;
    if rest.is_empty() || rest.ends_with('/') {
        return None;
    }
    let (id_str, file_name) = rest.split_once('_')?;
    let id = id_str.parse().ok()?;
    Some((id, file_name.to_string()))
}

#[cfg(test)]
#[allow(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "project round-trip tests fail immediately when fixture I/O or serialization breaks"
)]
mod test {
    use super::*;
    use std::io::{Read, Write};
    use tempfile::tempdir;

    const SAMPLE_RATE: u32 = 48000;

    #[allow(
        clippy::arithmetic_side_effects,
        reason = "the fixture's sizes and sample values are small constants"
    )]
    fn write_mono_wav(path: &Path) {
        let samples: Vec<i16> = (0..4_800).map(|i| (i % 100 - 50) * 100).collect();
        let data_len = u32::try_from(samples.len() * 2).unwrap();
        let mut bytes = Vec::new();
        bytes.extend_from_slice(b"RIFF");
        bytes.extend_from_slice(&(36 + data_len).to_le_bytes());
        bytes.extend_from_slice(b"WAVEfmt ");
        bytes.extend_from_slice(&16_u32.to_le_bytes());
        bytes.extend_from_slice(&1_u16.to_le_bytes());
        bytes.extend_from_slice(&1_u16.to_le_bytes());
        bytes.extend_from_slice(&SAMPLE_RATE.to_le_bytes());
        bytes.extend_from_slice(&(SAMPLE_RATE * 2).to_le_bytes());
        bytes.extend_from_slice(&2_u16.to_le_bytes());
        bytes.extend_from_slice(&16_u16.to_le_bytes());
        bytes.extend_from_slice(b"data");
        bytes.extend_from_slice(&data_len.to_le_bytes());
        for sample in samples {
            bytes.extend_from_slice(&sample.to_le_bytes());
        }
        std::fs::write(path, bytes).unwrap();
    }

    #[test]
    fn extracted_audio_is_deleted_with_the_last_project_state() {
        use crate::audio::render_state::AudioGraphState;
        use crate::core::file_manager::audio_loader::AudioLoader;

        let dir = tempdir().unwrap();
        let wav = dir.path().join("tone.wav");
        write_mono_wav(&wav);
        let mut state = ApplicationState::default();
        state
            .load_audio(wav.to_str().unwrap(), None, SAMPLE_RATE)
            .unwrap();
        let project = dir.path().join("with_audio.karbeat");
        save_daw_project(&project, &state).unwrap();

        let loaded = load_daw_project(&project, SAMPLE_RATE).unwrap();
        let session = loaded
            .asset_library
            .session_dir
            .as_ref()
            .expect("embedded audio is extracted into a session directory")
            .path()
            .to_path_buf();
        let extracted = loaded.asset_library.source_map.values().next().unwrap();
        assert!(extracted.file_path.starts_with(&session));
        assert!(extracted.file_path.is_file());
        assert!(
            AudioGraphState::from(&loaded)
                .asset_library
                .session_dir
                .is_none()
        );

        let clone = loaded.clone();
        drop(loaded);
        assert!(
            session.is_dir(),
            "a remaining project state still needs the files"
        );
        drop(clone);
        assert!(!session.exists());
    }

    #[test]
    fn failed_replacement_cleans_temporary_archive_and_preserves_destination() {
        let dir = tempdir().unwrap();
        let destination = dir.path().join("existing.karbeat");
        std::fs::create_dir(&destination).unwrap();
        let previous = destination.join("previous");
        std::fs::write(&previous, b"keep").unwrap();
        assert!(save_daw_project(&destination, &ApplicationState::default()).is_err());
        assert_eq!(std::fs::read(previous).unwrap(), b"keep");
        assert_eq!(std::fs::read_dir(dir.path()).unwrap().count(), 1);
    }

    #[test]
    fn it_should_be_able_to_save_project() {
        // Setup isolated temp directory
        let dir = tempdir().expect("Failed to create temp directory");
        let file_path = dir.path().join("test_save.karbeat");

        // Create dummy state
        let app_state = ApplicationState::default();

        // Execute Save
        let result = save_daw_project(&file_path, &app_state);
        assert!(result.is_ok(), "Failed to save project: {:?}", result.err());
        assert!(
            file_path.exists(),
            "The .karbeat file was not created on disk"
        );

        // Verify Custom Magic Header exists at the exact beginning of the file
        let mut file = File::open(&file_path).unwrap();
        let mut magic = [0u8; 8];
        file.read_exact(&mut magic).unwrap();
        assert_eq!(&magic, KARBEAT_MAGIC_HEADER, "Magic header did not match");
    }

    #[test]
    fn it_should_reject_invalid_project_file() {
        let dir = tempdir().unwrap();

        // === Scenario A: Missing Magic Header ===
        let file_path_no_magic = dir.path().join("invalid_no_magic.karbeat");
        let mut file = File::create(&file_path_no_magic).unwrap();
        file.write_all(b"GARBAGE_DATA_NO_MAGIC_HEADER").unwrap();

        let load_result = load_daw_project(&file_path_no_magic, SAMPLE_RATE);
        assert!(load_result.is_err());
        assert_eq!(
            load_result.unwrap_err().to_string(),
            "Invalid or corrupted .karbeat file",
            "Did not fail with the expected magic header error"
        );

        // === Scenario B: Valid Header, but corrupted ZIP payload ===
        let file_path_bad_zip = dir.path().join("invalid_bad_zip.karbeat");
        let mut file2 = File::create(&file_path_bad_zip).unwrap();
        file2.write_all(KARBEAT_MAGIC_HEADER).unwrap();
        file2.write_all(b"THIS IS NOT A ZIP FILE").unwrap();

        let load_result_zip = load_daw_project(&file_path_bad_zip, SAMPLE_RATE);
        assert!(
            load_result_zip.is_err(),
            "Failed to reject a corrupted ZIP payload"
        );
    }

    #[test]
    fn test_flow_from_save_to_load() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("flow_test.karbeat");

        // Setup initial state
        let original_state = ApplicationState::default();

        // Save
        let save_result = save_daw_project(&file_path, &original_state);
        assert!(save_result.is_ok(), "Failed to save project in flow test");

        // Peek Metadata
        let peek_result = peek_project_metadata(&file_path);
        assert!(
            peek_result.is_ok(),
            "Failed to peek metadata from saved file"
        );

        // Load & Verify
        let load_result = load_daw_project(&file_path, SAMPLE_RATE);
        assert!(
            load_result.is_ok(),
            "Failed to load the project we just saved: {:?}",
            load_result.err()
        );

        let loaded_state = load_result.unwrap();

        assert_eq!(
            serde_json::to_value(&original_state).unwrap(),
            serde_json::to_value(&loaded_state).unwrap(),
            "Loaded state did not match the saved state!"
        );
    }

    /// Writes a project the way builds before format versioning did: positional
    /// MessagePack and no `format.json`.
    fn write_v1_project(path: &Path, state: &ApplicationState) {
        let mut file = File::create(path).unwrap();
        file.write_all(KARBEAT_MAGIC_HEADER).unwrap();
        let mut zip = ZipWriter::new(file);
        let options = SimpleFileOptions::default();
        zip.start_file("metadata.toml", options).unwrap();
        zip.write_all(toml::to_string(&state.metadata).unwrap().as_bytes())
            .unwrap();
        zip.add_directory("audio/", options).unwrap();
        zip.start_file("project.msgpack", options).unwrap();
        zip.write_all(&rmp_serde::to_vec(state).unwrap()).unwrap();
        zip.finish().unwrap();
    }

    #[test]
    fn saved_projects_are_json_with_a_format_version() {
        let dir = tempdir().unwrap();
        let project = dir.path().join("v2.dgdaw");
        save_daw_project(&project, &ApplicationState::default()).unwrap();

        let manifest: serde_json::Value =
            serde_json::from_slice(&archive_entry(&project, "format.json").unwrap()).unwrap();
        assert_eq!(manifest["version"], 2);
        let payload: serde_json::Value =
            serde_json::from_slice(&archive_entry(&project, "project.json").unwrap()).unwrap();
        assert!(payload["transport"]["bpm"].is_number());
        assert!(archive_entry(&project, "project.msgpack").is_none());
    }

    #[test]
    fn v1_projects_load_and_resave_as_v2() {
        use crate::core::file_manager::format::{ProjectFormatVersion, ProjectMigrator};
        use crate::core::project::PluginInstance;

        let mut state = ApplicationState::default();
        state.transport.bpm = 132.0;
        state.metadata.name = "Old project".into();
        let track = state.add_new_audio_track().id;
        let mut plugin = PluginInstance::new_with_id(7, "EQ");
        plugin.plugin_state = vec![1, 2, 3, 250];
        state.mixer.master_bus.effects.insert(plugin);

        let dir = tempdir().unwrap();
        let v1 = dir.path().join("v1.dgdaw");
        write_v1_project(&v1, &state);
        {
            let mut file = File::open(&v1).unwrap();
            file.read_exact(&mut [0; 8]).unwrap();
            let mut archive = ZipArchive::new(file).unwrap();
            assert_eq!(
                ProjectMigrator::detect(&mut archive).unwrap().version(),
                ProjectFormatVersion::V1
            );
        }

        let loaded = load_daw_project(&v1, SAMPLE_RATE).unwrap();
        assert_eq!(loaded.transport.bpm, 132.0);
        assert_eq!(loaded.metadata.name, "Old project");
        assert!(loaded.tracks.contains_key(track));
        let effect = loaded.mixer.master_bus.effects.iter().next().unwrap();
        assert_eq!(effect.instance.plugin_state, [1, 2, 3, 250]);

        let v2 = dir.path().join("v2.dgdaw");
        save_daw_project(&v2, &loaded).unwrap();
        assert!(archive_entry(&v2, "format.json").is_some());
        let reloaded = load_daw_project(&v2, SAMPLE_RATE).unwrap();
        assert_eq!(
            serde_json::to_value(&loaded).unwrap(),
            serde_json::to_value(&reloaded).unwrap()
        );
    }

    #[test]
    fn newer_format_versions_are_rejected_with_a_clear_error() {
        let dir = tempdir().unwrap();
        let project = dir.path().join("future.dgdaw");
        let mut file = File::create(&project).unwrap();
        file.write_all(KARBEAT_MAGIC_HEADER).unwrap();
        let mut zip = ZipWriter::new(file);
        zip.start_file("format.json", SimpleFileOptions::default())
            .unwrap();
        zip.write_all(br#"{"version":99}"#).unwrap();
        zip.finish().unwrap();

        let error = load_daw_project(&project, SAMPLE_RATE).unwrap_err();
        assert!(error.to_string().contains("format version 99"), "{error}");
    }

    #[test]
    fn non_finite_values_fail_the_save_and_keep_the_previous_file() {
        let dir = tempdir().unwrap();
        let project = dir.path().join("keep.dgdaw");
        save_daw_project(&project, &ApplicationState::default()).unwrap();
        let before = std::fs::read(&project).unwrap();

        let mut broken = ApplicationState::default();
        broken.transport.bpm = f32::NAN;
        let error = save_daw_project(&project, &broken).unwrap_err();
        assert!(error.to_string().contains("not finite"), "{error}");
        assert_eq!(std::fs::read(&project).unwrap(), before);
        assert_eq!(std::fs::read_dir(dir.path()).unwrap().count(), 1);
    }

    #[test]
    fn it_should_be_able_to_load_valid_project() {
        // Because "validity" in this context requires a valid TOML and ZIP layout,
        // the safest way to test an isolated valid load is to generate a fresh one
        // using the save function, ensuring the loader can parse its own formatting.
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("valid_load.karbeat");
        let app_state = ApplicationState::default();

        save_daw_project(&file_path, &app_state).unwrap();

        let load_result = load_daw_project(&file_path, SAMPLE_RATE);
        assert!(
            load_result.is_ok(),
            "Failed to load a known-valid project file"
        );
    }

    fn state_with_cover(cover_path: &Path) -> ApplicationState {
        let art = crate::core::project::CoverArt::encode_rgba(8, &[10_u8, 20, 30, 255].repeat(64))
            .unwrap();
        std::fs::write(cover_path, art.bytes()).unwrap();
        let mut state = ApplicationState::default();
        state.metadata.cover = Some(CoverImage::new(cover_path));
        state
    }

    fn archive_entry(project: &Path, name: &str) -> Option<Vec<u8>> {
        let mut file = File::open(project).unwrap();
        file.read_exact(&mut [0; 8]).unwrap();
        let mut archive = ZipArchive::new(file).unwrap();
        let mut entry = archive.by_name(name).ok()?;
        let mut bytes = Vec::new();
        entry.read_to_end(&mut bytes).unwrap();
        Some(bytes)
    }

    #[test]
    fn cover_is_embedded_with_a_relative_path_and_linked_on_load() {
        let dir = tempdir().unwrap();
        let cover_path = dir.path().join("crop.jpg");
        let project = dir.path().join("cover.dgdaw");
        save_daw_project(&project, &state_with_cover(&cover_path)).unwrap();

        let embedded = archive_entry(&project, "cover/cover.jpg").expect("embedded cover");
        assert_eq!(embedded, std::fs::read(&cover_path).unwrap());
        let toml = String::from_utf8(archive_entry(&project, "metadata.toml").unwrap()).unwrap();
        assert!(toml.contains("path = \"cover/cover.jpg\""), "{toml}");

        let loaded = load_daw_project(&project, 48_000).unwrap();
        let cover = loaded.metadata.cover.expect("resolved cover");
        assert_eq!(cover.linked_path.as_deref(), Some(cover_path.as_path()));
        // The session path leads to the original file on this machine
        assert_eq!(
            std::fs::canonicalize(&cover.path).unwrap(),
            std::fs::canonicalize(&cover_path).unwrap()
        );
    }

    #[test]
    fn missing_link_falls_back_to_the_embedded_copy() {
        let dir = tempdir().unwrap();
        let cover_path = dir.path().join("crop.jpg");
        let project = dir.path().join("moved.dgdaw");
        save_daw_project(&project, &state_with_cover(&cover_path)).unwrap();
        let original = std::fs::read(&cover_path).unwrap();
        std::fs::remove_file(&cover_path).unwrap();

        let loaded = load_daw_project(&project, 48_000).unwrap();
        let cover = loaded.metadata.cover.expect("extracted cover");
        assert_ne!(cover.path, cover_path);
        assert_eq!(std::fs::read(&cover.path).unwrap(), original);
        // The original link is kept for machines where it still exists
        assert_eq!(cover.linked_path.as_deref(), Some(cover_path.as_path()));
    }

    #[test]
    fn projects_without_cover_have_no_cover_entry() {
        let dir = tempdir().unwrap();
        let project = dir.path().join("plain.dgdaw");
        save_daw_project(&project, &ApplicationState::default()).unwrap();
        assert!(archive_entry(&project, "cover/cover.jpg").is_none());
        assert!(
            load_daw_project(&project, 48_000)
                .unwrap()
                .metadata
                .cover
                .is_none()
        );
    }

    fn audio_entry_names(project: &Path) -> Vec<String> {
        let mut file = File::open(project).unwrap();
        file.read_exact(&mut [0; 8]).unwrap();
        let archive = ZipArchive::new(file).unwrap();
        archive
            .file_names()
            .filter(|name| name.starts_with("audio/") && !name.ends_with('/'))
            .map(str::to_string)
            .collect()
    }

    #[test]
    fn envelopes_edits_and_hard_copies_survive_save_and_load() {
        use crate::core::file_manager::audio_loader::AudioLoader;
        use crate::core::project::{
            EnvelopePoint, Fade, GainEnvelope,
            audio_waveform::{AudioSampleMode, BeatGrid, EditedWaveform, WaveformEdits},
            clip::ClipSourceType,
        };

        let dir = tempdir().unwrap();
        let wav = dir.path().join("tone.wav");
        write_mono_wav(&wav);
        let mut state = ApplicationState::default();
        let source = state
            .load_audio(wav.to_str().unwrap(), None, SAMPLE_RATE)
            .unwrap();
        let track = state.add_new_audio_track().id;
        let clip = state
            .create_new_clip(Some(source.to_u64()), ClipSourceType::Audio, track, 0)
            .unwrap();
        let duplicate = state
            .duplicate_clip_groups(track, &[clip.id], &[1_920])
            .unwrap()
            .remove(0);

        let waveform_envelope = GainEnvelope {
            fade_in: Fade {
                length: 64,
                ..Fade::default()
            },
            crossfade: 32,
            ..GainEnvelope::default()
        };
        state
            .set_audio_source_envelope(source, waveform_envelope.clone())
            .unwrap();
        {
            let waveform = Arc::make_mut(&mut state.asset_library.source_map[source]);
            waveform.sample_mode = AudioSampleMode::Resampled;
            waveform.edited = Some(EditedWaveform {
                edits: WaveformEdits {
                    reverse: true,
                    pitch_semitones: 3.0,
                    warp: true,
                    ..WaveformEdits::default()
                },
                ..EditedWaveform::default()
            });
            waveform.beat_grid = Some(BeatGrid {
                bpm: 124.0,
                confidence: 0.9,
                beats: vec![0.1, 0.58, 1.07],
                downbeats: vec![0.1],
            });
        }
        let clip_envelope = GainEnvelope {
            points: vec![EnvelopePoint {
                position: 100,
                gain: 0.5,
                ..EnvelopePoint::default()
            }],
            ..GainEnvelope::default()
        };
        state
            .set_clip_envelope(clip.id, clip_envelope.clone())
            .unwrap();
        let made = state.make_clips_unique(track, &[duplicate.id]).unwrap();
        let copy = made.sources[0];

        let project = dir.path().join("envelopes.karbeat");
        save_daw_project(&project, &state).unwrap();
        assert_eq!(
            audio_entry_names(&project).len(),
            1,
            "a hard copy shares its original's embedded file"
        );

        let loaded = load_daw_project(&project, SAMPLE_RATE).unwrap();
        let sources = &loaded.asset_library.source_map;
        let original = &sources[source];
        assert_eq!(original.envelope, waveform_envelope);
        assert_eq!(original.sample_mode, AudioSampleMode::Resampled);
        let edits = &original.edited.as_ref().unwrap().edits;
        assert!(edits.reverse);
        assert_eq!(edits.pitch_semitones, 3.0);
        assert!(edits.warp);
        let grid = original.beat_grid.as_ref().unwrap();
        assert_eq!(grid.bpm, 124.0);
        assert_eq!(grid.beats, vec![0.1, 0.58, 1.07]);
        assert_eq!(grid.downbeats, vec![0.1]);
        assert_eq!(sources[copy].name, "tone.wav (copy)");
        assert_eq!(sources[copy].id, Some(copy));
        assert!(Arc::ptr_eq(
            original.buffer.as_ref().unwrap(),
            sources[copy].buffer.as_ref().unwrap(),
        ));
        assert_eq!(
            loaded.clips_pool[clip.id].envelope.as_deref(),
            Some(&clip_envelope)
        );
        assert!(loaded.clips_pool[duplicate.id].envelope.is_none());
    }

    #[test]
    fn clips_saved_before_envelopes_still_load() {
        use crate::core::project::{Clip, ClipTimeUnit, DawSource};
        use crate::shared::id::ClipId;

        /// The clip layout projects were saved with before clip envelopes existed.
        #[derive(serde::Serialize)]
        struct LegacyClip {
            name: String,
            id: ClipId,
            source: Option<DawSource>,
            time: ClipTimeUnit,
        }

        let bytes = rmp_serde::to_vec(&LegacyClip {
            name: "old".into(),
            id: ClipId::default(),
            source: None,
            time: ClipTimeUnit::default(),
        })
        .unwrap();
        let clip: Clip = rmp_serde::from_slice(&bytes).unwrap();
        assert_eq!(clip.name, "old");
        assert!(clip.envelope.is_none());
    }
}
