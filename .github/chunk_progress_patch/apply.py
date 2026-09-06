from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected marker once, found {count}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))


# 1) CocoaPods: expose background_downloader's real iOS child progress/status
# through NotificationCenter without changing its download/resume/merge logic.
podfile = "ios/Podfile"
pod_text = read(podfile)
helper = r'''
def patch_background_downloader_chunk_updates
  plugin_file = File.expand_path(
    File.join(
      '.symlinks', 'plugins', 'background_downloader', 'ios',
      'background_downloader', 'Sources', 'background_downloader',
      'ParallelDownloader.swift'
    ),
    __dir__
  )
  unless File.exist?(plugin_file)
    raise "[AnimeWitcher] background_downloader ParallelDownloader.swift not found: #{plugin_file}"
  end

  source = File.read(plugin_file)
  marker = 'AnimeWitcherBackgroundDownloaderChunkUpdate'
  return if source.include?(marker)

  status_needle = "    func chunkStatusUpdate(chunkTaskId: String, status: TaskStatus, taskException: TaskException?, responseBody: String?) {\n        // Confirm chunk is part of this parent task\n        guard let chunk = chunks.first(where: { $0.task.taskId == chunkTaskId }) else { return }\n"
  status_instrumentation = <<~'SWIFT'
        NotificationCenter.default.post(
            name: Notification.Name("AnimeWitcherBackgroundDownloaderChunkUpdate"),
            object: nil,
            userInfo: [
                "parentTaskId": parentTask.taskId,
                "chunkTaskId": chunkTaskId,
                "status": status.rawValue
            ]
        )
  SWIFT
  unless source.include?(status_needle)
    raise '[AnimeWitcher] background_downloader chunkStatusUpdate marker changed; update the integration patch'
  end
  source.sub!(status_needle, status_needle + status_instrumentation)

  progress_needle = "    func chunkProgressUpdate(chunkTaskId: String, progress: Double) {\n        guard let chunk = chunks.first(where: { $0.task.taskId == chunkTaskId }) else {\n            return  // chunk is not part of this parent task\n        }\n"
  progress_instrumentation = <<~'SWIFT'
        if progress >= 0 && progress <= 1 {
            NotificationCenter.default.post(
                name: Notification.Name("AnimeWitcherBackgroundDownloaderChunkUpdate"),
                object: nil,
                userInfo: [
                    "parentTaskId": parentTask.taskId,
                    "chunkTaskId": chunkTaskId,
                    "progress": progress
                ]
            )
        }
  SWIFT
  unless source.include?(progress_needle)
    raise '[AnimeWitcher] background_downloader chunkProgressUpdate marker changed; update the integration patch'
  end
  source.sub!(progress_needle, progress_needle + progress_instrumentation)

  File.write(plugin_file, source)
  Pod::UI.puts '[AnimeWitcher] Enabled real ParallelDownloadTask child progress telemetry'
end

'''
if "def patch_background_downloader_chunk_updates" not in pod_text:
    marker = "post_install do |installer|\n"
    if marker not in pod_text:
        raise RuntimeError("ios/Podfile: post_install marker missing")
    pod_text = pod_text.replace(marker, helper + marker, 1)
    pod_text = pod_text.replace(
        marker,
        marker + "  patch_background_downloader_chunk_updates\n",
        1,
    )
    write(podfile, pod_text)


