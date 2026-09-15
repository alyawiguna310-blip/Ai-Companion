import 'core/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

import 'core/services/notification_service.dart';
import 'features/chat/character_selection_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final permission = await Permission.notification.request();
  if (permission.isGranted) {
    if (kDebugMode) print("Notification permission granted!");
  } else {
    if (kDebugMode) print("Notification permission denied.");
  }

  await NotificationService.instance.initialize();
  await ThemeService.load();

  runApp(const AICompanionApp());
}

class AICompanionApp extends StatelessWidget {
  const AICompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'AI Companion 2.0',
          themeMode: themeMode,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: const CharacterSelectionPage(),
        );
      },
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.poppins().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B5CF6),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F5FB),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.poppins().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B5CF6),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F12),
    );
  }
}