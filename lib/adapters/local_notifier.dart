import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../ports/notifier.dart';

const meshNotificationChannelId = 'cmo.pinnies';

/// Thin wrapper over flutter_local_notifications — the only file that
/// imports it. Android channel + plugin init happen lazily before the first
/// [show], since the plugin must be registered with the Flutter engine
/// before platform-specific implementations can be resolved.
class LocalNotifier implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            meshNotificationChannelId,
            'Pinnies',
            description: 'Mesh transfer and relay notifications',
          ),
        );
    _initialized = true;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          meshNotificationChannelId,
          'Pinnies',
        ),
      ),
    );
  }
}
