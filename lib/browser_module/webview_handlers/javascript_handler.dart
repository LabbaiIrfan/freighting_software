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
      
      // Enable password managers
      loginForm.setAttribute('autocomplete', 'on');
      
      // Set correct autocomplete attributes for password managers
      loginForm.querySelectorAll('input').forEach(input => {
        if (input.getAttribute('name') === 'username') {
          input.setAttribute('autocomplete', 'username');
        } else if (input.getAttribute('name') === 'password') {
          input.setAttribute('autocomplete', 'current-password');
        }
      });
      
      // Handle form submission
      loginForm.addEventListener('submit', function(event) {
        const username = document.querySelector("input[name='username']").value;
        const password = document.querySelector("input[name='password']").value;
        if (username && password) {
          window.flutter_inappwebview.callHandler('appHandler', {
            type: 'login_submit',
            username: username,
            password: password
          });
          
          // Save credentials to the app's session management
          window.savedUsername = username;
          window.savedPassword = password;
        }
      });
    }
    
    // Create a MutationObserver to detect when Google Password Manager fills the form
    if (document.querySelector("input[name='username']") && document.querySelector("input[name='password']")) {
      const usernameField = document.querySelector("input[name='username']");
      const passwordField = document.querySelector("input[name='password']");
      
      const observer = new MutationObserver(function(mutations) {
        // Check if both fields have values (indicating password manager filled them)
        if (usernameField.value && passwordField.value) {
          console.log("Password manager detected");
          
          // Save values to the app's variables
          window.savedUsername = usernameField.value;
          window.savedPassword = passwordField.value;
        }
      });
      
      // Watch both fields for value changes
      observer.observe(usernameField, { attributes: true, attributeFilter: ['value'] });
      observer.observe(passwordField, { attributes: true, attributeFilter: ['value'] });
      
      // Also watch for direct value changes
      usernameField.addEventListener('input', function() {
        if (usernameField.value) window.savedUsername = usernameField.value;
      });
      
      passwordField.addEventListener('input', function() {
        if (passwordField.value) window.savedPassword = passwordField.value;
      });
    }
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