import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/currency_formatter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
    );

    // 🔥 Minta izin notifikasi khusus untuk Android 13+ (API 33+)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showTopupNotification({
    required double amount,
    required double balance,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'topup_channel',
      'Top Up Notifications',
      channelDescription: 'Notifications for successful top up transactions',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    final formattedAmount = CurrencyFormatter.format(amount);
    final formattedBalance = CurrencyFormatter.format(balance);

    await _notificationsPlugin.show(
      0,
      'Top Up Berhasil',
      'Transaksi Top Up sebesar $formattedAmount telah berhasil dilakukan. Saldo Anda saat ini adalah $formattedBalance.',
      platformChannelSpecifics,
    );
  }

  static Future<void> showBiometricStatusNotification(bool enabled) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'security_channel',
      'Security Notifications',
      channelDescription: 'Notifications for security setting updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    final status = enabled ? 'diaktifkan' : 'dinonaktifkan';

    await _notificationsPlugin.show(
      1,
      'Keamanan Akun',
      'Login biometrik telah $status.',
      platformChannelSpecifics,
    );
  }
}
