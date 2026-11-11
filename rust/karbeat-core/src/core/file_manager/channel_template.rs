//! Mixer channel templates: the ordered effect chain of one channel, stored as a `.effch` file.
//!
//! A template holds each plugin's identity and state, and nothing tied to the project it came
//! from: no effect IDs, routing, sidechain sends, automation, or fader values.

use std::{fs::read, io::Write, path::Path};

use anyhow::Context;
use serde::{Deserialize, Serialize};

use crate::core::project::plugin::PluginInstance;

/// File extension of a channel template.
pub const CHANNEL_TEMPLATE_EXTENSION: &str = "effch";

/// Template layout written by this build.
const CHANNEL_TEMPLATE_VERSION: u32 = 1;

/// Contents of a `.effch` file.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ChannelTemplate {
    /// Layout version, so later builds can recognize and upgrade older files.
    pub version: u32,
    /// Plugins in DSP processing order.
    pub effects: Vec<PluginInstance>,
}

impl ChannelTemplate {
    /// Creates a template in the current layout from plugins in processing order.
    pub fn new(effects: Vec<PluginInstance>) -> Self {
        Self {
            version: CHANNEL_TEMPLATE_VERSION,
            effects,
        }
    }
}

/// Serializes the template, then decodes it once to make sure the file will load again.
///
/// JSON has no NaN or infinity: serde writes them as null, which a plain float field rejects on
/// load. Failing here keeps any previous file intact instead.
fn encode(template: &ChannelTemplate) -> anyhow::Result<Vec<u8>> {
    let bytes = serde_json::to_vec(template).context("Failed to serialize the channel template")?;
    if let Err(error) = serde_json::from_slice::<ChannelTemplate>(&bytes) {
        anyhow::bail!(
            "The channel template contains a value that cannot be saved, most likely a number \
             that is not finite (NaN or infinity): {error}"
        );
    }
    Ok(bytes)
}

/// Rejects a path that does not name a `.effch` file.
pub fn ensure_channel_template_path(path: &Path) -> anyhow::Result<()> {
    anyhow::ensure!(
        path.extension()
            .is_some_and(|extension| extension.eq_ignore_ascii_case(CHANNEL_TEMPLATE_EXTENSION)),
        "Channel templates must use the .{CHANNEL_TEMPLATE_EXTENSION} extension"
    );
    Ok(())
}

/// Reads the template at `path`.
///
/// The version is checked first, so a file from a newer build gets a clear error rather than
/// whatever its changed layout fails to decode with.
pub fn load_channel_template(path: &Path) -> anyhow::Result<ChannelTemplate> {
    #[derive(Deserialize)]
    struct Header {
        version: u32,
    }

    ensure_channel_template_path(path)?;
    let bytes = read(path).with_context(|| format!("Failed to open {}", path.display()))?;
    let header: Header =
        serde_json::from_slice(&bytes).context("This file is not a channel template")?;
    anyhow::ensure!(
        header.version <= CHANNEL_TEMPLATE_VERSION,
        "This channel template uses format version {}, which is newer than this version of \
         DigiDAW supports ({CHANNEL_TEMPLATE_VERSION}). Update DigiDAW to open it.",
        header.version
    );
    serde_json::from_slice(&bytes).context("Failed to read the channel template")
}

/// Atomically writes `template` to `path`, leaving any existing file intact on failure.
pub fn save_channel_template(path: &Path, template: &ChannelTemplate) -> anyhow::Result<()> {
    ensure_channel_template_path(path)?;
    let bytes = encode(template)?;
    let parent = path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let mut temporary = tempfile::NamedTempFile::new_in(parent)?;
    let file = temporary.as_file_mut();
    file.write_all(&bytes)?;
    file.sync_all()?;
    temporary.persist(path).map_err(|error| error.error)?;
    Ok(())
}

#[cfg(test)]
#[allow(
    clippy::indexing_slicing,
    clippy::unwrap_used,
    reason = "template round-trip tests fail immediately when fixture I/O or serialization breaks"
)]
mod tests {
    use super::*;
    use karbeat_plugin_types::ParameterSpec;
    use std::fs::{read_dir, write};

    fn template() -> ChannelTemplate {
        let mut eq = PluginInstance::new_with_id(7, "EQ");
        eq.plugin_state = vec![1, 2, 3, 250];
        eq.bypass = true;
        eq.display_name = Some("Vocal EQ".into());
        let compressor = PluginInstance::new_with_id(9, "Compressor");
        ChannelTemplate::new(vec![eq, compressor])
    }

    #[test]
    fn saved_template_round_trips_in_order_as_versioned_json() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("vocal.effch");
        let template = template();
        save_channel_template(&path, &template).unwrap();

        let document: serde_json::Value = serde_json::from_slice(&read(&path).unwrap()).unwrap();
        assert_eq!(document["version"], CHANNEL_TEMPLATE_VERSION);
        assert_eq!(load_channel_template(&path).unwrap(), template);
    }

    #[test]
    fn newer_versions_and_other_files_are_rejected_with_a_clear_error() {
        let directory = tempfile::tempdir().unwrap();

        let future = directory.path().join("future.effch");
        write(&future, br#"{"version":99,"chain":{}}"#).unwrap();
        let error = load_channel_template(&future).unwrap_err();
        assert!(error.to_string().contains("format version 99"), "{error}");

        let garbage = directory.path().join("garbage.effch");
        write(&garbage, b"not json").unwrap();
        let error = load_channel_template(&garbage).unwrap_err();
        assert!(
            error.to_string().contains("not a channel template"),
            "{error}"
        );

        let wrong_extension = directory.path().join("chain.json");
        write(&wrong_extension, br#"{"version":1,"effects":[]}"#).unwrap();
        assert!(load_channel_template(&wrong_extension).is_err());
    }

    #[test]
    fn non_finite_values_fail_the_save_and_keep_the_previous_file() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("keep.effch");
        write(&path, b"previous template").unwrap();

        let mut broken = template();
        broken.effects[0].parameter_specs = vec![ParameterSpec::new_float(
            0,
            "Gain",
            "Main",
            f64::NAN,
            0.0,
            1.0,
            0.0,
            0.0,
        )];
        let error = save_channel_template(&path, &broken).unwrap_err();
        assert!(error.to_string().contains("not finite"), "{error}");
        assert_eq!(read(&path).unwrap(), b"previous template");
        assert_eq!(read_dir(directory.path()).unwrap().count(), 1);
    }
}
