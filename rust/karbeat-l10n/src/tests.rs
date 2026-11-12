use std::collections::{BTreeMap, BTreeSet};

use fluent_syntax::{
    ast::{CallArguments, Entry, Expression, InlineExpression, Pattern, PatternElement},
    parser::parse,
};

use super::*;
use crate::catalog::{Catalog, sources};

/// Message id → variables the message uses, for one language.
type Messages = BTreeMap<String, BTreeSet<String>>;

/// Parses every file of `language`, failing on syntax errors and duplicate ids.
fn messages(language: Language) -> Messages {
    let mut messages = Messages::new();
    let mut terms = BTreeSet::new();
    for (area, source) in AREAS.iter().zip(sources(language)) {
        let file = format!("{}/{area}.ftl", language.code());
        let resource = parse(source)
            .unwrap_or_else(|(_, errors)| panic!("{file} has syntax errors: {errors:?}"));
        for entry in resource.body {
            match entry {
                Entry::Message(message) => {
                    let mut variables = BTreeSet::new();
                    if let Some(pattern) = &message.value {
                        pattern_variables(pattern, &mut variables);
                    }
                    let id = message.id.name.to_owned();
                    assert!(
                        messages.insert(id.clone(), variables).is_none(),
                        "{file} repeats message '{id}'"
                    );
                }
                Entry::Term(term) => {
                    assert!(
                        terms.insert(term.id.name.to_owned()),
                        "{file} repeats term '-{}'",
                        term.id.name
                    );
                }
                Entry::Junk { content } => panic!("{file} has junk: {content}"),
                _ => {}
            }
        }
    }
    messages
}

fn pattern_variables(pattern: &Pattern<&str>, variables: &mut BTreeSet<String>) {
    for element in &pattern.elements {
        if let PatternElement::Placeable { expression } = element {
            expression_variables(expression, variables);
        }
    }
}

fn expression_variables(expression: &Expression<&str>, variables: &mut BTreeSet<String>) {
    match expression {
        Expression::Select { selector, variants } => {
            inline_variables(selector, variables);
            for variant in variants {
                pattern_variables(&variant.value, variables);
            }
        }
        Expression::Inline(inline) => inline_variables(inline, variables),
    }
}

fn inline_variables(inline: &InlineExpression<&str>, variables: &mut BTreeSet<String>) {
    match inline {
        InlineExpression::VariableReference { id } => {
            variables.insert(id.name.to_owned());
        }
        InlineExpression::FunctionReference { arguments, .. } => {
            call_variables(arguments, variables);
        }
        InlineExpression::TermReference {
            arguments: Some(arguments),
            ..
        } => call_variables(arguments, variables),
        InlineExpression::Placeable { expression } => expression_variables(expression, variables),
        _ => {}
    }
}

fn call_variables(arguments: &CallArguments<&str>, variables: &mut BTreeSet<String>) {
    for positional in &arguments.positional {
        inline_variables(positional, variables);
    }
    for named in &arguments.named {
        inline_variables(&named.value, variables);
    }
}

#[test]
fn every_language_parses_without_duplicates() {
    for language in Language::ALL {
        messages(language);
    }
}

#[test]
fn translations_only_use_source_ids_and_variables() {
    let source = messages(Language::SOURCE);
    for language in Language::ALL {
        for (id, variables) in messages(language) {
            let source_variables = source
                .get(&id)
                .unwrap_or_else(|| panic!("{} has '{id}', which en-US lacks", language.code()));
            let unknown: Vec<_> = variables.difference(source_variables).collect();
            assert!(
                unknown.is_empty(),
                "{} '{id}' uses variables en-US does not pass: {unknown:?}",
                language.code()
            );
        }
    }
}

#[test]
fn every_message_formats_in_every_language() {
    let source = messages(Language::SOURCE);
    for language in Language::ALL {
        for (id, variables) in &source {
            for count in [1.0, 2.0, 5.0] {
                let args: Vec<_> = variables
                    .iter()
                    .map(|name| (name.as_str(), Arg::Number(count)))
                    .collect();
                let text = format(language, id, &args);
                assert_ne!(&text, id, "{} could not format '{id}'", language.code());
                assert!(
                    !text.contains("{$") && !text.contains("{-"),
                    "{} '{id}' left a placeable unresolved: {text}",
                    language.code()
                );
            }
        }
    }
}

