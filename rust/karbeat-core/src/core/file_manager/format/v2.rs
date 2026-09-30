//! Format v2: the project state as named JSON in `project.json`.

use std::io::{Read, Seek};

use anyhow::Context;
use zip::ZipArchive;

use crate::core::project::ApplicationState;

pub(super) struct V2Loader;

impl V2Loader {
    pub(super) const ENTRY: &str = "project.json";

    /// Reads the raw JSON document, before any typed decoding.
    pub(super) fn read_document<R: Read + Seek>(
        archive: &mut ZipArchive<R>,
    ) -> anyhow::Result<serde_json::Value> {
        let entry = archive
            .by_name(Self::ENTRY)
            .with_context(|| format!("{} missing from project archive", Self::ENTRY))?;
        serde_json::from_reader(std::io::BufReader::new(entry))
            .with_context(|| format!("Failed to parse {}", Self::ENTRY))
    }

    pub(super) fn decode(document: serde_json::Value) -> anyhow::Result<ApplicationState> {
        serde_json::from_value(document)
            .with_context(|| format!("Failed to deserialize {}", Self::ENTRY))
    }

    /// Serializes the state, then decodes it once to make sure the file will load again.
    ///
    /// JSON has no NaN or infinity: serde writes them as null, which a plain float field
    /// rejects on load. Failing the save keeps the previous file intact instead.
    pub(super) fn encode(state: &ApplicationState) -> anyhow::Result<Vec<u8>> {
        let bytes = serde_json::to_vec(state).context("Failed to serialize the project to JSON")?;
        if let Err(error) = serde_json::from_slice::<ApplicationState>(&bytes) {
            anyhow::bail!(
                "The project contains a value that cannot be saved, most likely a number that \
                 is not finite (NaN or infinity): {error}"
            );
        }
        Ok(bytes)
    }
}
