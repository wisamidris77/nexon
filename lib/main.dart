import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexon/screens/chat_screen.dart';
import 'package:nexon/screens/settings_screen.dart';
import 'package:nexon/screens/conversation_detail_screen.dart';
import 'package:nexon/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Initialize database here
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences for theme
  await SharedPreferences.getInstance();

  runApp(const ProviderScope(child: NexonApp()));
}

class NexonApp extends ConsumerWidget {
  const NexonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme changes
    final themeState = ref.watch(themeProvider);
    // Primary Blue Color #0388e3
    const primaryColor = Color(0xFF0388E3);
    const borderRadius = 12.0;

    return MaterialApp(
      title: 'Nexon',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          secondary: const Color(0xFF4F46E5), // Indigo for secondary actions
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withOpacity(0.05),
        ),
        cardTheme: CardTheme(
          elevation: 0.5,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius), side: BorderSide(color: Colors.grey.withOpacity(0.1))),
          shadowColor: Colors.black.withOpacity(0.05),
        ),
        drawerTheme: DrawerThemeData(
          backgroundColor: Colors.white,
          elevation: 1,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: primaryColor.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
          secondary: const Color(0xFF818CF8), // Lighter indigo for dark theme
        ),
        appBarTheme: AppBarTheme(centerTitle: false, elevation: 0, backgroundColor: const Color(0xFF1F2937), surfaceTintColor: Colors.transparent),
        scaffoldBackgroundColor: const Color(0xFF111827),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1F2937),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16))),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          color: const Color(0xFF1F2937),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius), side: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      themeMode: themeState.flutterThemeMode,
      initialRoute: '/',
      routes: {'/': (context) => const ChatScreen(), '/settings': (context) => const SettingsScreen()},
    );
  }
}
