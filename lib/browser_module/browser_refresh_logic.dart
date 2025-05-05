// browser_refresh_logic.dart
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Handles the pull-to-refresh functionality for the WebView
class RefreshHandler {
  /// Stops the refresh animation
  static void stopRefreshing(PullToRefreshController? refreshController) {
    try {
      if (refreshController != null) {
        refreshController.endRefreshing();
        developer.log("✅ Refresh animation stopped", name: "RefreshHandler");
      }
    } catch (e) {
      developer.log("⚠️ Error stopping refresh: $e", name: "RefreshHandler");
    }
  }

  /// Programmatically starts a refresh
  static Future<void> refreshWebView(InAppWebViewController? controller) async {
    if (controller != null) {
      try {
        developer.log("🔄 Manual refresh triggered", name: "RefreshHandler");
        await controller.reload();
      } catch (e) {
        developer.log("❌ Error during manual refresh: $e", name: "RefreshHandler");
      }
    }
  }
}