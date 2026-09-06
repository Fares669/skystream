from pathlib import Path

path = Path('test/support/memory_storage_service.dart')
text = path.read_text(encoding='utf-8')

parallel_import = "import 'package:animewitcher/core/services/download_parallel.dart';\n"
if parallel_import not in text:
    marker = "import 'package:animewitcher/core/services/download_concurrency.dart';\n"
    if marker not in text:
        raise RuntimeError('memory storage concurrency import marker missing')
    text = text.replace(marker, marker + parallel_import, 1)

methods = '''
  @override
  Future<void> setDownloadParallelParts(int value) async {
    settings[kDownloadPartsSettingKey] = normalizeDownloadPartPreference(value);
  }

  @override
  int getDownloadParallelParts() {
    return normalizeDownloadPartPreference(settings[kDownloadPartsSettingKey]);
  }

'''
marker = '''  @override
  Future<void> setDownloadNotificationPrefs(
'''
if 'Future<void> setDownloadParallelParts(int value)' not in text:
    if marker not in text:
        raise RuntimeError('memory storage notification marker missing')
    text = text.replace(marker, methods + marker, 1)

path.write_text(text, encoding='utf-8')

# Extend the existing downloads-settings widget test so the new control is
# exercised end-to-end: Auto is visible, choosing 4 persists immediately, and
# the subtitle reflects the new value without reopening the screen.
path = Path('test/features/settings/presentation/download_concurrency_settings_test.dart')
text = path.read_text(encoding='utf-8')
if 'storage.getDownloadParallelParts(), 4' not in text:
    marker = """    expect(find.text(downloadConcurrencySubtitle(3)), findsOneWidget);
    expect(find.text(downloadConcurrencySubtitle(1)), findsNothing);
"""
    if marker not in text:
        raise RuntimeError('download settings concurrency assertion marker missing')
    addition = """

    await tester.dragUntilVisible(
      find.text(downloadPartsTitle()),
      find.byType(Scrollable).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    expect(find.text(downloadPartsTitle()), findsOneWidget);
    expect(find.text(downloadPartsSubtitle(0)), findsOneWidget);

    await tester.tap(find.text(downloadPartsTitle()));
    await tester.pumpAndSettle();
    expect(find.text('تلقائي'), findsWidgets);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();

    expect(storage.getDownloadParallelParts(), 4);
    expect(find.text(downloadPartsSubtitle(4)), findsOneWidget);
"""
    text = text.replace(marker, marker + addition, 1)
    path.write_text(text, encoding='utf-8')
