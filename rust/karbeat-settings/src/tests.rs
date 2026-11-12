use std::{
    collections::BTreeSet,
    fs::{read_dir, read_to_string, write},
    path::{Path, PathBuf},
};

use tempfile::{TempDir, tempdir};

use super::*;

fn open(dir: &TempDir) -> (SettingsStore, Vec<Recovered>) {
    SettingsStore::open(dir.path()).unwrap()
}

fn settings_file(dir: &TempDir) -> PathBuf {
    dir.path().join(Preferences::FILE_NAME)
}

#[test]
fn missing_files_give_defaults_without_writing() {
    let dir = tempdir().unwrap();
    let (store, recovered) = open(&dir);

    assert!(recovered.is_empty());
    assert_eq!(store.preferences(), &Preferences::default());
    assert_eq!(store.preferences().general.history_limit, 100);
    assert_eq!(store.preferences().audio.sample_rate, 48_000);
    assert!(store.automation_templates().templates.is_empty());
    assert_eq!(read_dir(dir.path()).unwrap().count(), 0);
}

#[test]
fn saved_preferences_load_back() {
    let dir = tempdir().unwrap();
    let (mut store, _) = open(&dir);
    store
        .update_preferences(|preferences| {
            preferences.general.history_limit = 250;
            preferences.general.language = Some("ja-JP".into());
            preferences.audio.output_device = Some("hw:1".into());
            preferences.appearance.theme_mode = ThemeMode::Light;
            preferences.appearance.color_theme = ColorThemeChoice::Source("/themes/a.json".into());
            preferences.shortcuts.overrides.insert(
                "transport.play".into(),
                ShortcutChord {
                    key: 0x20,
                    control: true,
                    shift: false,
                    alt: false,
                    meta: false,
                },
            );
        })
        .unwrap();

    let (reopened, recovered) = open(&dir);
    assert!(recovered.is_empty());
    assert_eq!(reopened.preferences(), store.preferences());
}

#[test]
fn missing_fields_take_their_defaults() {
    let dir = tempdir().unwrap();
    write(settings_file(&dir), "[general]\nhistory_limit = 25\n").unwrap();

    let (store, _) = open(&dir);
    let general = &store.preferences().general;
    assert_eq!(general.history_limit, 25);
    assert!(general.auto_save_enabled);
    assert_eq!(general.auto_save_interval_seconds, 300);
    assert_eq!(general.language, None);
    assert_eq!(store.preferences().logs, LogSettings::default());
}

#[test]
fn an_invalid_value_resets_only_that_field() {
    let dir = tempdir().unwrap();
    write(
        settings_file(&dir),
        "[appearance]\ntheme_mode = \"sepia\"\ncolor_palette = \"teal\"\n\
         [general]\nhistory_limit = -4\nauto_save_enabled = false\n",
    )
    .unwrap();

    let (store, recovered) = open(&dir);
    assert!(recovered.is_empty());
    let preferences = store.preferences();
    assert_eq!(preferences.appearance.theme_mode, ThemeMode::Dark);
    assert_eq!(preferences.appearance.color_palette, ColorPalette::Teal);
    assert_eq!(preferences.general.history_limit, 100);
    assert!(!preferences.general.auto_save_enabled);

    // The repaired values are written back.
    let text = read_to_string(settings_file(&dir)).unwrap();
    assert!(text.contains("theme_mode = \"dark\""), "{text}");
}

#[test]
fn an_invalid_shortcut_drops_only_that_shortcut() {
    let dir = tempdir().unwrap();
    write(
        settings_file(&dir),
        "[shortcuts.overrides]\n\
         \"edit.undo\" = { key = 122, control = true, shift = false, alt = false, meta = false }\n\
         \"edit.redo\" = { key = \"z\" }\n",
    )
    .unwrap();

    let (store, _) = open(&dir);
    let overrides = &store.preferences().shortcuts.overrides;
    assert_eq!(overrides.len(), 1);
    assert_eq!(overrides["edit.undo"].key, 122);
}

#[test]
fn out_of_range_values_are_brought_into_range() {
    let dir = tempdir().unwrap();
    write(
        settings_file(&dir),
        "[appearance]\nbackground_overlay = 3.5\n[logs]\nmaximum_entries = 10\n",
    )
    .unwrap();

    let (mut store, _) = open(&dir);
    assert_eq!(
        store.preferences().appearance.background_overlay,
        AppearanceSettings::DEFAULT_OVERLAY
    );
    assert_eq!(
        store.preferences().logs.maximum_entries,
        LogSettings::DEFAULT_ENTRIES
    );

    let updated = store
        .update_preferences(|preferences| preferences.logs.maximum_entries = 5000)
        .unwrap();
    assert_eq!(updated.logs.maximum_entries, LogSettings::DEFAULT_ENTRIES);
}

