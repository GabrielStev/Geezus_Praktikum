import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys for SharedPreferences persistence
const _kHydrationEnabled = 'notif_hydration_enabled';
const _kHydrationIntervalHours = 'notif_hydration_interval_hours';
const _kRunEnabled = 'notif_run_enabled';
const _kRunHour = 'notif_run_hour';
const _kRunMinute = 'notif_run_minute';

// Stable notification IDs to prevent duplicates
const _kHydrationNotifId = 100;
const _kRunNotifId = 101;
const _kHydrationTestId = 300;
const _kRunTestId = 301;

/// Result of a permission check/request.
enum NotifPermissionStatus {
  /// Permission granted — can send notification.
  granted,

  /// Permission denied but can still ask (first-time or rationale).
  denied,

  /// Permission permanently denied — user must go to app Settings.
  permanentlyDenied,

  /// Platform not supported (web).
  unsupported,
}

/// Hasil eksekusi pengiriman notifikasi langsung (untuk tombol Tes).
class NotifSendResult {
  final bool sent;
  final NotifPermissionStatus permissionStatus;
  final String? errorMessage;

  const NotifSendResult({
    required this.sent,
    required this.permissionStatus,
    this.errorMessage,
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static Future<void>? _initFuture;

  // ---------------------------------------------------------------------------
  // Initialization (including lazy initialization)
  // ---------------------------------------------------------------------------

  static Future<void> _ensureInitialized() async {
    if (kIsWeb || _isInitialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _performInitialize();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  static Future<void> _performInitialize() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'hydration_channel',
            'Pengingat Hidrasi',
            description: 'Notifikasi jadwal minum air putih harian',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'activity_reminder_channel',
            'Pengingat Aktivitas Harian',
            description: 'Notifikasi pengingat aktivitas harian',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService _performInitialize error: $e');
    }
  }

  static Future<void> initNotification() async {
    if (kIsWeb) {
      debugPrint('NotificationService: skipped on Web platform.');
      return;
    }
    await _ensureInitialized();
    try {
      // Restore previously scheduled notifications after app restart
      await _restoreScheduledNotifications();
    } catch (e) {
      debugPrint('NotificationService restore error: $e');
    }
  }

  static void _onNotificationResponse(NotificationResponse details) {
    debugPrint('Notification tapped: ${details.payload}');
  }

  // ---------------------------------------------------------------------------
  // Permission Handling — Android plugin + permission_handler (MIUI-safe)
  // ---------------------------------------------------------------------------

  /// Cek apakah notifikasi aktif di sistem Android (termasuk MIUI & Android < 13).
  static Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    await _ensureInitialized();

    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final pluginEnabled = await androidPlugin?.areNotificationsEnabled();
      if (pluginEnabled == true) {
        return true;
      }
    } catch (e) {
      debugPrint('areNotificationsEnabled (androidPlugin) error: $e');
    }

    try {
      if (await Permission.notification.isGranted) {
        return true;
      }
    } catch (e) {
      debugPrint('areNotificationsEnabled (permission_handler) error: $e');
    }

    return false;
  }

  /// Check current notification permission status.
  static Future<NotifPermissionStatus> getPermissionStatus() async {
    if (kIsWeb) return NotifPermissionStatus.unsupported;
    try {
      if (await areNotificationsEnabled()) {
        return NotifPermissionStatus.granted;
      }
      final status = await Permission.notification.status;
      if (status.isGranted) return NotifPermissionStatus.granted;
      if (status.isPermanentlyDenied) {
        return NotifPermissionStatus.permanentlyDenied;
      }
      return NotifPermissionStatus.denied;
    } catch (e) {
      debugPrint('getPermissionStatus error: $e');
      return NotifPermissionStatus.denied;
    }
  }

