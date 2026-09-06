import 'package:animewitcher/core/services/download_parallel.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('adaptive parallel downloads', () {
    test('normalizes supported manual values and junk to Auto', () {
      for (final value in <int>[0, 1, 2, 4, 6, 8]) {
        expect(normalizeDownloadPartPreference(value), value);
      }
      expect(normalizeDownloadPartPreference(null), 0);
      expect(normalizeDownloadPartPreference(3), 0);
      expect(normalizeDownloadPartPreference(99), 0);
    });

    test('never splits without proven Range support and size', () {
      expect(
        selectAdaptiveDownloadParts(
          preference: 8,
          totalBytes: 900 * 1024 * 1024,
          supportsRanges: false,
        ),
        1,
      );
      expect(
        selectAdaptiveDownloadParts(
          preference: 8,
          totalBytes: -1,
          supportsRanges: true,
        ),
        1,
      );
    });

    test('Auto scales conservatively up to eight parts', () {
      const mib = 1024 * 1024;
      expect(
        selectAdaptiveDownloadParts(
          preference: 0,
          totalBytes: 40 * mib,
          supportsRanges: true,
        ),
        1,
      );
      expect(
        selectAdaptiveDownloadParts(
          preference: 0,
          totalBytes: 100 * mib,
          supportsRanges: true,
        ),
        2,
      );
      expect(
        selectAdaptiveDownloadParts(
          preference: 0,
          totalBytes: 400 * mib,
          supportsRanges: true,
        ),
        4,
      );
      expect(
        selectAdaptiveDownloadParts(
          preference: 0,
          totalBytes: 900 * mib,
          supportsRanges: true,
        ),
        6,
      );
      expect(
        selectAdaptiveDownloadParts(
          preference: 0,
          totalBytes: 2 * 1024 * mib,
          supportsRanges: true,
        ),
        8,
      );
    });

    test('builds one logical parent with the same taskId', () {
      final normal = DownloadTask(
        taskId: 'episode-12',
        url: 'https://example.com/episode.mp4',
        filename: 'episode.mp4',
        displayName: 'Episode 12',
        directory: 'downloads',
        headers: const {'Referer': 'https://example.com'},
        updates: Updates.statusAndProgress,
        allowPause: true,
        metaData: 'episode:12',
      );
      final parallel = buildAdaptiveDownloadTask(template: normal, parts: 4);
      expect(parallel, isA<ParallelDownloadTask>());
      expect(parallel.taskId, normal.taskId);
      expect(parallel.filename, normal.filename);
      expect(parallel.metaData, normal.metaData);
      expect(downloadTaskPartCount(parallel), 4);
    });

    test('internal chunks are never logical episode tasks', () {
      final child = DownloadTask(
        url: 'https://example.com/episode.mp4',
        group: FileDownloader.chunkGroup,
      );
      final parent = ParallelDownloadTask(
        url: 'https://example.com/episode.mp4',
        chunks: 4,
      );
      expect(isInternalDownloaderChunk(child), isTrue);
      expect(isLogicalEpisodeDownloadTask(child), isFalse);
      expect(isLogicalEpisodeDownloadTask(parent), isTrue);
    });
  });
}
