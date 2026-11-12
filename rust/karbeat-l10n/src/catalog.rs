//! The embedded Fluent resources, one bundle per language, and message formatting.

use std::{collections::HashSet, fmt::Display, sync::LazyLock};

use fluent::{FluentArgs, FluentResource, FluentValue, concurrent::FluentBundle};
use parking_lot::Mutex;
use tracing::warn;
use unic_langid::LanguageIdentifier;

use crate::Language;

/// The Fluent files of every language, one per area of the app, in load order.
pub const AREAS: [&str; 10] = [
    "common",
    "app",
    "settings",
    "shortcuts",
    "workspace",
    "track",
    "mixer",
    "piano-roll",
    "source",
    "plugins",
];

/// Embeds the files listed in [`AREAS`] of one language folder.
macro_rules! language_sources {
    ($code:literal) => {
        [
            include_str!(concat!("../locales/", $code, "/common.ftl")),
            include_str!(concat!("../locales/", $code, "/app.ftl")),
            include_str!(concat!("../locales/", $code, "/settings.ftl")),
            include_str!(concat!("../locales/", $code, "/shortcuts.ftl")),
            include_str!(concat!("../locales/", $code, "/workspace.ftl")),
            include_str!(concat!("../locales/", $code, "/track.ftl")),
            include_str!(concat!("../locales/", $code, "/mixer.ftl")),
            include_str!(concat!("../locales/", $code, "/piano-roll.ftl")),
            include_str!(concat!("../locales/", $code, "/source.ftl")),
            include_str!(concat!("../locales/", $code, "/plugins.ftl")),
        ]
    };
}

/// The Fluent files of `language`, in the order of [`AREAS`].
pub(crate) fn sources(language: Language) -> [&'static str; AREAS.len()] {
    match language {
        Language::EnUs => language_sources!("en-US"),
        Language::IdId => language_sources!("id-ID"),
        Language::JaJp => language_sources!("ja-JP"),
        Language::FrFr => language_sources!("fr-FR"),
        Language::EsEs => language_sources!("es-ES"),
        Language::PtPt => language_sources!("pt-PT"),
        Language::NlNl => language_sources!("nl-NL"),
        Language::KoKr => language_sources!("ko-KR"),
        Language::ZhCn => language_sources!("zh-CN"),
        Language::ItIt => language_sources!("it-IT"),
        Language::DeDe => language_sources!("de-DE"),
    }
}

/// A value placed into a message, such as `{ $count }`.
#[derive(Clone, Debug, PartialEq)]
pub enum Arg {
    /// Text shown as is.
    Text(String),
    /// A number, which also picks plural variants.
    Number(f64),
}

type Bundle = FluentBundle<FluentResource>;

/// Every language's bundle, in the order of [`Language::ALL`].
pub(crate) struct Catalog {
    bundles: Vec<Bundle>,
}

static CATALOG: LazyLock<Catalog> = LazyLock::new(|| Catalog::new(sources));

/// Message ids already reported as broken, so each is logged once.
static REPORTED: LazyLock<Mutex<HashSet<String>>> = LazyLock::new(Default::default);

impl Catalog {
    /// Builds every language's bundle from the files `load` returns for it.
    pub(crate) fn new<S>(load: impl Fn(Language) -> S) -> Self
    where
        S: IntoIterator<Item = &'static str>,
    {
        let bundles = Language::ALL
            .into_iter()
            .map(|language| bundle(language, load(language)))
            .collect();
        Self { bundles }
    }

    /// Formats `id` in `language`, then in the source language, then gives the id itself.
    pub(crate) fn format(&self, language: Language, id: &str, args: &[(&str, Arg)]) -> String {
        let args = fluent_args(args);
        [language, Language::SOURCE]
            .into_iter()
            .find_map(|language| self.format_in(language, id, &args))
            .unwrap_or_else(|| {
                report_once(id, "the message does not exist");
                id.to_owned()
            })
    }

    fn format_in(&self, language: Language, id: &str, args: &FluentArgs) -> Option<String> {
        let index = Language::ALL.iter().position(|known| *known == language)?;
        let bundle = self.bundles.get(index)?;
        let pattern = bundle.get_message(id)?.value()?;
        let mut errors = Vec::new();
        let text = bundle.format_pattern(pattern, Some(args), &mut errors);
        if !errors.is_empty() {
            report_once(
                id,
                format_args!("{} formatting errors: {errors:?}", language.code()),
            );
        }
        Some(text.into_owned())
    }
}

/// Formats message `id` in `language`.
///
/// A message the language lacks is taken from English (US). A message that does not exist at
/// all gives `id` itself, so a missing string shows up in the UI instead of an empty label.
pub fn format(language: Language, id: &str, args: &[(&str, Arg)]) -> String {
    CATALOG.format(language, id, args)
}

fn bundle(language: Language, sources: impl IntoIterator<Item = &'static str>) -> Bundle {
    let tag = language
        .code()
        .parse::<LanguageIdentifier>()
        .unwrap_or_default();
    let mut bundle = FluentBundle::new_concurrent(vec![tag]);
    // None of the languages is right-to-left, and Flutter would draw the isolation marks.
    bundle.set_use_isolating(false);
    for (index, source) in sources.into_iter().enumerate() {
        let area = AREAS.get(index).copied().unwrap_or("extra");
        let resource = match FluentResource::try_new(source.to_owned()) {
            Ok(resource) => resource,
            Err((resource, errors)) => {
                warn!(
                    "{}/{area}.ftl has syntax errors: {errors:?}",
                    language.code()
                );
                resource
            }
        };
        if let Err(errors) = bundle.add_resource(resource) {
            warn!(
                "{}/{area}.ftl could not be added: {errors:?}",
                language.code()
            );
        }
    }
    bundle
}

fn fluent_args<'a>(args: &'a [(&'a str, Arg)]) -> FluentArgs<'a> {
    let mut fluent = FluentArgs::with_capacity(args.len());
    for (name, value) in args {
        let value = match value {
            Arg::Text(text) => FluentValue::from(text.as_str()),
            Arg::Number(number) => FluentValue::from(*number),
        };
        fluent.set(*name, value);
    }
    fluent
}

fn report_once(id: &str, problem: impl Display) {
    if REPORTED.lock().insert(id.to_owned()) {
        warn!("Translation '{id}': {problem}");
    }
}
