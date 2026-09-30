//! Format v1: the project state as positional MessagePack in `project.msgpack`.
//!
//! v1 files are decoded with the current Rust types, which only works because every field
//! added since has been appended to the end of its struct with `#[serde(default)]`. Keep
//! that rule for as long as v1 files are supported, even though v2 does not need it.

use std::io::{Read, Seek};

use anyhow::Context;
use zip::ZipArchive;

use crate::core::project::ApplicationState;

pub(super) struct V1Loader;

impl V1Loader {
    const ENTRY: &str = "project.msgpack";

    pub(super) fn read<R: Read + Seek>(
        archive: &mut ZipArchive<R>,
    ) -> anyhow::Result<ApplicationState> {
        let mut bytes = Vec::new();
        archive
            .by_name(Self::ENTRY)
            .with_context(|| format!("{} missing from project archive", Self::ENTRY))?
            .read_to_end(&mut bytes)?;
        rmp_serde::from_slice(&bytes)
            .with_context(|| format!("Failed to deserialize {}", Self::ENTRY))
    }
}

/// Upgrades a v1 project to v2.
///
/// v2 changed only the encoding, not the schema, so the decoded state carries over as is.
pub(super) fn migrate_to_v2(state: ApplicationState) -> ApplicationState {
    state
}