# 2) AppDelegate: mirror the plugin's NotificationCenter telemetry over the
# existing Flutter channel used by the download continued-processing bridge.
app_delegate = "ios/Runner/AppDelegate.swift"
app_text = read(app_delegate)
if "downloadChunkProgressObserver" not in app_text:
    app_text = app_text.replace(
        "  private var downloadContinuedProcessingChannel: FlutterMethodChannel?\n",
        "  private var downloadContinuedProcessingChannel: FlutterMethodChannel?\n"
        "  private var downloadChunkProgressObserver: NSObjectProtocol?\n",
        1,
    )

    observer = r'''
#if os(iOS)
    if let previous = downloadChunkProgressObserver {
      NotificationCenter.default.removeObserver(previous)
    }
    downloadChunkProgressObserver = NotificationCenter.default.addObserver(
      forName: Notification.Name("AnimeWitcherBackgroundDownloaderChunkUpdate"),
      object: nil,
      queue: .main
    ) { [weak channel] notification in
      guard let values = notification.userInfo,
            let parentTaskId = values["parentTaskId"] as? String,
            let chunkTaskId = values["chunkTaskId"] as? String,
            !parentTaskId.isEmpty,
            !chunkTaskId.isEmpty else { return }

      var arguments: [String: Any] = [
        "parentTaskId": parentTaskId,
        "chunkTaskId": chunkTaskId,
      ]
      if let progress = values["progress"] as? NSNumber {
        arguments["progress"] = progress.doubleValue
      }
      if let status = values["status"] as? NSNumber {
        arguments["status"] = status.intValue
      }
      channel?.invokeMethod("chunkUpdate", arguments: arguments)
    }
#endif

'''
    app_marker = "#if os(iOS)\n    if #available(iOS 26.0, *) {\n      DownloadContinuedProcessingManager.shared.cancellationHandler = {\n"
    if app_marker not in app_text:
        raise RuntimeError("AppDelegate.swift: continued-processing marker missing")
    app_text = app_text.replace(app_marker, observer + app_marker, 1)
    write(app_delegate, app_text)


# 3) Dart native bridge: accept real child progress/status messages.
continued = "lib/core/services/download_continued_processing_service.dart"
continued_text = read(continued)
if "SystemDownloadChunkUpdate" not in continued_text:
    continued_text = continued_text.replace(
        "typedef SystemDownloadCancellation = Future<void> Function(String taskId);\n",
        "typedef SystemDownloadCancellation = Future<void> Function(String taskId);\n"
        "typedef SystemDownloadChunkUpdate = void Function({\n"
        "  required String parentTaskId,\n"
        "  required String chunkTaskId,\n"
        "  double? progress,\n"
        "  int? statusOrdinal,\n"
        "});\n",
        1,
    )
    continued_text = continued_text.replace(
        "  final SystemDownloadCancellation onSystemCancel;\n  bool _handlerInstalled = false;\n\n"
        "  DownloadContinuedProcessingService({required this.onSystemCancel}) {\n",
        "  final SystemDownloadCancellation onSystemCancel;\n"
        "  final SystemDownloadChunkUpdate? onChunkUpdate;\n"
        "  bool _handlerInstalled = false;\n\n"
        "  DownloadContinuedProcessingService({\n"
        "    required this.onSystemCancel,\n"
        "    this.onChunkUpdate,\n"
        "  }) {\n",
        1,
    )
    old_handler = """  Future<dynamic> _handleNativeCall(MethodCall call) async {\n    if (call.method != 'cancel') return false;\n\n    final arguments = call.arguments;\n    if (arguments is! Map) return false;\n\n    final taskId = arguments['taskId'];\n    if (taskId is! String || taskId.isEmpty) return false;\n\n    await onSystemCancel(taskId);\n    return true;\n  }\n"""
    new_handler = """  Future<dynamic> _handleNativeCall(MethodCall call) async {\n    final arguments = call.arguments;\n    if (arguments is! Map) return false;\n\n    if (call.method == 'chunkUpdate') {\n      final parentTaskId = arguments['parentTaskId'];\n      final chunkTaskId = arguments['chunkTaskId'];\n      if (parentTaskId is! String ||\n          parentTaskId.isEmpty ||\n          chunkTaskId is! String ||\n          chunkTaskId.isEmpty) {\n        return false;\n      }\n      final rawProgress = arguments['progress'];\n      final rawStatus = arguments['status'];\n      onChunkUpdate?.call(\n        parentTaskId: parentTaskId,\n        chunkTaskId: chunkTaskId,\n        progress: rawProgress is num ? rawProgress.toDouble() : null,\n        statusOrdinal: rawStatus is num ? rawStatus.toInt() : null,\n      );\n      return true;\n    }\n\n    if (call.method != 'cancel') return false;\n    final taskId = arguments['taskId'];\n    if (taskId is! String || taskId.isEmpty) return false;\n\n    await onSystemCancel(taskId);\n    return true;\n  }\n"""
    if old_handler not in continued_text:
        raise RuntimeError("download_continued_processing_service.dart: handler marker missing")
    continued_text = continued_text.replace(old_handler, new_handler, 1)
    write(continued, continued_text)


