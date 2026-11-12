import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:karbeat/src/rust/api/l10n.dart';

/// The flag of [language], from `assets/images/flags/`.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.language, this.width = 24});

  final UiLanguage language;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 3 / 4;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SvgPicture.asset(
        'assets/images/flags/${language.flag}.svg',
        key: ValueKey('language-flag-${language.flag}'),
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => SizedBox(width: width, height: height),
      ),
    );
  }
}
