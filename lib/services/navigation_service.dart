// lib/services/navigation_service.dart
import 'package:flutter/material.dart';

class NavigationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<dynamic>? pushReplacementNamed(
    String routeName, {
    Object? arguments,
  }) {
    // Hapus semua route sebelumnya dan tampilkan halaman login
    return navigatorKey.currentState?.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false,
      arguments: arguments,
    );
  }
}
