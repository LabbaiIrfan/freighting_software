import 'package:flutter/material.dart';

/// Customizable loading indicator that shows only a splash screen
/// and transitions directly to the webview without animations
class LoadingIndicator extends StatefulWidget {
  final double progress;
  final bool initialLoadComplete;

  const LoadingIndicator({
    Key? key,
    required this.progress,
    required this.initialLoadComplete,
  }) : super(key: key);

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> {
  // Custom loading animation colors
  final Color _primaryColor = const Color(0xFF3794C8);

  @override
  Widget build(BuildContext context) {
    // Only show splash screen until webview is fully loaded
    // Once loaded (progress == 1.0), return empty widget to show webview directly
    if (widget.progress < 1.0) {
      return _buildSplashScreen();
    }

    // Return empty widget when loaded to show the webview without animation
    return const SizedBox.shrink();
  }

  /// Splash screen for initial app load
  Widget _buildSplashScreen() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: screenHeight * 0.25),
              Image.asset(
                'assets/icon.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.local_shipping_rounded,
                    size: 80,
                    color: _primaryColor,
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Freighting App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3794C8),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 30),
              // Linear Loading Indicator
              SizedBox(
                width: screenWidth * 0.6,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: const Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              ),
              SizedBox(height: screenHeight * 0.3),
            ],
          ),
        ),
      ),
    );
  }
}