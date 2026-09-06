import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'settings_service.dart';
import 'database_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final String? payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          final File file = File(payload);
          if (await file.exists()) {
            await OpenFilex.open(payload);
          }
        }
      },
    );

    // Initialize timezones for local scheduling
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print('🔔 NotificationService: Could not initialize local timezone: $e');
    }
  }

  Future<void> showFileNotification({
    required String title,
    required String body,
    required String filePath,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
      'file_export_channel',
      'File Exports',
      channelDescription: 'Notifications for completed file exports',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: filePath,
    );
  }

  Future<void> scheduleDailyDigest() async {
    try {
      final settings = SettingsService.instance;
      await settings.init();

      if (!settings.notificationsEnabled) {
        await _notificationsPlugin.cancel(999);
        print('🔔 Notifications disabled. Cancelled daily digest.');
        return;
      }

      final db = DatabaseService();
      final tasks = await db.getAllScheduledTasks();

      final today = DateTime.now();
      final snowball = settings.snowballEffect;

      final pendingTasks = tasks.where((t) {
        final isCompleted = t['completedAt'] != null;
        if (isCompleted) return false;
        final dueDateStr = t['dueDate'];
        if (dueDateStr == null) return false;
        final dueDate = DateTime.tryParse(dueDateStr);
        if (dueDate == null) return false;

        final todayMidnight = DateTime(today.year, today.month, today.day);
        final taskDateMidnight = DateTime(dueDate.year, dueDate.month, dueDate.day);

        if (snowball) {
          return taskDateMidnight.isBefore(todayMidnight) || taskDateMidnight.isAtSameMomentAs(todayMidnight);
        } else {
          return taskDateMidnight.isAtSameMomentAs(todayMidnight);
        }
      }).toList();

      if (pendingTasks.isEmpty) {
        await _notificationsPlugin.cancel(999);
        print('🔔 No pending tasks for today. Cancelled daily digest.');
        return;
      }

      final timeStr = settings.digestTime;
      final parts = timeStr.split(':');
      final hour = int.tryParse(parts[0]) ?? 7;
      final minute = int.tryParse(parts[1]) ?? 0;

      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final taskNames = pendingTasks.map((t) => t['name'] ?? 'Task').take(3).join(', ');
      final remainingCount = pendingTasks.length > 3 ? ' and ${pendingTasks.length - 3} more' : '';
      final body = 'You have ${pendingTasks.length} pending tasks: $taskNames$remainingCount.';

      await _notificationsPlugin.zonedSchedule(
        999,
        'Daily Task Summary',
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_digest_channel',
            'Daily Digests',
            channelDescription: 'Daily reminder of your scheduled tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      print('🔔 Scheduled daily digest notification at: $scheduledDate');
    } catch (e) {
      print('🔔 Error scheduling daily digest: $e');
    }
  }
}
