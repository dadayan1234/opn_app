// lib/services/notification_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/event_detail_screen.dart';
import '../screens/news_detail_screen.dart';
import '../services/navigation_service.dart';

// Global instance untuk background handler
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message received: ${message.data}');

  await Firebase.initializeApp();

  // Inisialisasi local notifications untuk background
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Ambil title dan body dari data payload
  final String title = message.data['title'] ?? 'Notifikasi Baru';
  final String body = message.data['body'] ?? 'Anda memiliki pesan baru.';

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'This channel is used for important notifications.',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID unik
    title,
    body,
    notificationDetails,
    payload: jsonEncode(message.data),
  );
}

Future<void> _handleMessageNavigation(Map<String, dynamic> data) async {
  print('Handling navigation with data: $data');

  final String? type = data['type'];
  final String? idString = data['id'];

  if (type == null || idString == null) {
    print('Missing type or id in notification data');
    return;
  }

  final int? id = int.tryParse(idString);
  if (id == null) {
    print('Invalid ID format: $idString');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final authToken = prefs.getString('access_token');
  if (authToken == null) {
    print('No auth token available');
    return;
  }

  final headers = {
    'accept': 'application/json',
    'Authorization': 'Bearer $authToken',
  };

  final context = NavigationService.navigatorKey.currentContext;
  if (context == null) {
    print('No navigation context available');
    return;
  }

  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (BuildContext context) =>
            const Center(child: CircularProgressIndicator()),
  );

  try {
    http.Response response;
    Widget? targetPage;

    if (type == 'event') {
      response = await http.get(
        Uri.parse('https://beopn.penaku.site/api/v1/events/$id'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        targetPage = EventDetailScreen(event: json.decode(response.body));
      }
    } else if (type == 'news') {
      response = await http.get(
        Uri.parse('https://beopn.penaku.site/api/v1/news/$id'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        targetPage = NewsDetailScreen(newsId: id);
      }
    }

    // Close loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    if (targetPage != null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => targetPage!));
    } else {
      print('Failed to create target page for type: $type, id: $id');
    }
  } catch (e) {
    // Close loading dialog on error
    Navigator.of(context, rootNavigator: true).pop();
    print("Error during navigation data fetch: $e");
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final AndroidNotificationChannel _androidChannel =
      const AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

  Future<void> initialize() async {
    print('Initializing NotificationService...');

    // Set foreground notification options
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Create notification channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Local notification tapped with payload: ${response.payload}');
        if (response.payload != null) {
          _handleMessageNavigation(jsonDecode(response.payload!));
        }
      },
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.data}');

      // Ambil title dan body dari data payload (bukan dari notification)
      final String title = message.data['title'] ?? 'Notifikasi Baru';
      final String body = message.data['body'] ?? 'Anda memiliki pesan baru.';

      // Tampilkan notifikasi lokal
      _showLocalNotification(title, body, message.data);
    });

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    print('NotificationService initialized successfully');
  }

  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          icon: '@drawable/ic_notification',
          priority: Priority.high,
          importance: Importance.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          autoCancel: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID unik
      title,
      body,
      notificationDetails,
      payload: jsonEncode(data),
    );
  }

  Future<void> setupInteractedMessage() async {
    print('Setting up message interaction handlers...');

    // Handle app launched from terminated state
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print(
        'App opened from terminated state with message: ${initialMessage.data}',
      );
      // Delay navigation untuk memastikan app sudah fully loaded
      Future.delayed(const Duration(seconds: 1), () {
        _handleMessageNavigation(initialMessage.data);
      });
    }

    // Handle app opened from background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background with message: ${message.data}');
      _handleMessageNavigation(message.data);
    });

    print('Message interaction handlers set up successfully');
  }

  Future<bool> requestPermission() async {
    print('Requesting notification permission...');

    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized;
    print('Permission status: ${settings.authorizationStatus}');

    return isAuthorized;
  }

  Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      print('FCM Token: $token');
      return token;
    } catch (e) {
      print('Error getting FCM token: $e');
      return null;
    }
  }

  Future<bool> sendTokenToServer(String token) async {
    print('Sending token to server: $token');

    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('access_token');
    if (authToken == null) {
      print('No auth token available');
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

      print('Server response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setBool('fcm_token_sent', true);
        print('FCM Token successfully sent to server.');
        return true;
      } else {
        print('Failed to send token. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error sending FCM token: $e');
      return false;
    }
  }

  Future<void> registerTokenAfterLogin() async {
    print('Registering token after login...');

    bool permissionGranted = await requestPermission();
    if (!permissionGranted) {
      print("Notification permission not granted. Token not sent.");
      return;
    }

    final String? token = await getToken();
    if (token != null) {
      await sendTokenToServer(token);

      // Set up token refresh listener
      _messaging.onTokenRefresh.listen((newToken) {
        print('Token refreshed: $newToken');
        sendTokenToServer(newToken);
      });
    } else {
      print('Failed to get FCM token');
    }
  }
}
