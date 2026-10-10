# Color themes

A color theme is a JSON file that sets every color of the app. The themes in this folder are bundled with DigiDAW; any other theme file can be loaded from **Settings → Appearance → Color theme**.

```json
{
  "name": "Catppuccin Mocha",
  "brightness": "dark",
  "colors": {
    "primary": "#cba6f7",
    "onPrimary": "#11111b",
    "secondary": "#89b4fa",
    "onSecondary": "#11111b",
    "error": "#f38ba8",
    "onError": "#11111b",
    "surface": "#1e1e2e",
    "onSurface": "#cdd6f4"
  }
}
```

| Field | Rule |
| --- | --- |
| `name` | Text shown in the theme menu, at most 48 characters. |
| `brightness` | `"light"` or `"dark"`. |
| `colors` | Color roles, each written as `"#RRGGBB"` or `"#RRGGBBAA"`. |

The roles are those of Material's `ColorScheme`.

* **Required:** `primary`, `onPrimary`, `secondary`, `onSecondary`, `error`, `onError`, `surface`, `onSurface`.
* **Optional:** `primaryContainer`, `onPrimaryContainer`, `secondaryContainer`, `onSecondaryContainer`, `tertiary`, `onTertiary`, `tertiaryContainer`, `onTertiaryContainer`, `errorContainer`, `onErrorContainer`, `onSurfaceVariant`, `surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`, `outline`, `outlineVariant`, `inverseSurface`, `onInverseSurface`, `inversePrimary`.

An optional role that is left out falls back to the closest required role. Unknown fields and roles are rejected, so a misspelled role is reported instead of being ignored.

Parsing and validation live in `lib/features/setting/services/color_theme_parser.dart`, which converts a file into the `AppColorTheme` model. To bundle a new theme, add the file here, list it in `pubspec.yaml`, and add it to `AppearanceAssetService.bundledColorThemes`.
