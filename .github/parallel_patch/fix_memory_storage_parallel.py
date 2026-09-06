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