#[test]
fn a_file_that_is_not_toml_is_moved_aside() {
    let dir = tempdir().unwrap();
    write(settings_file(&dir), "this is [not toml").unwrap();

    let (store, recovered) = open(&dir);
    assert_eq!(store.preferences(), &Preferences::default());
    assert_eq!(recovered.len(), 1);
    let entry = recovered.first().unwrap();
    assert_eq!(entry.file, settings_file(&dir));
    assert_eq!(entry.backup, dir.path().join("settings.bad.toml"));
    assert_eq!(read_to_string(&entry.backup).unwrap(), "this is [not toml");
    assert!(!settings_file(&dir).exists());
}

#[test]
fn a_complete_file_keeps_its_comments() {
    let dir = tempdir().unwrap();
    let (mut store, _) = open(&dir);
    store
        .update_preferences(|preferences| preferences.general.history_limit = 50)
        .unwrap();
    let commented = format!(
        "# Edited by hand\n{}",
        read_to_string(settings_file(&dir)).unwrap()
    );
    write(settings_file(&dir), &commented).unwrap();

    let _ = open(&dir);
    assert_eq!(read_to_string(settings_file(&dir)).unwrap(), commented);
}

#[test]
fn folder_settings_must_name_existing_folders() {
    let dir = tempdir().unwrap();
    let (mut store, _) = open(&dir);
    let missing = dir.path().join("missing");

    let error = store
        .update_preferences(|preferences| {
            preferences.general.default_export_folder = Some(missing.clone());
        })
        .unwrap_err();
    assert!(matches!(error, SettingsError::NotAFolder(path) if path == missing));
    assert_eq!(store.preferences().general.default_export_folder, None);

    let relative = store.update_preferences(|preferences| {
        preferences.general.default_project_folder = Some(PathBuf::from("projects"));
    });
    assert!(relative.is_err());

    let folder = dir.path().to_path_buf();
    store
        .update_preferences(|preferences| {
            preferences.general.default_project_folder = Some(folder.clone());
        })
        .unwrap();
    assert_eq!(
        store.preferences().general.default_project_folder,
        Some(folder)
    );
}

#[test]
fn a_folder_that_disappeared_is_kept() {
    let dir = tempdir().unwrap();
    let folder = tempdir().unwrap();
    let folder_path = folder.path().to_path_buf();
    let (mut store, _) = open(&dir);
    store
        .update_preferences(|preferences| {
            preferences.general.default_project_folder = Some(folder_path.clone());
        })
        .unwrap();
    drop(folder);

    let (mut reopened, _) = open(&dir);
    assert_eq!(
        reopened.preferences().general.default_project_folder,
        Some(folder_path.clone())
    );
    // Changing another setting keeps it too.
    reopened
        .update_preferences(|preferences| preferences.general.history_limit = 10)
        .unwrap();
    assert_eq!(
        reopened.preferences().general.default_project_folder,
        Some(folder_path)
    );
}

fn template(id: &str, points: Vec<TemplatePoint>) -> AutomationTemplate {
    AutomationTemplate {
        id: id.into(),
        name: format!("Template {id}"),
        length_ticks: 960,
        points,
    }
}

fn point(time_ticks: u32, curve_type: CurveType, handles: Option<[f64; 4]>) -> TemplatePoint {
    TemplatePoint {
        time_ticks,
        value: 0.5,
        curve_type,
        tension: 0.0,
        handles,
    }
}

#[test]
fn automation_templates_round_trip() {
    let dir = tempdir().unwrap();
    let (mut store, _) = open(&dir);
    let templates = AutomationTemplates {
        templates: vec![
            template(
                "1",
                vec![
                    point(0, CurveType::Bezier, Some([0.25, 0.1, 0.75, 0.9])),
                    point(960, CurveType::SCurve, None),
                ],
            ),
            template("2", vec![point(0, CurveType::HalfSine, None)]),
        ],
    };
    store.set_automation_templates(templates.clone()).unwrap();

    let (reopened, _) = open(&dir);
    assert_eq!(reopened.automation_templates(), &templates);
}

