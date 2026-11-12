//! The languages the user interface is translated into.

/// A language the user interface can be shown in.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Language {
    /// English (United States), the source language every translation starts from.
    EnUs,
    /// Indonesian.
    IdId,
    /// Japanese.
    JaJp,
    /// French (France).
    FrFr,
    /// Spanish (Spain).
    EsEs,
    /// Portuguese (Portugal).
    PtPt,
    /// Dutch (Netherlands).
    NlNl,
    /// Korean.
    KoKr,
    /// Chinese (Simplified).
    ZhCn,
    /// Italian.
    ItIt,
    /// German (Germany).
    DeDe,
}

impl Language {
    /// The source language, used for every message a translation lacks.
    pub const SOURCE: Self = Self::EnUs;

    /// Every language, in the order the language selector lists them.
    pub const ALL: [Self; 11] = [
        Self::EnUs,
        Self::IdId,
        Self::JaJp,
        Self::FrFr,
        Self::EsEs,
        Self::PtPt,
        Self::NlNl,
        Self::KoKr,
        Self::ZhCn,
        Self::ItIt,
        Self::DeDe,
    ];

    /// BCP 47 tag, also the name of the language's folder under `locales/`.
    pub const fn code(self) -> &'static str {
        match self {
            Self::EnUs => "en-US",
            Self::IdId => "id-ID",
            Self::JaJp => "ja-JP",
            Self::FrFr => "fr-FR",
            Self::EsEs => "es-ES",
            Self::PtPt => "pt-PT",
            Self::NlNl => "nl-NL",
            Self::KoKr => "ko-KR",
            Self::ZhCn => "zh-CN",
            Self::ItIt => "it-IT",
            Self::DeDe => "de-DE",
        }
    }

    /// The language's name in itself.
    pub const fn native_name(self) -> &'static str {
        match self {
            Self::EnUs => "English (US)",
            Self::IdId => "Bahasa Indonesia",
            Self::JaJp => "日本語",
            Self::FrFr => "Français",
            Self::EsEs => "Español (España)",
            Self::PtPt => "Português (Portugal)",
            Self::NlNl => "Nederlands",
            Self::KoKr => "한국어",
            Self::ZhCn => "简体中文",
            Self::ItIt => "Italiano",
            Self::DeDe => "Deutsch",
        }
    }

    /// The language's name in English.
    pub const fn english_name(self) -> &'static str {
        match self {
            Self::EnUs => "English (US)",
            Self::IdId => "Indonesian",
            Self::JaJp => "Japanese",
            Self::FrFr => "French",
            Self::EsEs => "Spanish (Spain)",
            Self::PtPt => "Portuguese (Portugal)",
            Self::NlNl => "Dutch",
            Self::KoKr => "Korean",
            Self::ZhCn => "Chinese (Simplified)",
            Self::ItIt => "Italian",
            Self::DeDe => "German",
        }
    }

    /// Lowercase ISO 3166 code of the flag shown next to the language.
    pub const fn flag(self) -> &'static str {
        match self {
            Self::EnUs => "us",
            Self::IdId => "id",
            Self::JaJp => "jp",
            Self::FrFr => "fr",
            Self::EsEs => "es",
            Self::PtPt => "pt",
            Self::NlNl => "nl",
            Self::KoKr => "kr",
            Self::ZhCn => "cn",
            Self::ItIt => "it",
            Self::DeDe => "de",
        }
    }

    /// The language whose [`code`](Self::code) is `code`, ignoring ASCII case.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL
            .into_iter()
            .find(|language| language.code().eq_ignore_ascii_case(code))
    }
}