  /// Request notification permission (tidak mensyaratkan exact alarm).
  static Future<NotifPermissionStatus> requestPermission() async {
    if (kIsWeb) return NotifPermissionStatus.unsupported;
    await _ensureInitialized();

    try {
      if (await areNotificationsEnabled()) {
        return NotifPermissionStatus.granted;
      }

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final pluginGranted =
          await androidPlugin?.requestNotificationsPermission();
      if (pluginGranted == true || await areNotificationsEnabled()) {
        return NotifPermissionStatus.granted;
      }

      final current = await Permission.notification.status;
      if (current.isGranted) {
        return NotifPermissionStatus.granted;
      }
      if (current.isPermanentlyDenied) {
        return NotifPermissionStatus.permanentlyDenied;
      }

      final result = await Permission.notification.request();
      debugPrint('Notification permission request result: $result');

      if (result.isGranted || await areNotificationsEnabled()) {
        return NotifPermissionStatus.granted;
      }
      if (result.isPermanentlyDenied) {
        return NotifPermissionStatus.permanentlyDenied;
      }
      return NotifPermissionStatus.denied;
    } catch (e) {
      debugPrint('requestPermission error: $e');
      if (await areNotificationsEnabled()) {
        return NotifPermissionStatus.granted;
      }
      return NotifPermissionStatus.denied;
    }
  }

  /// Open the app's notification settings page so the user can toggle it on.
  static Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Simple bool check — true if permission is currently granted.
  static Future<bool> checkPermission() async {
    if (kIsWeb) return false;
    return areNotificationsEnabled();
  }

  // ---------------------------------------------------------------------------
  // Hydration Reminder
  // ---------------------------------------------------------------------------

