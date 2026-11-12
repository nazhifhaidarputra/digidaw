//! The user interface language and its translated messages, formatted by `karbeat-l10n`.
//!
//! Dart asks for every message through [`l10n_format`], a synchronous call, in the language
//! [`apply_language`] or [`save_language`] last activated.

use anyhow::anyhow;
use flutter_rust_bridge::frb;
use karbeat_l10n::{Arg, Language, format, resolve};
use parking_lot::RwLock;

use crate::api::settings::{store_language, stored_language};

/// The language messages are formatted in.
static ACTIVE: RwLock<Language> = RwLock::new(Language::SOURCE);

/// A language the user interface is translated into.
#[derive(Clone, Debug, PartialEq, Eq)]
#[frb(dart_metadata=("freezed"))]
pub struct UiLanguage {
    /// BCP 47 code, such as `ja-JP`.
    pub code: String,
    /// The language's name in itself.
    pub native_name: String,
    /// The language's name in English.
    pub english_name: String,
    /// Lowercase ISO 3166 code of its flag, naming `assets/images/flags/<flag>.svg`.
    pub flag: String,
}

impl From<Language> for UiLanguage {
    fn from(language: Language) -> Self {
        Self {
            code: language.code().to_owned(),
            native_name: language.native_name().to_owned(),
            english_name: language.english_name().to_owned(),
            flag: language.flag().to_owned(),
        }
    }
}

/// The chosen language and the one in use.
#[derive(Clone, Debug, PartialEq, Eq)]
#[frb(dart_metadata=("freezed"))]
pub struct UiLanguageState {
    /// The saved choice; `None` follows the system language.
    pub selected: Option<String>,
    /// The language messages are shown in.
    pub active: UiLanguage,
    /// The language the system locales resolve to, shown with the "System default" choice.
    pub system: UiLanguage,
}

/// A value placed into a message.
#[derive(Clone, Debug)]
pub enum UiL10nValue {
    Text(String),
    Number(f64),
}

/// A named value placed into a message, such as `{ $count }`.
#[derive(Clone, Debug)]
pub struct UiL10nArg {
    pub name: String,
    pub value: UiL10nValue,
}

/// Every language, in the order the language selector lists them.
#[frb(sync)]
pub fn available_languages() -> Vec<UiLanguage> {
    Language::ALL.into_iter().map(Into::into).collect()
}

/// Formats message `id` in the active language.
#[frb(sync)]
pub fn l10n_format(id: String, args: Vec<UiL10nArg>) -> String {
    let language = *ACTIVE.read();
    format_message(language, &id, &args)
}

/// Formats message `id` in the language `code`, or in the active language when `code` is not
/// a known language.
#[frb(sync)]
pub fn l10n_format_in(code: String, id: String, args: Vec<UiL10nArg>) -> String {
    let language = Language::from_code(&code).unwrap_or_else(|| *ACTIVE.read());
    format_message(language, &id, &args)
}

/// Activates the saved language, or the system language when none is saved or the saved one is
/// unknown. `system_locales` are the operating system's locales, most preferred first.
pub fn apply_language(system_locales: Vec<String>) -> anyhow::Result<UiLanguageState> {
    let selected = stored_language()?.and_then(|code| Language::from_code(&code));
    Ok(activate(selected, &system_locales))
}

/// Saves and activates language `code`; `None` follows the system language.
pub fn save_language(
    code: Option<String>,
    system_locales: Vec<String>,
) -> anyhow::Result<UiLanguageState> {
    let selected = code
        .map(|code| Language::from_code(&code).ok_or_else(|| anyhow!("Unknown language '{code}'")))
        .transpose()?;
    store_language(selected.map(|language| language.code().to_owned()))?;
    Ok(activate(selected, &system_locales))
}

fn activate(selected: Option<Language>, system_locales: &[String]) -> UiLanguageState {
    let system = resolve(system_locales);
    let active = selected.unwrap_or(system);
    *ACTIVE.write() = active;
    UiLanguageState {
        selected: selected.map(|language| language.code().to_owned()),
        active: active.into(),
        system: system.into(),
    }
}

fn format_message(language: Language, id: &str, args: &[UiL10nArg]) -> String {
    let args: Vec<_> = args
        .iter()
        .map(|arg| {
            let value = match &arg.value {
                UiL10nValue::Text(text) => Arg::Text(text.clone()),
                UiL10nValue::Number(number) => Arg::Number(*number),
            };
            (arg.name.as_str(), value)
        })
        .collect();
    format(language, id, &args)
}
