// session_storage.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer' as developer;

// Keys for SharedPreferences
const String _kCookiesKey = "session_cookies";
const String _kUsernameKey = "session_username";
const String _kPasswordKey = "session_password";
const String _kSessionExpiry = "session_expiry";
const String _kLoginTimestamp = "session_login_time";
const String _kAutoSubmitKey = "session_auto_submit";
const String _baseUrl = "https://app.freighting.in";

// Global cookie manager
final CookieManager _cookieManager = CookieManager.instance();

/// Logs a message with appropriate emoji prefix
void _log(String message, {bool isError = false, bool isWarning = false}) {
  String prefix = isError ? "❌" : (isWarning ? "⚠️" : "✅");
  developer.log("$prefix $message", name: "SessionManager");
}

/// Saves all cookies from the current session
Future<bool> saveSession(InAppWebViewController controller) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cookies = await _cookieManager.getCookies(url: WebUri(_baseUrl));

    if (cookies.isEmpty) {
      _log("No cookies to save", isWarning: true);
      return false;
    }

    // Convert cookies to a JSON-serializable format
    final cookieData = cookies.map((cookie) => {
      'name': cookie.name,
      'value': cookie.value,
      'domain': cookie.domain,
      'path': cookie.path,
      'expiresDate': cookie.expiresDate,
      'isSecure': cookie.isSecure,
      'isHttpOnly': cookie.isHttpOnly,
    }).toList();

    // Store as JSON string
    await prefs.setString(_kCookiesKey, jsonEncode(cookieData));

    // Set session expiry (default 7 days)
    final now = DateTime.now();
    await prefs.setInt(_kSessionExpiry, now.add(const Duration(days: 7)).millisecondsSinceEpoch);

    _log("Session saved: ${cookies.length} cookies stored");
    return true;
  } catch (e) {
    _log("Error saving session: $e", isError: true);
    return false;
  }
}

/// Restores cookies from the saved session
Future<bool> restoreSession(InAppWebViewController controller) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    String? cookiesJson = prefs.getString(_kCookiesKey);
    int? expiryTime = prefs.getInt(_kSessionExpiry);

    // Check if session is expired
    if (expiryTime != null && DateTime.now().millisecondsSinceEpoch > expiryTime) {
      _log("Session expired, clearing cookies", isWarning: true);
      await clearSession();
      return false;
    }

    if (cookiesJson == null || cookiesJson.isEmpty) {
      _log("No saved cookies found", isWarning: true);
      return false;
    }

    try {
      final List<dynamic> cookiesList = jsonDecode(cookiesJson);
      await _cookieManager.deleteAllCookies();

      int restoredCount = 0;
      for (var cookieData in cookiesList) {
        try {
          await _cookieManager.setCookie(
            url: WebUri(_baseUrl),
            name: cookieData['name'],
            value: cookieData['value'],
            domain: cookieData['domain'],
            path: cookieData['path'] ?? "/",
            isSecure: cookieData['isSecure'] ?? true,
            isHttpOnly: cookieData['isHttpOnly'] ?? false,
          );
          restoredCount++;
        } catch (e) {
          _log("Error restoring cookie: $e", isWarning: true);
        }
      }

      _log("Session restored: $restoredCount cookies");
      return restoredCount > 0;
    } catch (e) {
      _log("Error parsing cookies: $e", isError: true);
      return false;
    }
  } catch (e) {
    _log("Error restoring session: $e", isError: true);
    return false;
  }
}

/// Saves credentials for auto-login
Future<void> saveLoginCredentials(
    BuildContext context, String username, String password, {bool promptForUpdate = true}) async {
  final prefs = await SharedPreferences.getInstance();
  String? storedUsername = prefs.getString(_kUsernameKey);

  // If we already have different credentials stored
  if (storedUsername != null && storedUsername != username && promptForUpdate) {
    bool shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Login Details"),
        content: const Text("You're logging in with different credentials. Would you like to save these new login details?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("No")),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Yes")),
        ],
      ),
    ) ?? false;

    if (!shouldUpdate) return;
  }

  // Save the credentials
  await prefs.setString(_kUsernameKey, username);
  await prefs.setString(_kPasswordKey, password);
  await prefs.setInt(_kLoginTimestamp, DateTime.now().millisecondsSinceEpoch);

  _log("Credentials saved for user: $username");
}