  /// Schedule hourly hydration reminder. Cancels any existing one first.
  static Future<void> scheduleHydrationReminder(int intervalHours) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    await cancelHydrationReminder();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHydrationEnabled, true);
      await prefs.setInt(_kHydrationIntervalHours, intervalHours);

      await _plugin.periodicallyShow(
        id: _kHydrationNotifId,
        title: '💧 Waktunya Minum Air!',
        body: 'Jaga hidrasi tubuhmu. Minum 1-2 gelas air sekarang.',
        repeatInterval: RepeatInterval.hourly,
        notificationDetails: _buildNotifDetails(
          channelId: 'hydration_channel',
          channelName: 'Pengingat Hidrasi',
          body: 'Jaga hidrasi tubuhmu. Minum 1-2 gelas air sekarang.',
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'hydration_screen',
      );
      debugPrint('Hydration reminder scheduled (${intervalHours}h interval)');
    } catch (e) {
      debugPrint('scheduleHydrationReminder error: $e');
    }
  }

  /// Cancel hydration reminder and persist OFF state.
  static Future<void> cancelHydrationReminder() async {
    if (kIsWeb) return;
    await _ensureInitialized();
    try {
      await _plugin.cancel(id: _kHydrationNotifId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHydrationEnabled, false);
    } catch (e) {
      debugPrint('cancelHydrationReminder error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Run Reminder
  // ---------------------------------------------------------------------------

  /// Schedule daily run reminder.
  static Future<void> scheduleRunReminder(int hour, int minute) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    await cancelRunReminder();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kRunEnabled, true);
      await prefs.setInt(_kRunHour, hour);
      await prefs.setInt(_kRunMinute, minute);

      await _plugin.periodicallyShow(
        id: _kRunNotifId,
        title: '🏋️ Siap Beraktivitas Hari Ini?',
        body: 'Catat latihanmu dan lanjutkan progres Boss Battle.',
        repeatInterval: RepeatInterval.daily,
        notificationDetails: _buildNotifDetails(
          channelId: 'activity_reminder_channel',
          channelName: 'Pengingat Aktivitas Harian',
          body: 'Catat latihanmu dan lanjutkan progres Boss Battle.',
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'run_screen',
      );
      debugPrint(
        'Run reminder scheduled ($hour:${minute.toString().padLeft(2, '0')})',
      );
    } catch (e) {
      debugPrint('scheduleRunReminder error: $e');
    }
  }

  /// Cancel run reminder and persist OFF state.
  static Future<void> cancelRunReminder() async {
    if (kIsWeb) return;
    await _ensureInitialized();
    try {
      await _plugin.cancel(id: _kRunNotifId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kRunEnabled, false);
    } catch (e) {
      debugPrint('cancelRunReminder error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Immediate Test Notifications
  // ---------------------------------------------------------------------------

  /// Send immediate hydration test notification.
  /// Tetap mencoba `_plugin.show()` walaupun status `requestPermission()` denied di MIUI.
  static Future<NotifSendResult> showHydrationReminder() async {
    if (kIsWeb) {
      return const NotifSendResult(
        sent: false,
        permissionStatus: NotifPermissionStatus.unsupported,
        errorMessage: 'Platform Web tidak mendukung notifikasi lokal.',
      );
    }

    await _ensureInitialized();
    final status = await requestPermission();

    try {
      await _plugin.show(
        id: _kHydrationTestId,
        title: '💧 Waktunya Minum Air!',
        body: 'Jaga hidrasi tubuhmu. Minum 1-2 gelas air sekarang.',
        notificationDetails: _buildNotifDetails(
          channelId: 'hydration_channel',
          channelName: 'Pengingat Hidrasi',
          body: 'Jaga hidrasi tubuhmu. Minum 1-2 gelas air sekarang.',
        ),
        payload: 'hydration_screen',
      );
      debugPrint('Hydration test notification sent');
      final finalStatus = await areNotificationsEnabled()
          ? NotifPermissionStatus.granted
          : status;
      return NotifSendResult(sent: true, permissionStatus: finalStatus);
    } catch (e) {
      debugPrint('showHydrationReminder error: $e');
      return NotifSendResult(
        sent: false,
        permissionStatus: status,
        errorMessage: e.toString(),
      );
    }
  }

  /// Send immediate run test notification.
  /// Tetap mencoba `_plugin.show()` walaupun status `requestPermission()` denied di MIUI.
  static Future<NotifSendResult> showRunReminder() async {
    if (kIsWeb) {
      return const NotifSendResult(
        sent: false,
        permissionStatus: NotifPermissionStatus.unsupported,
        errorMessage: 'Platform Web tidak mendukung notifikasi lokal.',
      );
    }

    await _ensureInitialized();
    final status = await requestPermission();

    try {
      await _plugin.show(
        id: _kRunTestId,
        title: '🏋️ Siap Beraktivitas Hari Ini?',
        body: 'Catat latihanmu dan lanjutkan progres Boss Battle.',
        notificationDetails: _buildNotifDetails(
          channelId: 'activity_reminder_channel',
          channelName: 'Pengingat Aktivitas Harian',
          body: 'Catat latihanmu dan lanjutkan progres Boss Battle.',
        ),
        payload: 'run_screen',
      );
      debugPrint('Run test notification sent');
      final finalStatus = await areNotificationsEnabled()
          ? NotifPermissionStatus.granted
          : status;
      return NotifSendResult(sent: true, permissionStatus: finalStatus);
    } catch (e) {
      debugPrint('showRunReminder error: $e');
      return NotifSendResult(
        sent: false,
        permissionStatus: status,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hydration_enabled': prefs.getBool(_kHydrationEnabled) ?? false,
      'hydration_interval_hours': prefs.getInt(_kHydrationIntervalHours) ?? 2,
      'run_enabled': prefs.getBool(_kRunEnabled) ?? false,
      'run_hour': prefs.getInt(_kRunHour) ?? 7,
      'run_minute': prefs.getInt(_kRunMinute) ?? 0,
    };
  }

  static Future<void> _restoreScheduledNotifications() async {
    final settings = await loadSettings();
    if (settings['hydration_enabled'] == true) {
      await scheduleHydrationReminder(
        settings['hydration_interval_hours'] as int,
      );
    }
    if (settings['run_enabled'] == true) {
      await scheduleRunReminder(
        settings['run_hour'] as int,
        settings['run_minute'] as int,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static NotificationDetails _buildNotifDetails({
    required String channelId,
    required String channelName,
    String body = '',
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: null,
          htmlFormatBigText: false,
        ),
        ticker: 'Geezus',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
