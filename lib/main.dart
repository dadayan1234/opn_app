// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

// Import services dan screens
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/biodata_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/news_screen.dart';
import 'screens/finance_screen.dart';

void main() async {
  print('Starting app initialization...');

  // 1. Memastikan semua binding widget siap sebelum menjalankan kode async.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inisialisasi lokalisasi untuk format tanggal dan waktu Bahasa Indonesia.
  await initializeDateFormatting('id_ID', null);

  // 3. Inisialisasi Firebase. Ini adalah langkah wajib.
  await Firebase.initializeApp();
  print('Firebase initialized');

  // 4. Inisialisasi NotificationService di sini untuk memastikan
  //    background handler terdaftar sebelum app running
  final notificationService = NotificationService();
  await notificationService.initialize();
  print('Notification service initialized');

  // 5. Menjalankan aplikasi.
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Setup notification interaction setelah app siap
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService().setupInteractedMessage();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('App lifecycle state changed: $state');

    if (state == AppLifecycleState.resumed) {
      // App kembali ke foreground, setup ulang interaction handler
      NotificationService().setupInteractedMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OPN Mobile',
      navigatorKey: NavigationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        // Tambahkan konfigurasi untuk notification
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
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
