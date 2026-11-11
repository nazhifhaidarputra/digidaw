//! Reading and atomically writing one settings file.

use std::{
    fs::{create_dir_all, read_to_string, remove_file, rename},
    io::{ErrorKind, Write},
    path::{Path, PathBuf},
};

use serde::{Serialize, de::DeserializeOwned};
use tempfile::NamedTempFile;
use toml::{Table, Value};

use crate::SettingsError;

/// A value stored in its own TOML file inside the settings directory.
pub trait SettingsFile: Serialize + DeserializeOwned + Default {
    /// File name inside the settings directory.
    const FILE_NAME: &'static str;

    /// Brings stored values that are out of range back into range.
    fn normalize(&mut self) {}
}

/// A settings file that could not be read and was replaced by defaults.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Recovered {
    /// The file that was unreadable.
    pub file: PathBuf,
    /// Where the unreadable file was moved, so it can be inspected or fixed by hand.
    pub backup: PathBuf,
    /// Why the file could not be read.
    pub reason: String,
}

/// Result of loading one settings file.
pub(crate) struct Loaded<T> {
    pub value: T,
    pub recovered: Option<Recovered>,
}

/// Loads `T` from `dir`.
///
/// A missing file gives the defaults. A file that is not valid TOML is moved aside and gives the
/// defaults. Values that do not fit are dropped one by one, and the file is rewritten when
/// anything had to be dropped or brought into range.
pub(crate) fn load<T: SettingsFile>(dir: &Path) -> Result<Loaded<T>, SettingsError> {
    let path = dir.join(T::FILE_NAME);
    let text = match read_to_string(&path) {
        Ok(text) => text,
        Err(error) if error.kind() == ErrorKind::NotFound => {
            return Ok(Loaded {
                value: T::default(),
                recovered: None,
            });
        }
        Err(error) => return Err(error.into()),
    };

    let parsed = text
        .parse::<Table>()
        .map_err(|error| error.to_string())
        .and_then(|table| {
            T::deserialize(Value::Table(table.clone()))
                .map(|value| (table, value))
                .map_err(|error| error.to_string())
        });
    let (table, mut value) = match parsed {
        Ok(parsed) => parsed,
        Err(reason) => {
            let backup = move_aside(&path)?;
            tracing::warn!(
                "Settings file {} is unreadable ({reason}); moved it to {} and using defaults",
                path.display(),
                backup.display(),
            );
            return Ok(Loaded {
                value: T::default(),
                recovered: Some(Recovered {
                    file: path,
                    backup,
                    reason,
                }),
            });
        }
    };

    value.normalize();
    if Value::try_from(&value).ok() != Some(Value::Table(table)) {
        save(dir, &value)?;
    }
    Ok(Loaded {
        value,
        recovered: None,
    })
}

/// Writes `value` to its file in `dir`, replacing the old file only once the new one is complete.
pub(crate) fn save<T: SettingsFile>(dir: &Path, value: &T) -> Result<(), SettingsError> {
    let text = toml::to_string(value)?;
    create_dir_all(dir)?;
    let mut temporary = NamedTempFile::new_in(dir)?;
    temporary.write_all(text.as_bytes())?;
    temporary.as_file().sync_all()?;
    temporary
        .persist(dir.join(T::FILE_NAME))
        .map_err(|error| error.error)?;
    Ok(())
}

/// Moves an unreadable file to `<stem>.bad.toml`, replacing an older backup.
fn move_aside(path: &Path) -> Result<PathBuf, SettingsError> {
    let backup = path.with_extension("bad.toml");
    match remove_file(&backup) {
        Ok(()) => {}
        Err(error) if error.kind() == ErrorKind::NotFound => {}
        Err(error) => return Err(error.into()),
    }
    rename(path, &backup)?;
    Ok(backup)
}
