// lib/services/notification_service.dart
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// PENTING: Handler ini HARUS berada di level atas (top-level function), tidak di dalam class.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Pastikan Firebase diinisialisasi
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  // Di sini Anda bisa menambahkan logika lain jika diperlukan saat notifikasi background masuk.
  // Namun, menampilkan notifikasi di background/terminated sudah di-handle otomatis oleh FCM
  // jika payload berisi key 'notification'.
}

class NotificationService {
  // Singleton pattern untuk memastikan hanya ada satu instance dari service ini
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Channel untuk notifikasi Android
  final AndroidNotificationChannel _androidChannel =
      const AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description:
            'This channel is used for important notifications.', // description
        importance: Importance.max,
      );

  /// Inisialisasi semua layanan notifikasi. Panggil sekali di main.dart
  Future<void> initialize() async {
    // 1. Inisialisasi Firebase (jika belum)
    // Sebaiknya Firebase.initializeApp() tetap di main() untuk kejelasan.

    // 2. Pengaturan notifikasi untuk foreground di iOS & Web
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Inisialisasi Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ); // <-- PERBAIKAN IKON
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await _localNotifications.initialize(initializationSettings);

    // 4. Buat Channel Notifikasi untuk Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    // 5. Setup Handler Notifikasi
    _setupMessageHandlers();

    // 6. Cek dan kirim token FCM ke server
    _checkAndSendToken();
  }

  void _setupMessageHandlers() {
    // Handler untuk pesan saat aplikasi di FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.notification?.title}');
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // Tampilkan notifikasi lokal HANYA jika ada payload notifikasi
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannel.id,
              _androidChannel.name,
              channelDescription: _androidChannel.description,
              icon: '@mipmap/ic_launcher', // <-- PERBAIKAN IKON
              priority: Priority.high,
              importance: Importance.max,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data), // kirim data jika ada
        );
      }
    });

    // Handler untuk pesan yang diklik saat aplikasi di BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened from background: ${message.data}');
      // TODO: Navigasi ke halaman tertentu berdasarkan message.data
      // contoh: if (message.data['type'] == 'event') { ... }
    });

    // Handler untuk pesan saat aplikasi dibuka dari kondisi TERMINATED
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('Message opened from terminated: ${message.data}');
        // TODO: Navigasi ke halaman tertentu berdasarkan message.data
      }
    });

    // Handler untuk background message (ketika pesan diterima, bukan diklik)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Meminta izin notifikasi kepada pengguna
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Mendapatkan FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Mengirim token ke server Anda
  Future<bool> sendTokenToServer(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('access_token');

    if (authToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('https://beopn.penaku.site/api/v1/notifications/fcm-token'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setBool('fcm_token_sent', true);
        print('FCM Token successfully sent to server.');
        return true;
      } else {
        print('Failed to send FCM token. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error sending FCM token: $e');
      return false;
    }
  }

  /// Cek jika token sudah pernah dikirim, jika belum, kirim.
  /// Juga setup listener untuk pembaruan token.
  Future<void> _checkAndSendToken() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenSent = prefs.getBool('fcm_token_sent') ?? false;

    if (!tokenSent) {
      final token = await getToken();
      if (token != null) {
        await sendTokenToServer(token);
      }
    }

    _messaging.onTokenRefresh.listen(sendTokenToServer);
  }
}
