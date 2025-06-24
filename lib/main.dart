import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/biodata_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/news_screen.dart';
import 'screens/finance_screen.dart';
import 'services/navigation_service.dart';
import 'package:intl/date_symbol_data_local.dart';

// Handler untuk pesan yang diterima saat aplikasi berada di background
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message received: ${message.messageId}');
}

// Inisialisasi kanal notifikasi
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description:
      'This channel is used for important notifications.', // description
  importance: Importance.high,
);

// Inisialisasi plugin notifikasi lokal
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Memastikan widget diinisialisasi terlebih dahulu

  // 3. Muat data lokalisasi untuk Bahasa Indonesia.
  // Aplikasi akan menunggu sampai proses ini selesai sebelum lanjut.
  await initializeDateFormatting('id_ID', null);
  // Inisialisasi Firebase
  await Firebase.initializeApp();

  // Set handler untuk background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Konfigurasi plugin notifikasi lokal
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // Konfigurasi pengaturan notifikasi FCM
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Meminta izin notifikasi
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Mendapatkan token FCM (bisa disimpan ke server Anda)
  String? token = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $token');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Handler untuk pesan yang diterima saat aplikasi dalam status foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // Jika pesan memiliki notifikasi dan merupakan notifikasi Android
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: 'launch_background', // Gunakan icon dari drawable resource
            ),
          ),
        );
      }
    });

    // Handler untuk pesan yang di-klik saat aplikasi berada di background tetapi tidak dimatikan
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked: ${message.data}');
      // Di sini Anda bisa menavigasi ke halaman tertentu berdasarkan data notifikasi
      // Misalnya: Navigator.pushNamed(context, '/notifications', arguments: message.data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OPN Mobile',
      navigatorKey: NavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/biodata': (context) => const BiodataFormScreen(),
        '/dashboard': (context) {
          final fullName =
              ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return DashboardScreen(fullName: fullName);
        },
        '/events': (context) => const EventsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/news': (context) => const NewsScreen(),
        '/finance': (context) => const FinanceScreen(),
      },
    );
  }
}