# 4) Keep true child progress in Riverpod, keyed by the logical parent taskId.
service = "lib/core/services/download_service.dart"
service_text = read(service)
if "class DownloadChunkProgress extends" not in service_text:
    provider_marker = """@Riverpod(keepAlive: true)\nclass ActiveDownloadsNotifier extends _$ActiveDownloadsNotifier {\n"""
    provider_code = """@Riverpod(keepAlive: true)\nclass DownloadChunkProgress extends _$DownloadChunkProgress {\n  @override\n  Map<String, Map<String, double>> build() => {};\n\n  void update({\n    required String parentTaskId,\n    required String chunkTaskId,\n    double? progress,\n    int? statusOrdinal,\n  }) {\n    final chunks = Map<String, double>.from(\n      state[parentTaskId] ?? const <String, double>{},\n    );\n    if (progress != null && progress >= 0 && progress <= 1) {\n      chunks[chunkTaskId] = progress.clamp(0.0, 1.0).toDouble();\n    }\n    if (statusOrdinal == TaskStatus.complete.index) {\n      chunks[chunkTaskId] = 1.0;\n    }\n    state = {...state, parentTaskId: chunks};\n  }\n\n  void remove(String parentTaskId) {\n    if (!state.containsKey(parentTaskId)) return;\n    state = {...state}..remove(parentTaskId);\n  }\n}\n\n"""
    if provider_marker not in service_text:
        raise RuntimeError("download_service.dart: provider marker missing")
    service_text = service_text.replace(provider_marker, provider_code + provider_marker, 1)

    old_ctor = """    _continuedProcessing = DownloadContinuedProcessingService(\n      onSystemCancel: _cancelFromSystemUI,\n    );\n"""
    new_ctor = """    _continuedProcessing = DownloadContinuedProcessingService(\n      onSystemCancel: _cancelFromSystemUI,\n      onChunkUpdate: _handleNativeChunkUpdate,\n    );\n"""
    if old_ctor not in service_text:
        raise RuntimeError("download_service.dart: continued-processing constructor marker missing")
    service_text = service_text.replace(old_ctor, new_ctor, 1)

    stream_marker = "  Stream<TaskUpdate> get updates => _updatesController.stream;\n\n"
    chunk_handler = """  void _handleNativeChunkUpdate({\n    required String parentTaskId,\n    required String chunkTaskId,\n    double? progress,\n    int? statusOrdinal,\n  }) {\n    _ref.read(downloadChunkProgressProvider.notifier).update(\n      parentTaskId: parentTaskId,\n      chunkTaskId: chunkTaskId,\n      progress: progress,\n      statusOrdinal: statusOrdinal,\n    );\n  }\n\n"""
    if stream_marker not in service_text:
        raise RuntimeError("download_service.dart: stream getter marker missing")
    service_text = service_text.replace(stream_marker, stream_marker + chunk_handler, 1)
    write(service, service_text)


