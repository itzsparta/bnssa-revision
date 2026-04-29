import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Initialisation complète
  static Future<void> init() async {
    // 1. Config Timezone (pour programmer à heure fixe)
    tz.initializeTimeZones();

    // 2. Config Android
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Config iOS (si besoin un jour)
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    // 4. Init Plugin
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings: initSettings);
  }

  // Demander la permission (Obligatoire pour Android 13+)
  static Future<void> requestPermissions() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Pour les notifs locales sur Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  // Programmer le rappel quotidien à 18h00
  static Future<void> scheduleDailyReminder() async {
    await _localNotifications.zonedSchedule(
      id: 0,
      title: 'Entraînement BNSSA 🏊‍♂️',
      body: 'Ne perdez pas le rythme ! 5 minutes de quiz pour réussir ?',
      scheduledDate: _nextInstanceOfTime(18, 00),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel_id',
          'Rappels Quotidiens',
          channelDescription: 'Rappel pour réviser le BNSSA',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Calcul de la prochaine heure (Demain si 18h est passé)
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // Fonction pour annuler (si l'utilisateur veut désactiver dans les réglages)
  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  static Future<void> showLocalNotification(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'trainer_channel_id',
        'Formateur',
        channelDescription: 'Notifications espace formateur',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _localNotifications.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}