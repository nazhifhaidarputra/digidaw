//! User libraries shared by every project: automation curve templates, favorite plugins, sample
//! folders and recently opened projects. Each is stored in its own file.

use std::{collections::BTreeSet, path::PathBuf};

use serde::{Deserialize, Serialize};

use crate::{file::SettingsFile, lenient};

/// Shape of the segment from an automation point to the next one.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
#[expect(missing_docs, reason = "each variant is the curve shape it names")]
pub enum CurveType {
    Linear,
    Exponential,
    Step,
    Logarithmic,
    SCurve,
    Bezier,
    Stairs,
    SmoothStairs,
    Pulse,
    Wave,
    Triangle,
    HalfSine,
}

/// One point of a template, timed from the start of the template.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TemplatePoint {
    /// Ticks from the start of the template.
    pub time_ticks: u32,
    /// Normalized lane value.
    pub value: f64,
    /// Shape of the segment to the next point.
    pub curve_type: CurveType,
    /// Bend of the segment to the next point.
    pub tension: f64,
    /// Bezier handles `[x1, y1, x2, y2]` of the segment to the next point.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub handles: Option<[f64; 4]>,
}

/// A saved automation curve.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AutomationTemplate {
    /// Identifier, unique inside the library.
    pub id: String,
    /// Name shown in the template menus.
    pub name: String,
    /// Length of the saved range in ticks.
    pub length_ticks: u32,
    /// The curve's points; never empty.
    pub points: Vec<TemplatePoint>,
}

/// The automation curve template library, stored in `automation-templates.toml`.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct AutomationTemplates {
    /// Templates in the order they were added.
    #[serde(rename = "template", deserialize_with = "lenient::list")]
    pub templates: Vec<AutomationTemplate>,
}

impl SettingsFile for AutomationTemplates {
    const FILE_NAME: &'static str = "automation-templates.toml";

    fn normalize(&mut self) {
        self.templates
            .retain(|template| !template.points.is_empty());
    }
}

/// Plugins marked as favorites, stored in `plugin-favorites.toml`.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct PluginFavorites {
    /// Catalog ids of the favorite plugins.
    #[serde(deserialize_with = "lenient::list")]
    pub ids: BTreeSet<String>,
}

impl SettingsFile for PluginFavorites {
    const FILE_NAME: &'static str = "plugin-favorites.toml";
}

/// Folders shown in the sample browser, stored in `sample-folders.toml`.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct SampleFolders {
    /// The folders, each listed once.
    #[serde(deserialize_with = "lenient::list")]
    pub folders: BTreeSet<PathBuf>,
}

impl SettingsFile for SampleFolders {
    const FILE_NAME: &'static str = "sample-folders.toml";
}

/// Recently opened or saved projects, most recent first, stored in `recent-projects.toml`.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct RecentProjects {
    /// Project files, most recent first, each listed once.
    #[serde(deserialize_with = "lenient::list")]
    pub paths: Vec<PathBuf>,
}

impl RecentProjects {
    /// Most projects remembered; older ones are forgotten.
    pub const LIMIT: usize = 10;

    /// Makes `path` the most recent project, moving it to the front if it is already listed.
    pub fn record(&mut self, path: PathBuf) {
        self.paths.retain(|listed| *listed != path);
        self.paths.insert(0, path);
        self.paths.truncate(Self::LIMIT);
    }
}

impl SettingsFile for RecentProjects {
    const FILE_NAME: &'static str = "recent-projects.toml";

    fn normalize(&mut self) {
        let mut seen = BTreeSet::new();
        self.paths.retain(|path| seen.insert(path.clone()));
        self.paths.truncate(Self::LIMIT);
    }
}
