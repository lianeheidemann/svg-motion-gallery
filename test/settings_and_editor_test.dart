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

  group('EditorController multi-selection', () {
    const multiSvg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<rect width="2" height="2"/>'
        '<g><circle r="1"/><rect width="3" height="3"/></g>'
        '<ellipse rx="1" ry="2"/></svg>';

    test('ticks layers from different folders and lists them in document order', () {
      final editor = EditorController(multiSvg)
        ..setMultiMode(true)
        ..select(const ElementPath([2]))
        ..select(const ElementPath([1, 0]))
        ..select(const ElementPath([0]));
      expect(editor.multiSelection, hasLength(3));
      expect(editor.targets, const [
        ElementPath([0]),
        ElementPath([1, 0]),
        ElementPath([2]),
      ]);
      expect(editor.selection, const ElementPath([0]), reason: 'the last one ticked');

      editor.select(const ElementPath([1, 0])); // ticking again unticks
      expect(editor.targets, const [
        ElementPath([0]),
        ElementPath([2]),
      ]);
      editor.select(null);
      expect(editor.targets, isEmpty);
    });

    test('turning it off keeps one layer selected; turning it on keeps the selected one', () {
      final editor = EditorController(multiSvg)..select(const ElementPath([2]));
      editor.setMultiMode(true);
      expect(editor.targets, const [
        ElementPath([2]),
      ]);
      editor
        ..select(const ElementPath([0]))
        ..setMultiMode(false);
      expect(editor.multiMode, isFalse);
      expect(editor.selection, const ElementPath([0]));
      expect(editor.multiSelection, isEmpty);
    });

    test('an edit reaches every ticked layer in one undo step', () {
      final editor = EditorController(multiSvg)
        ..setMultiMode(true)
        ..select(const ElementPath([0]))
        ..select(const ElementPath([1, 1]));
      editor.applyToTargets((svg, path) => SvgPaintEdit.setFill(svg, path, '#FF0000'));
      expect('fill="#FF0000"'.allMatches(editor.svg), hasLength(2));
      editor.undo();
      expect(editor.svg.contains('#FF0000'), isFalse, reason: 'one step undoes both');
    });

    test('deleting and duplicating work on every ticked layer', () {
      final editor = EditorController(multiSvg)
        ..setMultiMode(true)
        ..select(const ElementPath([0]))
        ..select(const ElementPath([1, 0]));
      editor.duplicateTargets();
      expect(editor.layers, hasLength(7), reason: 'two copies added to the 5 layers');
      expect(editor.multiSelection, isEmpty);

      final again = EditorController(multiSvg)
        ..setMultiMode(true)
        ..select(const ElementPath([0]))
        ..select(const ElementPath([1, 0]));
      again.removeTargets();
      expect(again.layers.map((l) => l.tag), ['g', 'rect', 'ellipse']);
    });

    const nestedSvg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
        '<g><g><circle r="1"/><rect width="1" height="1"/></g><path d="M0 0L1 1"/></g>'
        '<ellipse rx="1" ry="2"/></svg>';

    test('ticking a folder ticks everything in it, and the folder takes the edits', () {
      final editor = EditorController(nestedSvg)
        ..setMultiMode(true)
        ..select(const ElementPath([0]));
      expect(editor.multiSelection.toSet(), {
        const ElementPath([0]),
        const ElementPath([0, 0]),
        const ElementPath([0, 0, 0]),
        const ElementPath([0, 0, 1]),
        const ElementPath([0, 1]),
      });
      expect(editor.targets, const [
        ElementPath([0]),
      ], reason: 'what is inside is covered');
      expect(editor.selection, const ElementPath([0]));
    });

    test('unticking a layer inside unticks the folders around it, not the rest', () {
      final editor = EditorController(nestedSvg)
        ..setMultiMode(true)
        ..select(const ElementPath([0]))
        ..select(const ElementPath([0, 0, 0]));
      expect(editor.multiSelection.toSet(), {
        const ElementPath([0, 0, 1]),
        const ElementPath([0, 1]),
      });
      expect(editor.targets, const [
        ElementPath([0, 0, 1]),
        ElementPath([0, 1]),
      ]);
    });

    test('ticking every layer of a folder ticks the folder, up the tree', () {
      final editor = EditorController(nestedSvg)
        ..setMultiMode(true)
        ..select(const ElementPath([0, 0, 0]))
        ..select(const ElementPath([0, 0, 1]));
      expect(editor.multiSelection, contains(const ElementPath([0, 0])));
      expect(editor.targets, const [
        ElementPath([0, 0]),
      ]);
      editor.select(const ElementPath([0, 1]));
      expect(editor.multiSelection, contains(const ElementPath([0])));
      expect(editor.targets, const [
        ElementPath([0]),
      ]);
      expect(editor.selection, const ElementPath([0]));
    });

    test('a ticked folder gets an edit once, not again for what is inside it', () {
      final editor = EditorController(multiSvg)
        ..setMultiMode(true)
        ..select(const ElementPath([1]));
      editor.duplicateTargets();
      expect(editor.layers, hasLength(8), reason: 'one copy of the folder and its 2 layers');
    });

    test('turning it on with a folder selected ticks what is in it', () {
      final editor = EditorController(multiSvg)..select(const ElementPath([1]));
      editor.setMultiMode(true);
      expect(editor.multiSelection, hasLength(3));
      expect(editor.targets, const [
        ElementPath([1]),
      ]);
    });

    test('select all ticks the folders too, and edits go to the top of the tree', () {
      final editor = EditorController(multiSvg)..selectAllLayers();
      expect(editor.multiSelection, hasLength(5));
      expect(editor.targets, const [
        ElementPath([0]),
        ElementPath([1]),
        ElementPath([2]),
      ]);
    });

    test('an editor wrapper is ticked with its layer, which keeps the edits', () {
      const wrapped =
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
          '<g data-sm-edit="element"><rect width="1" height="1"/></g><circle r="1"/></svg>';
      final editor = EditorController(wrapped)
        ..setMultiMode(true)
        ..select(const ElementPath([0, 0]));
      expect(editor.multiSelection, contains(const ElementPath([0])));
      expect(editor.targets, const [
        ElementPath([0, 0]),
      ]);
      expect(editor.selection, const ElementPath([0, 0]));
      editor
        ..select(null)
        ..select(const ElementPath([0]));
      expect(editor.targets, const [
        ElementPath([0, 0]),
      ], reason: 'ticking the wrapper row too');
    });

    test('redo brings the ticked layers back', () {
      final editor = EditorController(multiSvg)
        ..setMultiMode(true)
        ..select(const ElementPath([0]))
        ..select(const ElementPath([2]));
      editor.applyToTargets(SvgLayers.toggleVisibility);
      expect(editor.multiSelection, hasLength(2));
      editor
        ..select(null)
        ..undo()
        ..redo();
      expect(editor.multiSelection, hasLength(2));
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
