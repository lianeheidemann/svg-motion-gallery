import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/svg_document.dart';
import '../l10n/l10n.dart';

/// File actions offered from the gallery card and the viewer.
enum SvgAction { rename, duplicate, share, delete }

/// "⋮" menu with file actions. The same widget (and the same handlers)
/// serves every screen; each screen only picks which [actions] to show so a
/// screen never offers the same action twice.
class SvgActionsMenu extends StatelessWidget {
  const SvgActionsMenu({
    super.key,
    required this.document,
    this.actions,
    this.onDeleted,
    this.onDuplicated,
  });

  final SvgDocument document;

  /// Defaults to every action. Duplicating a file on the phone copies it into
  /// the app's library and leaves the file on the phone as it is.
  final List<SvgAction>? actions;
  final VoidCallback? onDeleted;
  final ValueChanged<SvgDocument>? onDuplicated;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<SvgAction>(
      tooltip: l10n.moreActions,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) =>
          runSvgAction(context, action, document, onDeleted: onDeleted, onDuplicated: onDuplicated),
      itemBuilder: (context) => [
        for (final action in actions ?? SvgAction.values)
          PopupMenuItem(
            value: action,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (action) {
                SvgAction.rename => Icons.drive_file_rename_outline_rounded,
                SvgAction.duplicate => Icons.copy_all_rounded,
                SvgAction.share => Icons.share_rounded,
                SvgAction.delete => Icons.delete_outline_rounded,
              }),
              title: Text(switch (action) {
                SvgAction.rename => l10n.actionRename,
                SvgAction.duplicate => l10n.actionDuplicate,
                SvgAction.share => l10n.actionShare,
                SvgAction.delete => l10n.actionDelete,
              }),
            ),
          ),
      ],
    );
  }
}

/// Runs [action] on [document]; used by [SvgActionsMenu] and by buttons
/// that expose one action directly (e.g. the viewer's share icon).
Future<void> runSvgAction(
  BuildContext context,
  SvgAction action,
  SvgDocument document, {
  VoidCallback? onDeleted,
  ValueChanged<SvgDocument>? onDuplicated,
}) async {
  final services = AppScope.of(context);
  final library = services.library;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  switch (action) {
    case SvgAction.rename:
      final name = await showTextInputDialog(
        context,
        title: l10n.renameTitle,
        label: l10n.fileName,
        initial: document.name,
        confirm: l10n.actionRename,
      );
      if (name != null && name.trim().isNotEmpty) {
        final renamed = await library.rename(document, name);
        if (renamed == null) messenger.showSnackBar(SnackBar(content: Text(l10n.renameFailed)));
      }
    case SvgAction.duplicate:
      final copy = await library.duplicate(document);
      if (copy == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.duplicateFailed(document.name))));
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.duplicated(copy.name))));
      onDuplicated?.call(copy);
    case SvgAction.share:
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      try {
        await services.sharer.share(document.name, library.contentOf(document), origin: origin);
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    case SvgAction.delete:
      final onDevice = document.isOnDevice;
      final confirmed = await showConfirmDialog(
        context,
        title: onDevice ? l10n.deleteDeviceTitle : l10n.deleteTitle,
        message: onDevice
            ? l10n.deleteDeviceMessage(document.name)
            : l10n.deleteMessage(document.name),
        confirm: l10n.actionDelete,
        destructive: true,
      );
      if (confirmed) {
        final deleted = await library.delete(document);
        messenger.showSnackBar(
          SnackBar(
            content: Text(deleted ? l10n.deleted(document.name) : l10n.deleteFailed(document.name)),
          ),
        );
        if (deleted) onDeleted?.call();
      }
  }
}

/// Asks a yes/no question. Returns true when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = false,
}) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Single text field dialog. Returns null when cancelled.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
  required String confirm,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextInputDialog(title: title, label: label, initial: initial, confirm: confirm),
);

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirm,
  });

  final String title;
  final String label;
  final String initial;
  final String confirm;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(labelText: widget.label),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(widget.confirm),
      ),
    ],
  );
}
