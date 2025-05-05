import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'browser_module/browser_screen.dart';
import 'network/network_status_checker.dart';
// import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize network monitoring
  ConnectivityHandler.initializeConnectivityMonitoring();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const FreightingApp());
}

class FreightingApp extends StatelessWidget {
  const FreightingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freighting App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3794C8),
          primary: const Color(0xFF3794C8),
          secondary: const Color(0xFF00B090),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3794C8),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3794C8),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const WebViewPage(
        url: 'https://app.freighting.in/',
      ),
    );
  }
}