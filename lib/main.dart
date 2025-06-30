// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

// Import services dan screens
import 'services/navigation_service.dart';
import 'services/notification_service.dart'; // <-- Pastikan import ini ada
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/biodata_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/events_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/news_screen.dart';
import 'screens/finance_screen.dart';

// Fungsi main yang sudah diperbaiki dan disederhanakan
void main() async {
  // 1. Memastikan semua binding widget siap sebelum menjalankan kode async.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inisialisasi lokalisasi untuk format tanggal dan waktu Bahasa Indonesia.
  await initializeDateFormatting('id_ID', null);

  // 3. Inisialisasi Firebase. Ini adalah langkah wajib.
  await Firebase.initializeApp();

  // 4. Inisialisasi semua layanan notifikasi dari satu tempat.
  // Panggilan ini akan menjalankan semua setup yang ada di NotificationService,
  // termasuk listener untuk foreground, background, dan setup channel.
  await NotificationService().initialize();

  // 5. Menjalankan aplikasi.
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
    // initState kini bersih dari logika notifikasi apa pun, karena semuanya
    // sudah ditangani secara terpusat oleh NotificationService.
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
