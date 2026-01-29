import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import '../models/task.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    // Get device timezone
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      print('LOG: Local timezone set to $timeZoneName');
    } catch (e) {
      print('LOG: Could not set local timezone: $e');
      // Fallback: set to 'UTC' or try to proceed
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS permissions are requested later or during init depending on config
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false, 
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        print('LOG: Notification tapped: ${details.payload}');
      },
    );
    print('LOG: NotificationService initialized');
  }

  Future<void> requestPermissions() async {
    print('LOG: Requesting permissions...');
    if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
      print('LOG: Android Permissions granted: $granted');
    }
  }

  Future<void> scheduleTaskNotifications(Task task) async {
    print('LOG: Scheduling for task ${task.title} (ID: ${task.id}) Deadline: ${task.deadline}');
    if (task.deadline == null || task.done) {
      // Ensure no notifications if deadline is null or task is done
      cancelTaskNotifications(task);
      return;
    }

    // ID Logic:
    // Task ID * 10 + 0 = One day before
    // Task ID * 10 + 1 = On deadline

    final deadline = task.deadline!;
    final now = DateTime.now();

    // 1. Notification: One day before (Besok Deadline)
    // Safe ID generation: Ensure result fits in 32-bit signed int
    // Max 32-bit: 2,147,483,647.
    // task.id might be large, so we mod it.
    final safeId = task.id % 100000000; // Limit base ID to 9 digits to allow *10
    
    // 1. Notification: One day before (Besok Deadline)
    // "One day before" means 24 hours before the deadline.
    final oneDayBefore = deadline.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      print('LOG: Scheduling 1-day-before at $oneDayBefore');
      await _scheduleNotification(
        id: safeId * 10 + 0,
        title: 'Pengingat Deadline',
        body: 'Besok adalah deadline untuk task: "${task.title}" pada jam ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}',
        scheduledDate: oneDayBefore,
      );
    }

    // 2. Notification: On deadline day (Hari ini Deadline)
    // Safe ID generation: Ensure result fits in 32-bit signed int
    // final safeId = task.id % 100000000; // Already declared above


    if (deadline.isAfter(now)) {
      print('LOG: Scheduling exact deadline at $deadline');
      await _scheduleNotification(
        id: safeId * 10 + 1,
        title: 'DEADLINE SEKARANG!',
        body: 'Saatnya menyelesaikan task: "${task.title}"!',
        scheduledDate: deadline,
        isUrgent: true,
      );
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool isUrgent = false,
  }) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          isUrgent ? 'deadline_channel_urgent' : 'deadline_channel_standard',
          isUrgent ? 'Deadline (Urgent)' : 'Deadline (Standard)',
          channelDescription: isUrgent ? 'Notifikasi saat deadline tiba' : 'Notifikasi pengingat sebelum deadline',
          importance: isUrgent ? Importance.max : Importance.high,
          priority: isUrgent ? Priority.high : Priority.defaultPriority,
          color: isUrgent ? const Color(0xFFFF0000) : null, // Merah if urgent
          colorized: isUrgent,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTaskNotifications(Task task) async {
    final safeId = task.id % 100000000;
    await _flutterLocalNotificationsPlugin.cancel(safeId * 10 + 0); // H-1 restored
    await _flutterLocalNotificationsPlugin.cancel(safeId * 10 + 1);
  }

  Future<void> cancelAll() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