# 5) Render one real yellow progress indicator per child when telemetry is
# available. Keep the honest parent aggregate as fallback on unsupported builds.
segmented = "lib/features/library/presentation/widgets/segmented_download_progress.dart"
write(segmented, """import 'package:background_downloader/background_downloader.dart';\nimport 'package:flutter/material.dart';\n\nimport '../../../../core/services/download_parallel.dart';\n\n/// Shows independent progress for each real ParallelDownloadTask child when\n/// native chunk telemetry is available. Otherwise it falls back to the parent\n/// aggregate progress with boundaries, never inventing per-chunk percentages.\nclass SegmentedDownloadProgress extends StatelessWidget {\n  const SegmentedDownloadProgress({\n    super.key,\n    required this.task,\n    required this.value,\n    required this.backgroundColor,\n    required this.borderRadius,\n    this.chunkProgress,\n  });\n\n  final Task task;\n  final double value;\n  final Color backgroundColor;\n  final BorderRadius borderRadius;\n  final Map<String, double>? chunkProgress;\n\n  @override\n  Widget build(BuildContext context) {\n    final parts = downloadTaskPartCount(task);\n    final progress = value.clamp(0.0, 1.0).toDouble();\n    final realValues = chunkProgress?.values\n            .where((value) => value >= 0 && value <= 1)\n            .map((value) => value.clamp(0.0, 1.0).toDouble())\n            .toList(growable: false) ??\n        const <double>[];\n    final hasRealChunkProgress = parts > 1 && realValues.isNotEmpty;\n\n    return Semantics(\n      label: parts > 1\n          ? hasRealChunkProgress\n              ? 'Download progress, $parts live parallel parts'\n              : 'Download progress, $parts parallel parts'\n          : null,\n      value: '${(progress * 100).floor()}%',\n      child: ClipRRect(\n        borderRadius: borderRadius,\n        child: SizedBox(\n          height: 4,\n          child: hasRealChunkProgress\n              ? _RealChunkProgress(\n                  parts: parts,\n                  values: realValues,\n                  backgroundColor: backgroundColor,\n                )\n              : _AggregateProgress(\n                  parts: parts,\n                  progress: progress,\n                  backgroundColor: backgroundColor,\n                ),\n        ),\n      ),\n    );\n  }\n}\n\nclass _RealChunkProgress extends StatelessWidget {\n  const _RealChunkProgress({\n    required this.parts,\n    required this.values,\n    required this.backgroundColor,\n  });\n\n  final int parts;\n  final List<double> values;\n  final Color backgroundColor;\n\n  @override\n  Widget build(BuildContext context) {\n    final separator = Theme.of(\n      context,\n    ).colorScheme.surface.withValues(alpha: 0.72);\n    return Row(\n      children: List<Widget>.generate(parts * 2 - 1, (index) {\n        if (index.isOdd) {\n          return ColoredBox(color: separator, child: const SizedBox(width: 1));\n        }\n        final part = index ~/ 2;\n        return Expanded(\n          child: LinearProgressIndicator(\n            value: part < values.length ? values[part] : 0.0,\n            backgroundColor: backgroundColor,\n          ),\n        );\n      }),\n    );\n  }\n}\n\nclass _AggregateProgress extends StatelessWidget {\n  const _AggregateProgress({\n    required this.parts,\n    required this.progress,\n    required this.backgroundColor,\n  });\n\n  final int parts;\n  final double progress;\n  final Color backgroundColor;\n\n  @override\n  Widget build(BuildContext context) {\n    return Stack(\n      fit: StackFit.expand,\n      children: [\n        LinearProgressIndicator(\n          value: progress,\n          backgroundColor: backgroundColor,\n        ),\n        if (parts > 1)\n          Row(\n            children: List<Widget>.generate(parts * 2 - 1, (index) {\n              if (index.isEven) return const Expanded(child: SizedBox());\n              return Container(\n                width: 1,\n                color: Theme.of(\n                  context,\n                ).colorScheme.surface.withValues(alpha: 0.72),\n              );\n            }),\n          ),\n      ],\n    );\n  }\n}\n""")


# 6) Bind per-child state to the download tile and visibly show the configured
# parallel count (e.g. 4×) next to the percent.
downloads_tab = "lib/features/library/presentation/widgets/downloads_tab.dart"
tab_text = read(downloads_tab)
if "download_parallel.dart" not in tab_text:
    tab_text = tab_text.replace(
        "import '../../../../core/services/download_concurrency.dart';\n",
        "import '../../../../core/services/download_concurrency.dart';\n"
        "import '../../../../core/services/download_parallel.dart';\n",
        1,
    )

