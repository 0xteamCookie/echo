import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Task handler run inside the Android foreground service process by
/// `flutter_foreground_task`. Its job is simply to stay alive so the OS does
/// not aggressively suspend our BLE scan/advertise/relay pipelines. The actual
/// mesh work is still driven from the main isolate callbacks in `main.dart`.
///
/// We intentionally keep this class minimal — all real logic (peripheral GATT
/// writes, relay ticks, sync) lives in the main isolate. The service just acts
/// as an execution-time anchor that Android respects for "connectedDevice" +
/// "location" foreground types.
@pragma('vm:entry-point')
void meshForegroundTaskEntrypoint() {
  FlutterForegroundTask.setTaskHandler(_MeshTaskHandler());
}

class _MeshTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[MeshFG] onStart ($starter) @ $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 15 s tick; used only as a liveness heartbeat for the notification.
    FlutterForegroundTask.updateService(
      notificationTitle: 'Beacon mesh running',
      notificationText: 'Relaying nearby messages in the background',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[MeshFG] onDestroy @ $timestamp');
  }
}

class MeshForegroundService {
  static bool _initialized = false;

  static Future<void> initAndStart() async {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'beacon_mesh_channel',
        channelName: 'Beacon mesh',
        channelDescription: 'Keeps BLE scan/advertise + relay loop running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      notificationTitle: 'Beacon mesh running',
      notificationText: 'Relaying nearby messages in the background',
      callback: meshForegroundTaskEntrypoint,
    );
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