/// Get/Set auto-submit setting
Future<bool> isAutoSubmitEnabled() async =>
    (await SharedPreferences.getInstance()).getBool(_kAutoSubmitKey) ?? true;

Future<void> setAutoSubmitEnabled(bool enabled) async {
  await (await SharedPreferences.getInstance()).setBool(_kAutoSubmitKey, enabled);
  _log("Auto-submit ${enabled ? 'enabled' : 'disabled'}");
}

/// Attempts to autofill login fields and submit the form
Future<bool> autofillLogin(InAppWebViewController controller) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString(_kUsernameKey);
    String? password = prefs.getString(_kPasswordKey);

    if (username == null || password == null) {
      _log("No stored credentials for autofill", isWarning: true);
      return false;
    }

    bool autoSubmit = await isAutoSubmitEnabled();

    // Check if we're on a login page first
    final bool hasLoginForm = await controller.evaluateJavascript(source: '''
      (document.querySelector("input[name='username']") !== null && 
       document.querySelector("input[name='password']") !== null)
    ''') ?? false;

    if (!hasLoginForm) {
      _log("No login form detected for autofill", isWarning: true);
      return false;
    }

    // Apply the autofill script
    final result = await controller.evaluateJavascript(source: '''
      (function() {
        try {
          const usernameField = document.querySelector("input[name='username']");
          const passwordField = document.querySelector("input[name='password']");
          const loginForm = usernameField ? usernameField.closest('form') : null;
          
          if (!usernameField || !passwordField) return false;
          
          // Update the saved values
          window.savedUsername = "$username";
          window.savedPassword = "$password";
          
          // Function to fill fields and optionally submit
          const fillFields = () => {
            // Username field
            usernameField.focus();
            usernameField.value = "$username";
            usernameField.setAttribute('data-filled', 'true');
            usernameField.dispatchEvent(new Event('input', { bubbles: true }));
            usernameField.dispatchEvent(new Event('change', { bubbles: true }));
            
            // Small delay between fields
            setTimeout(() => {
              // Password field
              passwordField.focus();
              passwordField.value = "$password";
              passwordField.setAttribute('data-filled', 'true');
              passwordField.dispatchEvent(new Event('input', { bubbles: true }));
              passwordField.dispatchEvent(new Event('change', { bubbles: true }));
              
              // Option to submit the form automatically
              if (${autoSubmit.toString()} && loginForm) {
                setTimeout(() => {
                  // Find the submit button
                  const submitButton = 
                    loginForm.querySelector('button[type="submit"]') || 
                    loginForm.querySelector('input[type="submit"]') ||
                    Array.from(loginForm.querySelectorAll('button')).find(btn => 
                      btn.textContent.toLowerCase().includes('sign in') || 
                      btn.textContent.toLowerCase().includes('login') ||
                      btn.textContent.toLowerCase().includes('log in'));
                  
                  if (submitButton) {
                    submitButton.click();
                  } else if (loginForm.submit) {
                    try { loginForm.submit(); } catch(e) {}
                  }
                }, 700);
              }
            }, 200);
          };
          
          // Execute fill immediately
          fillFields();
          
          // Backup: Try again after a short delay
          setTimeout(fillFields, 500);
          
          // Create a global function that can be called later if needed
          window.reapplyAutofill = fillFields;
          
          return true;
        } catch(e) {
          console.error("Autofill error:", e);
          return false;
        }
      })();
    ''');

    if (result == true) {
      _log("Login fields autofilled successfully" + (autoSubmit ? " with auto-submit" : ""));
      return true;
    } else {
      _log("Autofill failed", isWarning: true);
      return false;
    }
  } catch (e) {
    _log("Error during autofill: $e", isError: true);
    return false;
  }
}

