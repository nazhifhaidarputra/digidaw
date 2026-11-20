/// Font families bundled with the app; each is declared in pubspec.yaml with
/// its files and license under assets/fonts/.
abstract final class AppFonts {
  /// The font used until the user picks another one.
  static const defaultFamily = 'IBM Plex Sans';

  /// Bundled families offered in the font menu: the default first, then the
  /// most used open-source Google Fonts.
  static const bundled = [
    defaultFamily,
    'Roboto',
    'Open Sans',
    'Noto Sans',
    'Montserrat',
    'Poppins',
    'Lato',
    'Inter',
    'Roboto Condensed',
    'Oswald',
    'Raleway',
    'Nunito',
    'Roboto Mono',
    'Ubuntu',
    'Rubik',
    'Work Sans',
    'Fira Sans',
    'DM Sans',
    'Source Sans 3',
    'Merriweather',
    'Playfair Display',
  ];
}
