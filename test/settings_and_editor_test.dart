import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:svg_core/svg_core.dart';
import 'package:svg_motion_gallery/src/data/app_settings.dart';
import 'package:svg_motion_gallery/src/features/editor/editor_controller.dart';
import 'package:svg_motion_gallery/src/state/settings_controller.dart';

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';

void main() {
  group('SettingsController', () {
    test('toggles theme and language and persists every change', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsController(const SettingsStore());
      await settings.load();
      expect(settings.value.darkMode, isTrue);
      expect(settings.value.language, AppLanguage.portuguese);

      settings
        ..toggleTheme()
        ..toggleLanguage()
        ..setAccent(AccentColor.orange)
        ..setSlideshowSeconds(9)
        ..setHighQualityPreviews(false);
      await pumpEventQueue();

      final reloaded = SettingsController(const SettingsStore());
      await reloaded.load();
      expect(reloaded.value.darkMode, isFalse);
      expect(reloaded.value.language, AppLanguage.english);
      expect(reloaded.value.accent, AccentColor.orange);
      expect(reloaded.value.slideshowSeconds, 9);
      expect(reloaded.value.highQualityPreviews, isFalse);
    });
  });

  group('EditorController', () {
    test('commits, undoes and redoes with the selection', () {
      final editor = EditorController(_svg);
      expect(editor.canSave, isFalse);
      final inserted = SvgInsertEdit.insert(editor.svg, SvgShapeKind.circle, color: '#FF0000');
      editor.apply(inserted);
      expect(editor.selection, inserted.selection);
      expect(editor.canSave, isTrue);
      expect(editor.layers, hasLength(2));

      editor.undo();
      expect(editor.svg, _svg);
      expect(editor.selection, isNull);
      editor.redo();
      expect(editor.selection, inserted.selection);
      expect(editor.selectedLayer?.tag, 'circle');
    });

    test('previews without touching the history', () {
      final editor = EditorController(_svg)..preview('<svg/>');
      expect(editor.displaySvg, '<svg/>');
      expect(editor.svg, _svg);
      expect(editor.canUndo, isFalse);
    });

    test('invalid code is reported but never replaces the document', () {
      final editor = EditorController(_svg)..updateCode('<svg><rect></svg>');
      expect(editor.validation.isValid, isFalse);
      expect(editor.validation.issue!.code, SvgIssueCode.malformedXml);
      expect(editor.svg, _svg);
      expect(editor.canSave, isFalse);
      expect(editor.hasUnsavedChanges, isTrue);

      const fixed = '<svg xmlns="http://www.w3.org/2000/svg"><circle r="4"/></svg>';
      editor.updateCode(fixed);
      expect(editor.validation.isValid, isTrue);
      expect(editor.svg, fixed);
      expect(editor.canUndo, isTrue);
    });

    test('formats code and tracks the saved state', () {
      final editor = EditorController(_svg)..formatCode();
      expect(editor.svg, contains('\n  <rect'));
      expect(editor.canSave, isTrue);
      editor.markSaved();
      expect(editor.canSave, isFalse);
      expect(editor.hasUnsavedChanges, isFalse);
    });
  });
}
