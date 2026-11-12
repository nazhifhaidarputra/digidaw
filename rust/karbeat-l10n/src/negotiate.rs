//! Picks the user interface language from the operating system's preferred locales.

use unic_langid::LanguageIdentifier;

use crate::Language;

/// The first of `system_locales` (most preferred first) that a translation covers, or the
/// source language when none is.
///
/// A locale matches a language with the same language and region, or failing that, the same
/// language alone: `pt-BR` gets Portuguese (Portugal). Traditional Chinese locales never get
/// Simplified Chinese.
pub fn resolve(system_locales: &[String]) -> Language {
    system_locales
        .iter()
        .filter_map(|locale| parse(locale))
        .find_map(|locale| best_match(&locale))
        .unwrap_or(Language::SOURCE)
}

/// Parses a locale such as `ja_JP.UTF-8` or `de-DE`.
fn parse(locale: &str) -> Option<LanguageIdentifier> {
    let tag = locale.split(['.', '@']).next()?.replace('_', "-");
    tag.parse().ok()
}

fn best_match(locale: &LanguageIdentifier) -> Option<Language> {
    if is_traditional_chinese(locale) {
        return None;
    }
    let candidates = Language::ALL.into_iter().filter_map(|language| {
        let tag: LanguageIdentifier = language.code().parse().ok()?;
        (tag.language == locale.language).then_some((language, tag))
    });
    let mut same_language = None;
    for (language, tag) in candidates {
        if locale.region.is_some() && tag.region == locale.region {
            return Some(language);
        }
        same_language.get_or_insert(language);
    }
    same_language
}

fn is_traditional_chinese(locale: &LanguageIdentifier) -> bool {
    locale.language.as_str() == "zh"
        && (locale
            .script
            .is_some_and(|script| script.as_str() == "Hant")
            || locale
                .region
                .is_some_and(|region| matches!(region.as_str(), "TW" | "HK" | "MO")))
}
