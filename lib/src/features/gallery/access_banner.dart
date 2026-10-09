import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Reminder shown while file access has not been allowed.
class AccessBanner extends StatelessWidget {
  const AccessBanner({super.key, required this.onAllow, required this.onDismiss});

  final VoidCallback onAllow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.sd_storage_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.deviceBannerTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    l10n.deviceBannerMessage,
                    style: TextStyle(color: GalleryColors.of(context).muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const Key('banner-allow'),
              onPressed: onAllow,
              child: Text(l10n.deviceAllow),
            ),
            IconButton(
              tooltip: l10n.deviceNotNow,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
