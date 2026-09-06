import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/download_parallel.dart';

/// Shows independent progress for each real ParallelDownloadTask child when
/// native chunk telemetry is available. Otherwise it falls back to the parent
/// aggregate progress with boundaries, never inventing per-chunk percentages.
class SegmentedDownloadProgress extends StatelessWidget {
  const SegmentedDownloadProgress({
    super.key,
    required this.task,
    required this.value,
    required this.backgroundColor,
    required this.borderRadius,
    this.chunkProgress,
  });

  final Task task;
  final double value;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final Map<String, double>? chunkProgress;

  @override
  Widget build(BuildContext context) {
    final parts = downloadTaskPartCount(task);
    final progress = value.clamp(0.0, 1.0).toDouble();
    final realValues =
        chunkProgress?.values
            .where((value) => value >= 0 && value <= 1)
            .map((value) => value.clamp(0.0, 1.0).toDouble())
            .toList(growable: false) ??
        const <double>[];
    final hasRealChunkProgress = parts > 1 && realValues.isNotEmpty;

    return Semantics(
      label: parts > 1
          ? hasRealChunkProgress
                ? 'Download progress, $parts live parallel parts'
                : 'Download progress, $parts parallel parts'
          : null,
      value: '${(progress * 100).floor()}%',
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          height: 4,
          child: hasRealChunkProgress
              ? _RealChunkProgress(
                  parts: parts,
                  values: realValues,
                  backgroundColor: backgroundColor,
                )
              : _AggregateProgress(
                  parts: parts,
                  progress: progress,
                  backgroundColor: backgroundColor,
                ),
        ),
      ),
    );
  }
}

class _RealChunkProgress extends StatelessWidget {
  const _RealChunkProgress({
    required this.parts,
    required this.values,
    required this.backgroundColor,
  });

  final int parts;
  final List<double> values;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final separator = Theme.of(
      context,
    ).colorScheme.surface.withValues(alpha: 0.72);
    return Row(
      children: List<Widget>.generate(parts * 2 - 1, (index) {
        if (index.isOdd) {
          return ColoredBox(color: separator, child: const SizedBox(width: 1));
        }
        final part = index ~/ 2;
        return Expanded(
          child: LinearProgressIndicator(
            value: part < values.length ? values[part] : 0.0,
            backgroundColor: backgroundColor,
          ),
        );
      }),
    );
  }
}

class _AggregateProgress extends StatelessWidget {
  const _AggregateProgress({
    required this.parts,
    required this.progress,
    required this.backgroundColor,
  });

  final int parts;
  final double progress;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
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
    );
  }
}
