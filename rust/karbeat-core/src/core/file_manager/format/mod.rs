//! Versioned project payloads inside the `.dgdaw` archive.
//!
//! Every archive written by this build carries a `format.json` entry naming its payload
//! version. Archives without one predate versioning and are [`ProjectFormatVersion::V1`].
//!
//! Loading goes through [`ProjectMigrator`], which reads the payload with the loader of the
//! version it was written in and upgrades it step by step to [`ProjectFormatVersion::CURRENT`].
//! Saving always writes the current version.
//!
//! Adding a version: add a `vN` module with its loader, a variant here, and a migration step
//! from the previous version. Steps from v2 onwards work on the JSON document
//! ([`serde_json::Value`]) before it is decoded, so they can rename, move, or restructure
//! fields that the current Rust types no longer describe.

mod v1;
mod v2;

use std::io::{Read, Seek, Write};

use anyhow::Context;
use serde::{Deserialize, Serialize};
use zip::{ZipArchive, ZipWriter, write::SimpleFileOptions};

use crate::core::project::ApplicationState;

/// Archive entry that names the payload version.
const FORMAT_ENTRY: &str = "format.json";

/// Project payload layouts, oldest first.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum ProjectFormatVersion {
    /// Positional MessagePack in `project.msgpack`. Fields can only be appended.
    V1,
    /// Named JSON in `project.json`. Fields can be added in any order.
    V2,
}

impl ProjectFormatVersion {
    /// Version written by this build.
    pub const CURRENT: Self = Self::V2;

    /// Number stored in `format.json`.
    pub fn number(self) -> u32 {
        match self {
            Self::V1 => 1,
            Self::V2 => 2,
        }
    }

    fn from_number(number: u32) -> Option<Self> {
        match number {
            1 => Some(Self::V1),
            2 => Some(Self::V2),
            _ => None,
        }
    }
}

/// Contents of `format.json`.
#[derive(Serialize, Deserialize)]
struct FormatManifest {
    version: u32,
}

/// Loads a project archive of any supported version as current state, and writes the
/// current version.
pub struct ProjectMigrator {
    version: ProjectFormatVersion,
}

impl ProjectMigrator {
    /// Reads the payload version of an opened project archive.
    pub fn detect<R: Read + Seek>(archive: &mut ZipArchive<R>) -> anyhow::Result<Self> {
        let Ok(mut entry) = archive.by_name(FORMAT_ENTRY) else {
            return Ok(Self {
                version: ProjectFormatVersion::V1,
            });
        };
        let mut bytes = Vec::new();
        entry.read_to_end(&mut bytes)?;
        let manifest: FormatManifest =
            serde_json::from_slice(&bytes).context("Failed to read the project format version")?;
        let version = ProjectFormatVersion::from_number(manifest.version).with_context(|| {
            format!(
                "This project uses format version {}, which is newer than this version of \
                 DigiDAW supports ({}). Update DigiDAW to open it.",
                manifest.version,
                ProjectFormatVersion::CURRENT.number()
            )
        })?;
        Ok(Self { version })
    }

    /// Version the archive was written in.
    pub fn version(&self) -> ProjectFormatVersion {
        self.version
    }

    /// Reads the project payload and upgrades it to the current version.
    ///
    /// Only the serialized project state is read; embedded audio and the cover are resolved
    /// by the caller.
    pub fn load<R: Read + Seek>(
        &self,
        archive: &mut ZipArchive<R>,
    ) -> anyhow::Result<ApplicationState> {
        let mut state = match self.version {
            ProjectFormatVersion::V1 => {
                let state = v1::V1Loader::read(archive)?;
                log::info!(
                    "Upgrading project from format v1 to v{}",
                    ProjectFormatVersion::CURRENT.number()
                );
                v1::migrate_to_v2(state)
            }
            ProjectFormatVersion::V2 => {
                let document = v2::V2Loader::read_document(archive)?;
                v2::V2Loader::decode(document)?
            }
        };
        // Audio clips placed in samples predate tick placement; converting them is idempotent
        state.migrate_legacy_audio_clip_placement();
        Ok(state)
    }

    /// Writes the format manifest and the project payload in the current version.
    ///
    /// Fails without writing the payload when the serialized project would not load back,
    /// such as when it contains a non-finite number.
    pub fn write<W: Write + Seek>(
        zip: &mut ZipWriter<W>,
        state: &ApplicationState,
        options: SimpleFileOptions,
    ) -> anyhow::Result<()> {
        let payload = v2::V2Loader::encode(state)?;
        let manifest = serde_json::to_vec(&FormatManifest {
            version: ProjectFormatVersion::CURRENT.number(),
        })?;
        zip.start_file(FORMAT_ENTRY, options)?;
        zip.write_all(&manifest)?;
        zip.start_file(v2::V2Loader::ENTRY, options)?;
        zip.write_all(&payload)?;
        Ok(())
    }
}
