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
      // Disable password saving features by setting autocomplete to "off"
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

    // Disable password saving
    await disablePasswordSaving(controller!);
  }

  /// Disable password manager integration
  Future<void> disablePasswordSaving(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: '''
      // Disable password manager for all current and future password fields
      (function() {
        // Function to disable password saving on a field
        function disablePasswordManager(field) {
          if (field) {
            // Set attributes that discourage password saving
            field.setAttribute('autocomplete', 'off');
            field.setAttribute('autocorrect', 'off');
            field.setAttribute('autocapitalize', 'off');
            field.setAttribute('data-lpignore', 'true');  // LastPass ignore
            field.classList.add('no-password-manager');
            
            // For Chrome/Edge
            field.setAttribute('autofill', 'off');
            
            // For Safari
            field.setAttribute('data-form-type', 'other');
            
            // Some password managers look at form too
            const form = field.form;
            if (form) {
              form.setAttribute('autocomplete', 'off');
              form.setAttribute('data-lpignore', 'true');
            }
          }
        }
        
        // Apply to all current password fields
        document.querySelectorAll('input[type="password"]').forEach(disablePasswordManager);
        
        // For username fields
        document.querySelectorAll('input[name="username"], input[type="email"], input[type="text"]').forEach(field => {
          disablePasswordManager(field);
        });
        
        // Watch for dynamically added fields using MutationObserver
        const observer = new MutationObserver(mutations => {
          mutations.forEach(mutation => {
            if (mutation.addedNodes) {
              mutation.addedNodes.forEach(node => {
                // Check if the added node is or contains input fields
                if (node.nodeType === 1) { // ELEMENT_NODE
                  // If it's an input field directly
                  if (node.tagName === 'INPUT') {
                    if (node.type === 'password' || 
                        node.name === 'username' || 
                        node.type === 'email' || 
                        node.type === 'text') {
                      disablePasswordManager(node);
                    }
                  }
                  
                  // If it contains input fields
                  const passwordFields = node.querySelectorAll('input[type="password"]');
                  passwordFields.forEach(disablePasswordManager);
                  
                  const usernameFields = node.querySelectorAll('input[name="username"], input[type="email"], input[type="text"]');
                  usernameFields.forEach(disablePasswordManager);
                }
              });
            }
          });
        });
        
        // Start observing the entire document for changes
        observer.observe(document.documentElement, {
          childList: true,
          subtree: true
        });
        
        // Additional trick: override the PasswordCredential API
        if (window.PasswordCredential) {
          window.PasswordCredential = function() {
            console.log('Password credential creation blocked');
            return {};
          };
        }
        
        // For Chrome's Password Manager specifically
        if (document.createElement) {
          const originalCreateElement = document.createElement;
          document.createElement = function(tag) {
            const element = originalCreateElement.call(document, tag);
            if (tag.toLowerCase() === 'input') {
              // Add a mutation observer for when type is set to password
              const observer = new MutationObserver(mutations => {
                mutations.forEach(mutation => {
                  if (mutation.attributeName === 'type' && 
                      element.getAttribute('type') === 'password') {
                    disablePasswordManager(element);
                  }
                });
              });
              
              observer.observe(element, { attributes: true });
              
              // Override setter for type property
              const originalDescriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'type');
              if (originalDescriptor && originalDescriptor.configurable) {
                Object.defineProperty(element, 'type', {
                  set: function(value) {
                    const result = originalDescriptor.set.call(this, value);
                    if (value === 'password') {
                      disablePasswordManager(this);
                    }
                    return result;
                  },
                  get: originalDescriptor.get
                });
              }
            }
            return element;
          };
        }
      })();
    ''');

    developer.log("✅ Password manager disabled", name: "WebViewController");
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
      // Re-apply password manager prevention on each page load
      await disablePasswordSaving(controller!);

      await JSHandler.injectJavaScript(controller!);

      // Check if we're on a login page and try auto-login
      bool isLoginPage = false;
      if (url != null && url.toString().contains("login")) {
        isLoginPage = true;
      } else {
        isLoginPage = await JSHandler.isLoginPage(controller!);
      }

      if (isLoginPage && !_autofillAttempted) {
        // Set flag to prevent multiple attempts
        _autofillAttempted = true;

        // Add a delay to ensure the page is fully loaded and ready
        await Future.delayed(const Duration(milliseconds: 800));

        // First setup the prevention for input clearing
        await preventInputClearing(controller!);

        // Then attempt the autofill
        await autofillLogin(controller!);
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