import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/app_settings.dart';
import '../l10n/l10n.dart';

/// Home screen button that switches between the light and dark theme.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final l10n = context.l10n;
    // Listens itself: as a const widget it is not rebuilt by its parent.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final dark = settings.value.darkMode;
        return IconButton(
          key: const Key('theme-toggle'),
          tooltip: dark ? l10n.switchToLight : l10n.switchToDark,
          onPressed: settings.toggleTheme,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) =>
                RotationTransition(turns: animation, child: child),
            child: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(dark),
            ),
          ),
        );
      },
    );
  }
}

/// Home screen button that translates the whole app (PT ⇄ EN). It shows
/// the language it switches to.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(listenable: settings, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final toEnglish = settings.value.language == AppLanguage.portuguese;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.l10n.switchLanguage,
      child: Semantics(
        button: true,
        label: context.l10n.switchLanguage,
        excludeSemantics: true,
        child: InkWell(
          key: const Key('language-toggle'),
          onTap: settings.toggleLanguage,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  toEnglish ? 'EN' : 'PT',
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
