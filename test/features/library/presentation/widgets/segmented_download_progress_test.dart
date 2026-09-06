import 'package:animewitcher/features/library/presentation/widgets/segmented_download_progress.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 400, child: child)),
  );

  testWidgets('renders one real progress bar per parallel child', (
    tester,
  ) async {
    final task = ParallelDownloadTask(
      taskId: 'episode-9',
      url: 'https://example.com/episode.mp4',
      chunks: 4,
    );

    await tester.pumpWidget(
      host(
        SegmentedDownloadProgress(
          task: task,
          value: 0.35,
          chunkProgress: const {
            'chunk-a': 0.10,
            'chunk-b': 0.25,
            'chunk-c': 0.50,
            'chunk-d': 0.75,
          },
          backgroundColor: Colors.black12,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );

    final indicators = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .toList();
    expect(indicators, hasLength(4));
    expect(indicators.map((indicator) => indicator.value).toList(), <double?>[
      0.10,
      0.25,
      0.50,
      0.75,
    ]);
  });

  testWidgets(
    'falls back to one honest aggregate bar without child telemetry',
    (tester) async {
      final task = ParallelDownloadTask(
        taskId: 'episode-10',
        url: 'https://example.com/episode.mp4',
        chunks: 4,
      );

      await tester.pumpWidget(
        host(
          SegmentedDownloadProgress(
            task: task,
            value: 0.35,
            backgroundColor: Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );

      final indicators = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(indicators, hasLength(1));
      expect(indicators.single.value, 0.35);
    },
  );

  testWidgets('supports the thicker progress bar used by the download dialog', (
    tester,
  ) async {
    final task = ParallelDownloadTask(
      taskId: 'episode-dialog',
      url: 'https://example.com/episode.mp4',
      chunks: 6,
    );

    await tester.pumpWidget(
      host(
        SegmentedDownloadProgress(
          task: task,
          value: 0.31,
          backgroundColor: Colors.black12,
          borderRadius: BorderRadius.circular(4),
          height: 8,
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(SegmentedDownloadProgress)).height,
      8,
    );
  });
}