#[test]
fn damaged_and_empty_templates_are_skipped() {
    let dir = tempdir().unwrap();
    let (mut store, _) = open(&dir);
    store
        .set_automation_templates(AutomationTemplates {
            templates: vec![
                template("kept", vec![point(0, CurveType::Linear, None)]),
                template("empty", Vec::new()),
            ],
        })
        .unwrap();
    assert_eq!(store.automation_templates().templates.len(), 1);

    let path = dir.path().join(AutomationTemplates::FILE_NAME);
    let text = read_to_string(&path).unwrap()
        + "\n[[template]]\nid = \"bad\"\nname = \"Bad\"\nlength_ticks = 10\n\
           points = [{ time_ticks = 0, value = 0.1, curve_type = \"spiral\", tension = 0.0 }]\n";
    write(&path, text).unwrap();

    let (reopened, recovered) = open(&dir);
    assert!(recovered.is_empty());
    let ids: Vec<_> = reopened
        .automation_templates()
        .templates
        .iter()
        .map(|template| template.id.as_str())
        .collect();
    assert_eq!(ids, ["kept"]);
}

#[test]
fn libraries_are_stored_in_their_own_files() {
    let dir = tempdir().unwrap();
    let (mut store, _) = open(&dir);
    store
        .set_plugin_favorites(PluginFavorites {
            ids: BTreeSet::from(["vst3:b".into(), "clap:a".into()]),
        })
        .unwrap();
    store
        .set_sample_folders(SampleFolders {
            folders: BTreeSet::from([PathBuf::from("/samples/drums")]),
        })
        .unwrap();

    let mut files: Vec<_> = read_dir(dir.path())
        .unwrap()
        .map(|entry| entry.unwrap().file_name().into_string().unwrap())
        .collect();
    files.sort();
    assert_eq!(files, ["plugin-favorites.toml", "sample-folders.toml"]);

    let (reopened, _) = open(&dir);
    assert_eq!(reopened.plugin_favorites(), store.plugin_favorites());
    assert_eq!(reopened.sample_folders(), store.sample_folders());
}

#[test]
fn saving_leaves_no_temporary_files() {
    let dir = tempdir().unwrap();
    let (mut store, _) = open(&dir);
    for limit in [1, 2, 3] {
        store
            .update_preferences(|preferences| preferences.general.history_limit = limit)
            .unwrap();
    }
    let names: Vec<_> = read_dir(dir.path())
        .unwrap()
        .map(|entry| entry.unwrap().path())
        .collect();
    assert_eq!(names, [settings_file(&dir)]);
    assert_eq!(store.dir(), Path::new(dir.path()));
}

#[test]
fn reopening_a_project_moves_it_to_the_front() {
    let dir = tempdir().unwrap();
    let (mut store, _) = open(&dir);
    for name in ["a", "b", "c", "d", "e", "f", "g"] {
        store
            .record_recent_project(format!("/projects/{name}.dgdaw"))
            .unwrap();
    }
    // "a" is 7th, the oldest; opening it again makes it the most recent, listed once.
    store.record_recent_project("/projects/a.dgdaw").unwrap();

    let (reopened, _) = open(&dir);
    let paths: Vec<_> = reopened
        .recent_projects()
        .paths
        .iter()
        .map(|path| path.to_str().unwrap())
        .collect();
    assert_eq!(
        paths,
        [
            "/projects/a.dgdaw",
            "/projects/g.dgdaw",
            "/projects/f.dgdaw",
            "/projects/e.dgdaw",
            "/projects/d.dgdaw",
            "/projects/c.dgdaw",
            "/projects/b.dgdaw",
        ]
    );
}

#[test]
fn recent_projects_keep_the_newest_up_to_the_limit() {
    let dir = tempdir().unwrap();
    let (mut store, _) = open(&dir);
    for index in 0..RecentProjects::LIMIT + 3 {
        store
            .record_recent_project(format!("/projects/{index}.dgdaw"))
            .unwrap();
    }

    let paths = &store.recent_projects().paths;
    assert_eq!(paths.len(), RecentProjects::LIMIT);
    assert_eq!(
        paths.first(),
        Some(&PathBuf::from(format!(
            "/projects/{}.dgdaw",
            RecentProjects::LIMIT + 2
        )))
    );
}

#[test]
fn a_hand_edited_recent_list_is_deduplicated() {
    let dir = tempdir().unwrap();
    write(
        dir.path().join(RecentProjects::FILE_NAME),
        "paths = [\"/p/a.dgdaw\", \"/p/b.dgdaw\", \"/p/a.dgdaw\"]\n",
    )
    .unwrap();

    let (store, _) = open(&dir);
    assert_eq!(
        store.recent_projects().paths,
        [PathBuf::from("/p/a.dgdaw"), PathBuf::from("/p/b.dgdaw")]
    );
}
