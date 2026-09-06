import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/download_parallel.dart';

/// One aggregate progress bar with visual chunk boundaries. background_downloader
/// intentionally hides per-chunk updates, so the separators represent the real
/// number of transport chunks without inventing fake per-chunk percentages.
class SegmentedDownloadProgress extends StatelessWidget {
  const SegmentedDownloadProgress({
    super.key,
    required this.task,
    required this.value,
    required this.backgroundColor,
    required this.borderRadius,
  });

  final Task task;
  final double value;
  final Color backgroundColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final parts = downloadTaskPartCount(task);
    final progress = value.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: parts > 1 ? 'Download progress, $parts parallel parts' : null,
      value: '${(progress * 100).floor()}%',
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          height: 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: backgroundColor,
              ),
              if (parts > 1)
                Row(
                  children: List<Widget>.generate(parts * 2 - 1, (index) {
                    if (index.isEven) return const Expanded(child: SizedBox());
                    return Container(
                      width: 1,
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.72),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
