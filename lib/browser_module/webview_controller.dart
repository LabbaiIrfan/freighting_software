// webview_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../session/session_storage.dart';
import 'browser_refresh_logic.dart';
import 'webview_handlers/javascript_handler.dart';
import 'dart:developer' as developer;

/// Handles the creation and configuration of the WebView controller
class WebViewController {
  /// The actual InAppWebViewController
  InAppWebViewController? controller;

  /// Pull-to-refresh controller
  PullToRefreshController? pullToRefreshController;

  /// Track autofill attempts to prevent multiple attempts
  bool _autofillAttempted = false;

  WebViewController() {
    // Initialize the pull-to-refresh controller early
    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: const Color(0xFF3794C8),
        backgroundColor: Colors.white,
        distanceToTriggerSync: 80,
      ),
      onRefresh: _handleRefresh,
    );
  }

  void _handleRefresh() async {
    if (controller != null) {
      try {
        developer.log("🔄 Pull-to-refresh triggered", name: "WebViewController");
        await controller!.reload();
        // Note: Don't call endRefreshing here - it will be called in onLoadStop
      } catch (e) {
        developer.log("❌ Error during refresh: $e", name: "WebViewController");
        if (pullToRefreshController != null) {
          pullToRefreshController!.endRefreshing();
        }
      }
    } else {
      developer.log("⚠️ Cannot refresh: controller is null", name: "WebViewController");
      if (pullToRefreshController != null) {
        pullToRefreshController!.endRefreshing();
      }
    }
  }

  /// Create WebView settings
  InAppWebViewSettings getWebViewSettings() {
    return InAppWebViewSettings(
      useHybridComposition: true,
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: false,
      javaScriptEnabled: true,
      cacheEnabled: true,
      transparentBackground: true,
      useShouldInterceptAjaxRequest: true,
      useShouldInterceptFetchRequest: true,
      javaScriptCanOpenWindowsAutomatically: true, // Allow JS popups
      supportZoom: false,  // Disable pinch zoom for better UX
      // Allow browser/password manager autocomplete
      userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1', // Use mobile user agent
    );
  }

  /// Set up the controller when the WebView is created
  Future<void> onWebViewCreated(InAppWebViewController newController) async {
    controller = newController;
    _autofillAttempted = false;

    // Set up JavaScript handler
    JSHandler.setupJavaScriptHandlers(controller!);

    // Restore session if available
    await restoreSession(controller!);

    // We no longer call disablePasswordSaving here
  }

  /// Handle page load start
  void onLoadStart(WebUri? url) {
    // Reset autofill flag on new page load
    _autofillAttempted = false;

    // This is intentionally left empty for other actions
  }

  /// Handle page load completion
  Future<void> onLoadStop(WebUri? url) async {
    developer.log("📄 Page load complete: ${url?.toString()}", name: "WebViewController");

    // Stop the refresh animation
    if (pullToRefreshController != null) {
      pullToRefreshController!.endRefreshing();
    }

    // If we have a controller, inject JavaScript
    if (controller != null) {
      await JSHandler.injectJavaScript(controller!);

      // Check if we're on a login page
      bool isLoginPage = false;
      if (url != null && url.toString().contains("login")) {
        isLoginPage = true;
      } else {
        isLoginPage = await JSHandler.isLoginPage(controller!);
      }

      if (isLoginPage) {
        // Add a delay to ensure the page is fully loaded and ready
        await Future.delayed(const Duration(milliseconds: 800));

        // First try to detect if external password manager has already filled fields
        bool externalManagerDetected = await integrateExternalPasswordManager(controller!);

        // If no external manager detected, use our internal autofill
        if (!externalManagerDetected && !_autofillAttempted) {
          _autofillAttempted = true;

          // Setup the prevention for input clearing
          await preventInputClearing(controller!);

          // Attempt the autofill
          await autofillLogin(controller!);
        }
      }
    }
  }

  /// Handle permission requests
  Future<PermissionResponse> onPermissionRequest(PermissionRequest request) async {
    return PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.GRANT,
    );
  }

  /// Handle SSL certificate errors
  Future<ServerTrustAuthResponse> onReceivedServerTrustAuthRequest() async {
    return ServerTrustAuthResponse(
      action: ServerTrustAuthResponseAction.PROCEED,
    );
  }

  /// Go back in navigation history if possible
  Future<bool> canGoBack() async {
    return await controller?.canGoBack() ?? false;
  }

  /// Navigate back
  Future<void> goBack() async {
    if (await canGoBack()) {
      await controller?.goBack();
    }
  }

  /// Reload the current page
  Future<void> reload() async {
    developer.log("🔄 Manual reload triggered", name: "WebViewController");
    _autofillAttempted = false; // Reset autofill flag on manual reload
    await controller?.reload();
  }

  /// Manually trigger autofill (can be called from UI)
  Future<bool> triggerAutofill() async {
    if (controller != null) {
      await preventInputClearing(controller!);
      _autofillAttempted = true;
      return await autofillLogin(controller!);
    }
    return false;
  }

  /// Dispose resources
  void dispose() {
    if (controller != null) {
      saveSession(controller!);
    }
    controller = null;
    pullToRefreshController = null;
  }
}