/// Prevent form inputs from being cleared
Future<void> preventInputClearing(InAppWebViewController controller) async {
  await controller.evaluateJavascript(source: '''
    (function() {
      // Store original values when set
      window.savedUsername = '';
      window.savedPassword = '';
      
      // Function to restore values
      window.restoreFormValues = function() {
        const usernameField = document.querySelector("input[name='username']");
        const passwordField = document.querySelector("input[name='password']");
        
        if (usernameField && window.savedUsername && usernameField.value === '') {
          usernameField.value = window.savedUsername;
          usernameField.dispatchEvent(new Event('input', { bubbles: true }));
        }
        
        if (passwordField && window.savedPassword && passwordField.value === '') {
          passwordField.value = window.savedPassword;
          passwordField.dispatchEvent(new Event('input', { bubbles: true }));
        }
      };
      
      // Save values when user types
      document.addEventListener('input', function(event) {
        if (event.target.name === 'username' && event.target.value) {
          window.savedUsername = event.target.value;
        }
        if (event.target.name === 'password' && event.target.value) {
          window.savedPassword = event.target.value;
        }
      }, true);
      
      // Setup mutation observer for form fields
      const setupProtection = function() {
        const usernameField = document.querySelector("input[name='username']");
        const passwordField = document.querySelector("input[name='password']");
        
        const inputObserver = new MutationObserver(function() {
          setTimeout(window.restoreFormValues, 50);
        });
        
        if (usernameField) {
          inputObserver.observe(usernameField, { 
            attributes: true, 
            attributeFilter: ['value'] 
          });
          
          if (usernameField.value) {
            window.savedUsername = usernameField.value;
          }
        }
        
        if (passwordField) {
          inputObserver.observe(passwordField, { 
            attributes: true, 
            attributeFilter: ['value'] 
          });
          
          if (passwordField.value) {
            window.savedPassword = passwordField.value;
          }
        }
      };
      
      // Run setup immediately and after a delay
      setupProtection();
      setTimeout(setupProtection, 500);
      
      // Periodic check as backup
      setInterval(window.restoreFormValues, 300);
    })();
  ''');
}

/// Clear all session data
Future<void> clearSession() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString(_kUsernameKey);

    await prefs.remove(_kPasswordKey);
    await prefs.remove(_kCookiesKey);
    await prefs.remove(_kSessionExpiry);
    await _cookieManager.deleteAllCookies();

    _log("Session cleared" + (username != null ? " for user: $username" : ""));
  } catch (e) {
    _log("Error clearing session: $e", isError: true);
  }
}

/// Check if the user is logged in based on stored cookies
Future<bool> isLoggedIn() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cookiesExist = prefs.containsKey(_kCookiesKey);
    final expiryTime = prefs.getInt(_kSessionExpiry);

    if (!cookiesExist || expiryTime == null) {
      return false;
    }

    return DateTime.now().millisecondsSinceEpoch < expiryTime;
  } catch (e) {
    _log("Error checking login status: $e", isWarning: true);
    return false;
  }
}

Future<bool> integrateExternalPasswordManager(InAppWebViewController controller) async {
  try {
    // This function will detect if an external password manager (like Google's) has filled the form
    // and will help with proper form submission
    final result = await controller.evaluateJavascript(source: '''
      (function() {
        try {
          const usernameField = document.querySelector("input[name='username']");
          const passwordField = document.querySelector("input[name='password']");
          const loginForm = usernameField ? usernameField.closest('form') : null;
          
          if (!usernameField || !passwordField || !loginForm) return false;
          
          // Check if fields are already filled by external password manager
          const isPreFilled = usernameField.value.length > 0 && passwordField.value.length > 0;
          
          if (isPreFilled) {
            console.log("Detected pre-filled values from password manager");
            
            // Save the values to the app's variables as well
            window.savedUsername = usernameField.value;
            window.savedPassword = passwordField.value;
            
            // Ensure input events are fired so the website recognizes the values
            usernameField.dispatchEvent(new Event('input', { bubbles: true }));
            passwordField.dispatchEvent(new Event('input', { bubbles: true }));
            
            // Find the submit button
            const submitButton = 
              loginForm.querySelector('button[type="submit"]') || 
              loginForm.querySelector('input[type="submit"]') ||
              Array.from(loginForm.querySelectorAll('button')).find(btn => 
                btn.textContent.toLowerCase().includes('sign in') || 
                btn.textContent.toLowerCase().includes('login') ||
                btn.textContent.toLowerCase().includes('log in'));
            
            // Delay and click the submit button
            setTimeout(() => {
              if (submitButton) {
                submitButton.click();
                return true;
              } else if (loginForm.submit) {
                try { 
                  loginForm.submit(); 
                  return true;
                } catch(e) {
                  console.error("Error submitting form:", e);
                }
              }
            }, 500);
          }
          
          return isPreFilled;
        } catch(e) {
          console.error("Integration error:", e);
          return false;
        }
      })();
    ''');

    return result == true;
  } catch (e) {
    print("Error during external password manager integration: $e");
    return false;
  }
}