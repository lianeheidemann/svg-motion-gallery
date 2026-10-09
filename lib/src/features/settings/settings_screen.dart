import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/app_settings.dart';
import '../../l10n/l10n.dart';
import '../../widgets/svg_actions_menu.dart';

/// Playback, appearance, file and storage preferences. The theme and the
/// language are switched from the home screen, so they are not repeated here.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<({int library, int backups})> _usage;
  int? _slideshowSeconds;

  /// Percent shown while the size slider is being dragged. The interface is
  /// only resized on release: rescaling mid-drag would move the slider away
  /// from the finger.
  int? _uiScalePercent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _usage = AppScope.of(context).library.usage();
  }

  void _refreshUsage() => setState(() => _usage = AppScope.of(context).library.usage());

  String _accentName(AppLocalizations l10n, AccentColor accent) => switch (accent) {
    AccentColor.blue => l10n.accentBlue,
    AccentColor.purple => l10n.accentPurple,
    AccentColor.pink => l10n.accentPink,
    AccentColor.cyan => l10n.accentCyan,
    AccentColor.orange => l10n.accentOrange,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = AppScope.of(context);
    final settings = services.settings;
    final muted = TextStyle(color: GalleryColors.of(context).muted);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsTitle),
            Text(l10n.settingsSubtitle, style: Theme.of(context).textTheme.bodySmall?.merge(muted)),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final value = settings.value;
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                SectionCard(
                  icon: Icons.play_arrow_rounded,
                  title: l10n.playbackSection,
                  children: [
                    SettingSwitchTile(
                      title: l10n.autoplayTitle,
                      value: value.autoplay,
                      onChanged: settings.setAutoplay,
                    ),
                    SettingSwitchTile(
                      title: l10n.loopTitle,
                      value: value.loop && value.autoplay,
                      onChanged: value.autoplay ? settings.setLoop : null,
                    ),
                    SettingSwitchTile(
                      title: l10n.hqTitle,
                      value: value.highQualityPreviews,
                      onChanged: settings.setHighQualityPreviews,
                    ),
                    SliderField(
                      label: l10n.slideshowInterval,
                      labelWidth: 120,
                      value: (_slideshowSeconds ?? value.slideshowSeconds).toDouble(),
                      min: 2,
                      max: 30,
                      divisions: 28,
                      unit: 's',
                      onChanged: (v) => setState(() => _slideshowSeconds = v.round()),
                      onChangeEnd: (v) {
                        _slideshowSeconds = null;
                        settings.setSlideshowSeconds(v.round());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  icon: Icons.palette_outlined,
                  title: l10n.appearanceSection,
                  children: [
                    Text(l10n.accentTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ColorSwatchPicker(
                      colors: [for (final accent in AccentColor.values) accent.color],
                      selected: value.accent.color,
                      semanticLabel: (color) => _accentName(
                        l10n,
                        AccentColor.values.firstWhere((accent) => accent.color == color),
                      ),
                      onSelected: (color) => settings.setAccent(
                        AccentColor.values.firstWhere((accent) => accent.color == color),
                      ),
                    ),
                    const Divider(height: 1),
                    SliderField(
                      key: const Key('ui-scale'),
                      label: l10n.uiScaleTitle,
                      labelWidth: 120,
                      value: (_uiScalePercent ?? (value.uiScale * 100).round()).toDouble(),
                      min: AppSettings.minUiScale * 100,
                      max: AppSettings.maxUiScale * 100,
                      divisions: 14,
                      unit: '%',
                      onChanged: (v) => setState(() => _uiScalePercent = v.round()),
                      onChangeEnd: (v) {
                        _uiScalePercent = null;
                        settings.setUiScale(v / 100);
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('ui-scale-reset'),
                        onPressed: value.uiScale == AppSettings.defaultUiScale
                            ? null
                            : () => settings.setUiScale(AppSettings.defaultUiScale),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: Text(l10n.uiScaleReset),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  icon: Icons.description_outlined,
                  title: l10n.filesSection,
                  children: [
                    SettingSwitchTile(
                      title: l10n.backupTitle,
                      subtitle: l10n.backupSubtitle,
                      value: value.autoBackup,
                      onChanged: settings.setAutoBackup,
                    ),
                    SettingSwitchTile(
                      key: const Key('setting-auto-format'),
                      title: l10n.autoFormat,
                      subtitle: l10n.autoFormatSubtitle,
                      value: value.autoFormatCode,
                      onChanged: settings.setAutoFormatCode,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SectionCard(
                  icon: Icons.storage_rounded,
                  title: l10n.storageSection,
                  children: [
                    FutureBuilder(
                      future: _usage,
                      builder: (context, snapshot) {
                        final usage = snapshot.data;
                        if (usage == null) return const LinearProgressIndicator();
                        final total = usage.library + usage.backups;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(l10n.storageUsage)),
                                Text(
                                  l10n.bytes(total),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: total == 0 ? 0 : usage.library / total,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.storageBreakdown(
                                l10n.bytes(usage.library),
                                l10n.bytes(usage.backups),
                              ),
                              style: muted,
                            ),
                          ],
                        );
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await services.library.restoreDemos();
                            _refreshUsage();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(l10n.demosRestored)));
                            }
                          },
                          icon: const Icon(Icons.auto_awesome_outlined),
                          label: Text(l10n.restoreDemos),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final confirmed = await showConfirmDialog(
                              context,
                              title: l10n.clearBackupsTitle,
                              message: l10n.clearBackupsMessage,
                              confirm: l10n.clearBackups,
                              destructive: true,
                            );
                            if (!confirmed) return;
                            await services.library.clearBackups();
                            _refreshUsage();
                          },
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: Text(l10n.clearBackups),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
