import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Discreet system notifications for Android/iOS while the app process is alive.
/// Copy stays neutral: never names, previews, or health details.
class PhoneAlerts {
  PhoneAlerts._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _channelId = 'wendo_updates';
  static const _channelName = 'Updates';
  static const _channelDescription = 'Neutral alerts for new activity on Wendo';

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    if (!_ready) await init();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showUpdate({required int id}) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        styleInformation: DefaultStyleInformation(true, true),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      id: id,
      title: 'Wendo',
      body: 'You have an update.',
      notificationDetails: details,
    );
  }

  static Future<void> showMessage({required String matchId}) async {
    await showUpdate(id: matchId.hashCode & 0x7fffffff);
  }

  static Future<void> showLike({required String fromUserId}) async {
    await showUpdate(id: (fromUserId.hashCode ^ 0x4c494b45) & 0x7fffffff);
  }
}