#[test]
fn language_change_warning_keeps_the_requested_wording() {
    assert_eq!(
        format(Language::EnUs, "settings-language-change-warning", &[]),
        "You are going to change your app language. Remember where the menu is so that you \
         are not lost in translation. Are you sure you want to change your language?"
    );
}

#[test]
fn every_language_translates_the_language_change_warning() {
    let english = format(Language::EnUs, "settings-language-change-warning", &[]);
    for language in Language::ALL.into_iter().skip(1) {
        assert_ne!(
            format(language, "settings-language-change-warning", &[]),
            english,
            "{} lacks the language change warning",
            language.code()
        );
    }
}

fn test_catalog() -> Catalog {
    Catalog::new(|language| match language {
        Language::EnUs => vec![
            "greeting = Hello, { $name }!\n\
             only-english = Only English\n\
             items = { $count ->\n    [one] One item\n   *[other] { $count } items\n}\n",
        ],
        Language::DeDe => vec![
            "greeting = Hallo, { $name }!\n\
             items = { $count ->\n    [one] Ein Element\n   *[other] { $count } Elemente\n}\n",
        ],
        _ => Vec::new(),
    })
}

#[test]
fn format_falls_back_to_english_then_to_the_id() {
    let catalog = test_catalog();
    let name = [("name", Arg::Text("Ana".to_owned()))];

    assert_eq!(
        catalog.format(Language::DeDe, "greeting", &name),
        "Hallo, Ana!"
    );
    assert_eq!(
        catalog.format(Language::DeDe, "only-english", &[]),
        "Only English"
    );
    assert_eq!(
        catalog.format(Language::JaJp, "greeting", &name),
        "Hello, Ana!"
    );
    assert_eq!(
        catalog.format(Language::DeDe, "no-such-message", &[]),
        "no-such-message"
    );
}

#[test]
fn numbers_pick_plural_variants() {
    let catalog = test_catalog();

    assert_eq!(
        catalog.format(Language::EnUs, "items", &[("count", Arg::Number(1.0))]),
        "One item"
    );
    assert_eq!(
        catalog.format(Language::EnUs, "items", &[("count", Arg::Number(3.0))]),
        "3 items"
    );
    assert_eq!(
        catalog.format(Language::DeDe, "items", &[("count", Arg::Number(3.0))]),
        "3 Elemente"
    );
}

#[test]
fn languages_round_trip_their_codes() {
    for language in Language::ALL {
        assert_eq!(Language::from_code(language.code()), Some(language));
    }
    assert_eq!(Language::from_code("JA-jp"), Some(Language::JaJp));
    assert_eq!(Language::from_code("xx-XX"), None);
}

fn resolved(locales: &[&str]) -> Language {
    let locales: Vec<String> = locales.iter().map(|locale| (*locale).to_owned()).collect();
    resolve(&locales)
}

#[test]
fn resolve_prefers_region_then_language_then_english() {
    assert_eq!(resolved(&["ja_JP.UTF-8"]), Language::JaJp);
    assert_eq!(resolved(&["pt-BR"]), Language::PtPt);
    assert_eq!(resolved(&["es-MX", "fr-FR"]), Language::EsEs);
    assert_eq!(resolved(&["sv-SE", "de-AT"]), Language::DeDe);
    assert_eq!(resolved(&["en-GB"]), Language::EnUs);
    assert_eq!(resolved(&["zh-Hans-CN"]), Language::ZhCn);
    assert_eq!(resolved(&["zh-TW"]), Language::EnUs);
    assert_eq!(resolved(&["zh-Hant", "ko-KR"]), Language::KoKr);
    assert_eq!(resolved(&["sv-SE"]), Language::EnUs);
    assert_eq!(resolved(&["C", "not a locale"]), Language::EnUs);
    assert_eq!(resolved(&[]), Language::EnUs);
}

/// Lists the en-US messages each language lacks. Run with
/// `cargo test -p karbeat-l10n coverage -- --ignored --nocapture`.
#[test]
#[ignore = "a report for translators, not a check"]
#[allow(clippy::print_stdout, reason = "the report is the test's output")]
fn coverage() {
    let source = messages(Language::SOURCE);
    for language in Language::ALL.into_iter().skip(1) {
        let translated = messages(language);
        let missing: Vec<_> = source
            .keys()
            .filter(|id| !translated.contains_key(*id))
            .collect();
        println!(
            "{} ({}): {}/{} translated",
            language.code(),
            language.english_name(),
            source.len() - missing.len(),
            source.len()
        );
        for id in missing {
            println!("  missing {id}");
        }
    }
}
