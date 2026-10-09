import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'editor_controller.dart';
import 'editor_tabs.dart';

/// The line at the bottom of the editor: "valid SVG" after a save, or what is
/// wrong with the document.
class EditorStatusBar extends StatelessWidget {
  const EditorStatusBar({
    super.key,
    required this.editor,
    required this.tab,
    required this.justSaved,
  });

  final EditorController editor;
  final EditorTab tab;

  /// The "valid SVG" banner only shows after a save, until the next edit.
  final bool justSaved;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final issue = editor.validation.issue;
    final metadata = editor.metadata;
    final warning = editor.validation.warning;
    // Typed code that is waiting, or broken, makes "valid" untrue: the Code
    // tab says what is going on.
    final showValid =
        justSaved && !editor.hasUnsavedChanges && !editor.codePending && editor.codeError == null;
    if (issue == null && warning == null && !showValid) return const SizedBox.shrink();
    // The Code tab says what is wrong right under the code, with a button to
    // go there; saying it again down here would only repeat it.
    if (tab == EditorTab.code && (issue != null || warning != null)) {
      return const SizedBox.shrink();
    }
    if (issue == null && warning != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: StatusBanner(
          ok: false,
          warning: true,
          title: l10n.svgWarning,
          message: l10n.issueMessage(warning),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: StatusBanner(
        ok: issue == null,
        title: issue == null ? l10n.svgValid : l10n.svgInvalid,
        message: issue == null
            ? l10n.statusSummary(
                l10n.dimensions(metadata),
                l10n.elementCount(metadata.elementCount),
              )
            : l10n.issueMessage(issue),
      ),
    );
  }
}
