// webview_handlers/error_handler.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../network/network_status_checker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Handles errors and connectivity issues
class ErrorHandler {
  /// Whether the page has encountered an error
  bool isPageError = false;

  /// Whether we're currently trying to reconnect
  bool isTryingAgain = false;

  /// Initialize connectivity monitoring
  Future<void> initConnectivity() async {
    await _checkConnectivity();
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    ConnectivityHandler.isConnected.value = result != ConnectivityResult.none;
  }

  /// Set up connectivity monitoring
  void monitorConnectivity(Function onConnectivityChanged) {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      // Update state when network changes
      ConnectivityHandler.isConnected.value = result != ConnectivityResult.none;
      onConnectivityChanged(ConnectivityHandler.isConnected.value);
    });
  }

  /// Handle try again action
  Future<void> tryAgain(InAppWebViewController? controller) async {
    isTryingAgain = true;
    isPageError = false;

    await _checkConnectivity();

    // Wait for a moment before checking again
    await Future.delayed(const Duration(seconds: 1));

    isTryingAgain = false;

    if (ConnectivityHandler.isConnected.value && controller != null) {
      controller.reload();
    }
  }

  /// Handle page load error
  void onLoadError() {
    isPageError = true;
  }

  /// Reset error state
  void resetError() {
    isPageError = false;
  }
}