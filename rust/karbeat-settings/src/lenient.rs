//! Deserializers that drop the parts of a settings file that do not fit, instead of failing.

use std::collections::BTreeMap;

use serde::{Deserialize, Deserializer, de::DeserializeOwned};
use toml::{Table, Value};

/// Reads a section, dropping each value that does not fit so it falls back to its default.
///
/// `S` must use `#[serde(default)]`, so a dropped field takes its value from `S::default()`.
/// A section that is not a table gives `S::default()`.
pub(crate) fn section<'de, D, S>(deserializer: D) -> Result<S, D::Error>
where
    D: Deserializer<'de>,
    S: DeserializeOwned + Default,
{
    let Value::Table(table) = Value::deserialize(deserializer)? else {
        tracing::warn!("A settings section is not a table; using its defaults");
        return Ok(S::default());
    };
    if let Ok(section) = S::deserialize(Value::Table(table.clone())) {
        return Ok(section);
    }

    let kept: Table = table
        .into_iter()
        .filter(|(key, value)| {
            let single = Table::from_iter([(key.clone(), value.clone())]);
            let fits = S::deserialize(Value::Table(single)).is_ok();
            if !fits {
                tracing::warn!("Ignoring the invalid setting '{key}'");
            }
            fits
        })
        .collect();
    Ok(S::deserialize(Value::Table(kept)).unwrap_or_default())
}

/// Reads a list into any collection, skipping each item that does not fit.
pub(crate) fn list<'de, D, C, T>(deserializer: D) -> Result<C, D::Error>
where
    D: Deserializer<'de>,
    C: FromIterator<T> + IntoIterator<Item = T>,
    T: DeserializeOwned,
{
    let Value::Array(items) = Value::deserialize(deserializer)? else {
        tracing::warn!("A settings list is not an array; using an empty list");
        return Ok(C::from_iter([]));
    };
    Ok(items
        .into_iter()
        .filter_map(|item| match T::deserialize(item) {
            Ok(item) => Some(item),
            Err(error) => {
                tracing::warn!("Ignoring an invalid settings entry: {error}");
                None
            }
        })
        .collect())
}

/// Reads a table of entries, skipping each entry that does not fit.
pub(crate) fn map<'de, D, T>(deserializer: D) -> Result<BTreeMap<String, T>, D::Error>
where
    D: Deserializer<'de>,
    T: DeserializeOwned,
{
    let Value::Table(entries) = Value::deserialize(deserializer)? else {
        tracing::warn!("A settings table is not a table; using an empty table");
        return Ok(BTreeMap::new());
    };
    Ok(entries
        .into_iter()
        .filter_map(|(key, value)| match T::deserialize(value) {
            Ok(value) => Some((key, value)),
            Err(error) => {
                tracing::warn!("Ignoring the invalid settings entry '{key}': {error}");
                None
            }
        })
        .collect())
}
