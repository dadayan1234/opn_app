import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FirebaseService {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Set up foreground notification presentation options
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotificationOnForeground(message);
    });

    // Check if we need to send token to the server
    await _checkAndSendToken();
  }

  // Request permission to receive notifications
  static Future<bool> requestPermission() async {
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // Get FCM token
  static Future<String?> getToken() async {
    return await messaging.getToken();
  }

  // Send FCM token to server
  static Future<bool> sendTokenToServer(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('access_token');

    if (authToken == null) {
      return false;
    }

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
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error sending FCM token: $e');
      return false;
    }
  }

  // Check if token needs to be sent and send if needed
  static Future<void> _checkAndSendToken() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenSent = prefs.getBool('fcm_token_sent') ?? false;

    if (!tokenSent) {
      final token = await getToken();
      if (token != null) {
        await sendTokenToServer(token);
      }
    }

    // Set up token refresh listener
    messaging.onTokenRefresh.listen((newToken) async {
      await sendTokenToServer(newToken);
    });
  }

  // Show local notification when app is in foreground
  static void _showNotificationOnForeground(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    }
  }
}

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}
