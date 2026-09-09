import 'dart:async';
import 'preload_task.dart';
import 'preload_metrics.dart';
import 'preload_request.dart';
import 'preload_scheduler.dart';
import 'package:rxdart/rxdart.dart';

/// Manages preload lifecycle.
final class PreloadManager {
  PreloadManager();

  final PreloadScheduler _scheduler = PreloadScheduler();

  final Map<String, PreloadTask> _tasks = {};

  final BehaviorSubject<PreloadMetrics> _metricsSubject = BehaviorSubject.seeded(const PreloadMetrics());

  Stream<PreloadMetrics> get metrics => _metricsSubject.stream;

  PreloadMetrics get currentMetrics => _metricsSubject.value;

  int get count => _tasks.length;

  void add(PreloadRequest request) {
    final task = PreloadTask(sourceId: request.sourceId, priority: request.priority);

    _tasks[request.sourceId.value] = task;

    _scheduler.add(task);

    _updateMetrics(total: currentMetrics.total + 1);
  }

  PreloadTask? next() {
    return _scheduler.next();
  }

  void complete(PreloadTask task) {
    task.complete();

    _updateMetrics(completed: currentMetrics.completed + 1);
  }

  void fail(PreloadTask task) {
    task.fail();

    _updateMetrics(failed: currentMetrics.failed + 1);
  }

  void cancel(PreloadTask task) {
    task.cancel();

    _updateMetrics(cancelled: currentMetrics.cancelled + 1);
  }

  void _updateMetrics({int? total, int? completed, int? failed, int? cancelled}) {
    _metricsSubject.add(
      currentMetrics.copyWith(total: total, completed: completed, failed: failed, cancelled: cancelled),
    );
  }

  Future<void> dispose() async {
    _scheduler.clear();

    _tasks.clear();

    await _metricsSubject.close();
  }
}
