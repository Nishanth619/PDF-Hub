import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyNotificationId = 1001;

  // List of notification messages for variety
  final List<Map<String, String>> _notificationMessages = [
    {
      'title': 'Process Your PDFs',
      'body': 'Don\'t forget to organize, compress, or convert your PDF documents today!',
    },
    {
      'title': 'PDF Tip of the Day',
      'body': 'Did you know you can merge multiple PDFs into one? Try it today!',
    },
    {
      'title': 'Organize Your Documents',
      'body': 'Keep your PDFs organized with our powerful tools. Start processing now!',
    },
    {
      'title': 'Compress Large Files',
      'body': 'Reduce your PDF file sizes without losing quality. Perfect for sharing!',
    },
    {
      'title': 'Convert Your Documents',
      'body': 'Transform your PDFs into editable formats like Word or Excel with ease.',
    },
    {
      'title': 'Extract Text from PDFs',
      'body': 'Use OCR to extract text from scanned documents and make them searchable.',
    },
    {
      'title': 'Add Watermarks',
      'body': 'Protect your documents by adding custom watermarks with our easy tools.',
    },
    {
      'title': 'Split Large PDFs',
      'body': 'Break down large PDFs into smaller, more manageable sections.',
    },
  ];

  Future<void> init() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Linux initialization settings
    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    // Initialize settings for all platforms
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
      linux: linuxSettings,
    );

    // Initialize the plugin
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap if needed
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Request notification permissions
    await _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    // Request permissions for Android 13+
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // For iOS, we request permissions through the initialization settings
  }

  Future<void> scheduleDailyNotification({
    int hour = 9,
    int minute = 0,
  }) async {
    // Cancel any existing daily notification
    await cancelDailyNotification();

    // Get a random notification message
    final random = Random();
    final message = _notificationMessages[random.nextInt(_notificationMessages.length)];

    // Create notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminder',
      channelDescription: 'Daily reminders for PDF processing',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
      linux: linuxDetails,
    );

    // Get the next scheduled time
    final tz.TZDateTime scheduledTime = _nextInstanceOfTime(hour, minute);

    // Schedule the notification
    await _notificationsPlugin.zonedSchedule(
      _dailyNotificationId,
      message['title']!,
      message['body']!,
      scheduledTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelDailyNotification() async {
    await _notificationsPlugin.cancel(_dailyNotificationId);
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'immediate_notification_channel',
      'Immediate Notification',
      channelDescription: 'Immediate notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
    );
  }
}