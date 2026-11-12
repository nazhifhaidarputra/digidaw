# Translating DigiDAW

DigiDAW's user interface is translated with [Fluent](https://projectfluent.org), Mozilla's localization system. Every message lives in a plain-text `.ftl` file in this crate, and the Rust [`fluent`](https://crates.io/crates/fluent) crate formats it. The Flutter app asks Rust for each message, so a translation never needs Dart or Rust knowledge, only a text editor.

This guide is for anyone who wants to fix a translation, translate a part of the app that is still in English, add a new message, or add a whole new language.

---

## Languages

| Code | Language | Flag |
| --- | --- | --- |
| `en-US` | English (US), the source language | `us` |
| `id-ID` | Indonesian | `id` |
| `ja-JP` | Japanese | `jp` |
| `fr-FR` | French (France) | `fr` |
| `es-ES` | Spanish (Spain) | `es` |
| `pt-PT` | Portuguese (Portugal) | `pt` |
| `nl-NL` | Dutch (Netherlands) | `nl` |
| `ko-KR` | Korean | `kr` |
| `zh-CN` | Chinese (Simplified) | `cn` |
| `it-IT` | Italian | `it` |
| `de-DE` | German (Germany) | `de` |

The language is chosen in **Settings → General → Language**. A fresh install follows the operating system language when it is one of the languages above, and English otherwise.

> The current translations were written with machine assistance and checked for consistency, not by native speakers of every language. Corrections from native speakers are very welcome. A pull request that only fixes wording is a great first contribution.

---

## Where the files are

```text
rust/karbeat-l10n/
  locales/
    en-US/            source language: every message starts here
      common.ftl      words used everywhere (OK, Cancel, Save…)
      app.ftl         menu bar, startup, notifications from the app core
      settings.ftl    the Settings screen and its pages
      shortcuts.ftl   keyboard shortcut names and categories
      workspace.ftl   control panel, export panel, project dialogs
      track.ftl       track list, clips, automation lanes
      mixer.ftl       mixer, routing, sidechains
      piano-roll.ftl  piano roll and MIDI keyboard
      source.ftl      source list and audio properties
      plugins.ftl     plugin browser and first-party plugin screens
    ja-JP/            the same files, translated
    …
  src/
    language.rs       the list of languages
    catalog.rs        loads the files and formats messages
    negotiate.rs      picks a language from the system locale
    tests.rs          checks every file (see "Checking your work")
```

Every language folder has the same ten files. The files are embedded into the app when it is built, so a change shows up after the next build.

---

## Fluent in five minutes

A message is an id, ` = `, and its text:

```ftl
settings-general-auto-save-enable = Enable auto save
```

### Placeholders

Values the app fills in are written `{ $name }`. Keep every placeholder that the English message uses, and never invent new ones (the tests reject unknown placeholders). You can move placeholders to wherever your language needs them:

```ftl
# en-US
workspace-unsaved-message = Save the changes to "{ $name }" before closing it? Unsaved changes will be lost.
# ja-JP
workspace-unsaved-message = 閉じる前に「{ $name }」の変更を保存しますか？保存しない変更は失われます。
```

### Plurals and other choices

A message can pick a variant from a value. The variant marked `*` is the default and is required:

```ftl
track-clips-selected = { $count ->
    [one] { $count } Clip
   *[other] { $count } Clips
}
```

Numbers are matched with your language's [CLDR plural categories](https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html) (`zero`, `one`, `two`, `few`, `many`, `other`), so Polish, for example, can use `[few]` and `[many]`. Exact numbers such as `[0]` also work. Languages without plural forms can drop the choice entirely:

```ftl
# ko-KR
track-clips-selected = 클립 { $count }개
```

Some choices are made on words rather than numbers, for example the track type in `app-tracks-move-type-mismatch`. Keep the keys (`[audio]`, `[midi]`, `*[automation]`) and translate only the text.

### The app name

`{ -app-name }` is a *term* defined in `common.ftl`. It always reads "DigiDAW". Use it instead of typing the name.

### Spaces and long lines

Fluent trims spaces at the start and end of a message. When a message must start or end with a space, write it as a quoted literal: `Grid{" "}`.

A long message can continue on the next lines if they are indented:

```ftl
settings-appearance-theme-remove-message = “{ $name }” will be removed from the theme menu.

    The file { $file } is not deleted.
```

Comments start with `#`; `##` comments name a section of the file.

---

## Translating

1. Open the file for the area you want to improve, in your language's folder, next to the same file in `en-US/`.
2. Translate the text after ` = `. Never change the id on the left.
3. Keep the shortcut keys, units and names that should stay as they are: `Ctrl`, `Alt+1`, `Hz`, `dB`, `ms`, `BPM`, `MIDI`, `VST3`, and file extensions like `.dgdaw`.
4. Run the checks in [Checking your work](#checking-your-work).

### Style

- Use the terms the musicians in your language already know from other DAWs. When a technical term is usually left in English (for example *sidechain* or *plugin*), leave it in English.
- Keep a term the same everywhere. If a message names a menu or button ("choose **Save as template**"), use the exact wording of that menu or button in your translation.
- Labels in the control panel (`workspace-readout-*`), buttons and tabs have little room. Prefer short words or common abbreviations there.
- Match the tone of the existing translation: German uses *du*, French *vous*, Spanish *tú*, Italian *tu* and Dutch *je*.

### A language that falls behind

When a message is missing from a language, the app shows the English text for it. Nothing breaks, so it is fine to add an English message without translating it into every language. To see what each language is missing, run:

```sh
cd rust
cargo test -p karbeat-l10n coverage -- --ignored --nocapture
```

---

## Adding or changing a message in the app

When you add text to the Flutter UI, add it to the English file first, then use it from Dart.

1. Pick the file for the area and add the message to `locales/en-US/<area>.ftl`:

   ```ftl
   mixer-delete-bus = Delete Bus
   ```

   Name the id `<area>-<what>` in lowercase words joined by `-`. Say what the text is for, not what it currently says (`mixer-sidechain-self`, not `mixer-a-channel-cannot`).

2. Use it in Dart through `tr`, from `package:karbeat/core/l10n/localizer.dart`:

   ```dart
   Text(tr('mixer-delete-bus'))
   Text(tr('track-clips-selected', {'count': selectedClipIds.length}))
   ```

   `tr` works anywhere, not only in widgets: notifiers use it for notification titles too. Pass numbers as `int` or `double` so plural variants work. Anything else is shown as text.

3. Add translations for the languages you can write. The others fall back to English until someone translates them.

Rules that keep the messages checkable:

- **Always pass a literal id**, never one built at runtime (`tr('settings-menu-${menu.name}')`). Use a `switch` with one `tr('…')` call per case instead. The test `test/core/l10n/message_ids_test.dart` scans `lib/` for literal ids and fails on any id that is missing from `en-US`.
- **One message per sentence.** Do not glue translated pieces together (`'${tr('a')} ${tr('b')}'`). Word order differs between languages; give the whole sentence to Fluent with placeholders.
- **Do not lowercase or uppercase translated text in code.** Write the case you want into the message.
- Strings a `const` constructor needs at compile time cannot call `tr`. Store the message id instead (as `DawShortcut.titleId` and `DawToolbarMenuAction` do) and call `tr` when the text is shown.
- When the language changes, the app rebuilds every widget once, so text that a `build` method formats is always current. Text that you store in state (for example in a notifier) keeps the language it was formatted in until it is formatted again.

To rename an id, change it in every language folder and in `lib/` together.

---

## Adding a language

1. Add a variant to `Language` in `src/language.rs` and give it a code, native name, English name and flag in each `match`. Add it to `Language::ALL` in the position the selector should show it.
2. Add `language_sources!("xx-YY")` for it in `sources()` in `src/catalog.rs`.
3. Create `locales/xx-YY/` with all ten `.ftl` files. Copy `common.ftl` from another language first: it holds the `-app-name` term.
4. Add the flag as `assets/images/flags/<flag>.svg`. We use the 4×3 SVGs from [flag-icons](https://github.com/lipis/flag-icons) (MIT, already credited in **Info → View licenses**).
5. Check that Flutter's own Material translations support the language (`GlobalMaterialLocalizations.delegate.isSupported`). Almost all common languages are supported. Nothing else in Dart needs to change: the supported locales come from Rust.
6. If system locales should resolve to it in a special way (as Traditional Chinese must not pick Simplified Chinese), extend `src/negotiate.rs` and its tests.
7. Run the checks below. The bridge does not need to be regenerated: the language list crosses it as data.

---

## Checking your work

From the repository root:

```sh
# Every file parses, ids are unique, translations only use known ids and placeholders,
# and every message formats in every language.
cd rust && cargo test -p karbeat-l10n

# Every tr('…') id in the Dart code exists in English.
flutter test test/core/l10n
```

Widget tests format messages from the English `.ftl` files without loading Rust (see `test/helpers/ftl_test_localizer.dart`), so a test that looks for English text keeps working when you move that text into Fluent.

Then build and run the app, switch to your language in **Settings → General → Language**, and look at the screens you changed. Long words can overflow narrow buttons; shorten them if they do.

### Fonts

Japanese, Korean and Chinese need a font with CJK glyphs. Flutter falls back to the system fonts, so on Linux install a CJK font such as Noto Sans CJK (`google-noto-sans-cjk-fonts` on Fedora, `fonts-noto-cjk` on Debian and Ubuntu) if those characters show as boxes. A custom application font from **Settings → Appearance** is used for the characters it contains, and the system font for the rest.

---

## What is not translated

- **Plugin parameter names and plugin names.** They come from the plugins themselves (and, for first-party plugins, from the manifests in `assets/manifests/audio-plugins/`) and are also used to save automation, so they stay as the plugin defines them.
- **Error details from the engine.** A notification's title is translated, but the detail text that comes from Rust (`anyhow` error chains, file system errors) stays in English, so it can be searched for and reported.
- **Log messages** in the log viewer and log files, for the same reason.
- **The loading and startup-error screens.** They appear before the Rust library is loaded, or when it fails to load, so Fluent is not available yet.
- **Project content** such as track, clip and pattern names, and names that the app suggests once and then stores in the project (such as "Bus 1").
