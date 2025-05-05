// webview_handlers/javascript_handler.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../session/session_storage.dart';

/// Handles JavaScript interactions with the WebView
class JSHandler {
  /// Set up JavaScript message handlers
  static void setupJavaScriptHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
        handlerName: 'appHandler',
        callback: (args) {
          try {
            if (args.isNotEmpty && args[0] is Map) {
              final message = args[0];
              if (message['type'] == 'account_switch') {
                _handleAccountSwitch();
              } else if (message['type'] == 'login_submit') {
                // Handle login credentials if needed
                final String? username = message['username'];
                final String? password = message['password'];
                if (username != null && password != null) {
                  // Save credentials if needed - don't save password to external manager
                }
              }
            }
          } catch (e) {
            debugPrint("Error handling JS message: $e");
          }
          return null;
        }
    );
  }

  /// Inject custom JavaScript into the page
  static Future<void> injectJavaScript(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: '''
      // Set up account switch detection
      window.handleAccountSwitch = function() {
        window.flutter_inappwebview.callHandler('appHandler', {type: 'account_switch'});
        console.log('account_switch');
      };
      
      // Attach listeners to account links
      document.querySelectorAll('a.account, .logout-btn, button.logout').forEach(element => {
        element.addEventListener('click', function(event) {
          handleAccountSwitch();
        });
      });
      
      // Hook form submissions on login page
      if (document.querySelector('form') && document.querySelector("input[name='username']")) {
        const loginForm = document.querySelector('form');
        
        // Add autocomplete="off" to the form and all inputs
        loginForm.setAttribute('autocomplete', 'off');
        loginForm.setAttribute('data-lpignore', 'true'); // LastPass ignore
        
        // Add attributes to disable password manager for all fields
        loginForm.querySelectorAll('input').forEach(input => {
          input.setAttribute('autocomplete', 'off');
          input.setAttribute('data-lpignore', 'true');
          input.setAttribute('data-form-type', 'other'); // Safari
          input.setAttribute('autofill', 'off'); // Chrome
        });
        
        loginForm.addEventListener('submit', function(event) {
          const username = document.querySelector("input[name='username']").value;
          const password = document.querySelector("input[name='password']").value;
          if (username && password) {
            window.flutter_inappwebview.callHandler('appHandler', {
              type: 'login_submit',
              username: username,
              password: password
            });
          }
        });
      }
      
      // Prevent Google Password Manager's autofill popup
      document.addEventListener('DOMContentLoaded', function() {
        // Prevent password saving dialog
        if (window.history && window.history.pushState) {
          // Create a "never save" form with random name for password managers to attach to
          const dummyForm = document.createElement('form');
          dummyForm.style.display = 'none';
          dummyForm.setAttribute('autocomplete', 'off');
          
          // Random unique ID to avoid detection patterns
          const randomId = 'dummy-form-' + Math.random().toString(36).substring(2, 15);
          dummyForm.id = randomId;
          
          document.body.appendChild(dummyForm);
        }
      });
    ''');
  }

  /// Check if the current page is a login page
  static Future<bool> isLoginPage(InAppWebViewController controller) async {
    final result = await controller.evaluateJavascript(source: '''
      (document.querySelector("input[name='username']") !== null && 
       document.querySelector("input[name='password']") !== null) ? true : false;
    ''');
    return result == true;
  }

  /// Handle account switching
  static Future<void> _handleAccountSwitch() async {
    await clearSession(); // Clear cookies & credentials
  }
}