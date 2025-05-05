// webview_handlers/navigation_handler.dart
import 'package:flutter/material.dart';
import 'dart:io' show Platform, exit;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../file_manager/file_handlers.dart';
import 'youtube_embed_controller.dart';
import 'javascript_handler.dart'; // Import JavaScript handler for login page check

/// Handles navigation-related actions in the WebView
class NavigationHandler {
  /// Handle the back button press
  static Future<bool> handleBackNavigation(
      InAppWebViewController? controller,
      BuildContext context,
      bool isNavigationPage) async {

    // If we can go back, just go back
    if (await controller?.canGoBack() ?? false) {
      await controller?.goBack();
      return false;
    }

    // If it's a navigation page, pop the navigation
    if (isNavigationPage) {
      Navigator.of(context).pop();
      return false;
    }

    // Only show exit dialog if we're on the login page or similar root page
    bool isOnLoginPage = await _isOnLoginOrRootPage(controller);
    if (isOnLoginPage) {
      return await _showExitConfirmationDialog(context);
    } else {
      // If not on login page, just pop the current view
      Navigator.of(context).pop();
      return false;
    }
  }

  /// Check if we're on the login page or a root page
  static Future<bool> _isOnLoginOrRootPage(InAppWebViewController? controller) async {
    if (controller == null) return false;

    // Check if it's a login page using JSHandler
    bool isLoginPage = await JSHandler.isLoginPage(controller);
    if (isLoginPage) return true;

    // You can add additional checks here for other "root" pages
    // For example, check URL patterns or page elements

    // Example: Check if URL is the main domain without additional paths
    final currentUrl = await controller.getUrl();
    if (currentUrl != null) {
      final uri = Uri.parse(currentUrl.toString());
      // If URL path is "/" or empty, consider it a root page
      if (uri.path == "/" || uri.path.isEmpty || uri.path == "/index.html") {
        return true;
      }
    }

    return false;
  }

  /// Handle URL overrides for special cases (PDFs, external apps)
  static Future<NavigationActionPolicy> handleUrlOverride(
      InAppWebViewController controller,
      NavigationAction navigationAction,
      BuildContext context) async {

    Uri? uri = navigationAction.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;

    // Handle PDF files
    if (uri.path.endsWith(".pdf")) {
      FileOpenHandler.openFileOrDownload(context, uri.toString());
      return NavigationActionPolicy.CANCEL;
    }

    // Handle external URLs (YouTube, etc.)
    return await handleExternalNavigation(controller, navigationAction);
  }

  /// Show exit confirmation dialog
  static Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit App'),
          content: const Text('Do you want to exit the app?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // User doesn't want to exit
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // User wants to exit
                _exitApp(); // Force exit
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );

    return shouldExit ?? false;
  }

  /// Force exit the application
  static void _exitApp() {
    if (Platform.isAndroid) {
      SystemNavigator.pop(); // For Android
    } else if (Platform.isIOS) {
      exit(0); // For iOS
    }
  }
}