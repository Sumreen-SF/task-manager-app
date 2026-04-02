import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      settings: initializationSettings,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  static String _getChannelId(String? sound) {
    if (sound == null || sound == "default") return 'task_channel_default';
    return 'task_channel_$sound';
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? sound,
  }) async {
    final channelId = _getChannelId(sound);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Tasks',
      channelDescription: 'Notifications for tasks and reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: sound != null && sound != "default"
          ? RawResourceAndroidNotificationSound(sound)
          : null,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? sound,
  }) async {
    final scheduledDate = tz.TZDateTime(
      tz.local,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
    );

    final now = tz.TZDateTime.now(tz.local);
    if (scheduledDate.isBefore(now)) {
      debugPrint("Scheduled time is in the past!");
      return;
    }

    final channelId = _getChannelId(sound);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Tasks',
      channelDescription: 'Notifications for tasks and reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: sound != null && sound != "default"
          ? RawResourceAndroidNotificationSound(sound)
          : null,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,   // This line is now correct
    );
  }
}