build_marker = """    final theme = Theme.of(context);\n    final l10n = AppLocalizations.of(context)!;\n    final isDone = status == TaskStatus.complete;\n"""
build_replacement = """    final theme = Theme.of(context);\n    final l10n = AppLocalizations.of(context)!;\n    final chunkProgress =\n        ref.watch(downloadChunkProgressProvider)[item.task.taskId];\n    final parallelParts = downloadTaskPartCount(item.task);\n    final isDone = status == TaskStatus.complete;\n"""
if build_marker not in tab_text:
    raise RuntimeError("downloads_tab.dart: tile build marker missing")
tab_text = tab_text.replace(build_marker, build_replacement, 1)

progress_call = """                SegmentedDownloadProgress(\n                  task: item.task,\n                  value: progress,\n"""
if progress_call not in tab_text:
    raise RuntimeError("downloads_tab.dart: segmented progress marker missing")
tab_text = tab_text.replace(
    progress_call,
    """                SegmentedDownloadProgress(\n                  task: item.task,\n                  value: progress,\n                  chunkProgress: chunkProgress,\n""",
    1,
)

percent_marker = """                      '${(progress.clamp(0.0, 1.0) * 100).floor()}%',\n"""
if percent_marker not in tab_text:
    raise RuntimeError("downloads_tab.dart: percent marker missing")
tab_text = tab_text.replace(
    percent_marker,
    """                      parallelParts > 1\n                          ? '$parallelParts×  ${(progress.clamp(0.0, 1.0) * 100).floor()}%'\n                          : '${(progress.clamp(0.0, 1.0) * 100).floor()}%',\n""",
    1,
)
write(downloads_tab, tab_text)


# 7) Widget regression tests: real child telemetry must render four independent
# progress indicators; aggregate fallback stays one indicator.
test_path = "test/features/library/presentation/widgets/segmented_download_progress_test.dart"
write(test_path, """import 'package:animewitcher/features/library/presentation/widgets/segmented_download_progress.dart';\nimport 'package:background_downloader/background_downloader.dart';\nimport 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  Widget host(Widget child) => MaterialApp(\n        home: Scaffold(\n          body: SizedBox(width: 400, child: child),\n        ),\n      );\n\n  testWidgets('renders one real progress bar per parallel child', (tester) async {\n    final task = ParallelDownloadTask(\n      taskId: 'episode-9',\n      url: 'https://example.com/episode.mp4',\n      chunks: 4,\n    );\n\n    await tester.pumpWidget(\n      host(\n        SegmentedDownloadProgress(\n          task: task,\n          value: 0.35,\n          chunkProgress: const {\n            'chunk-a': 0.10,\n            'chunk-b': 0.25,\n            'chunk-c': 0.50,\n            'chunk-d': 0.75,\n          },\n          backgroundColor: Colors.black12,\n          borderRadius: BorderRadius.circular(4),\n        ),\n      ),\n    );\n\n    final indicators = tester\n        .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))\n        .toList();\n    expect(indicators, hasLength(4));\n    expect(indicators.map((indicator) => indicator.value).toList(),\n        <double?>[0.10, 0.25, 0.50, 0.75]);\n  });\n\n  testWidgets('falls back to one honest aggregate bar without child telemetry',\n      (tester) async {\n    final task = ParallelDownloadTask(\n      taskId: 'episode-10',\n      url: 'https://example.com/episode.mp4',\n      chunks: 4,\n    );\n\n    await tester.pumpWidget(\n      host(\n        SegmentedDownloadProgress(\n          task: task,\n          value: 0.35,\n          backgroundColor: Colors.black12,\n          borderRadius: BorderRadius.circular(4),\n        ),\n      ),\n    );\n\n    final indicators = tester\n        .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))\n        .toList();\n    expect(indicators, hasLength(1));\n    expect(indicators.single.value, 0.35);\n  });\n}\n""")

print("Applied true per-chunk progress bridge")
