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

// Base URL for the app
const String _baseUrl = "https://app.freighting.in";

/// Global cookie manager
final CookieManager _cookieManager = CookieManager.instance();

/// Saves all cookies from the current session
Future<bool> saveSession(InAppWebViewController controller) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cookies = await _cookieManager.getCookies(url: WebUri(_baseUrl));

    if (cookies.isNotEmpty) {
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

      developer.log("✅ Session saved: ${cookies.length} cookies stored", name: "SessionManager");
      return true;
    } else {
      developer.log("⚠️ No cookies to save", name: "SessionManager");
      return false;
    }
  } catch (e) {
    developer.log("❌ Error saving session: $e", name: "SessionManager");
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
    if (expiryTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > expiryTime) {
        developer.log("⚠️ Session expired, clearing cookies", name: "SessionManager");
        await clearSession();
        return false;
      }
    }

    if (cookiesJson != null && cookiesJson.isNotEmpty) {
      try {
        final List<dynamic> cookiesList = jsonDecode(cookiesJson);

        // Clear existing cookies first
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
            developer.log("⚠️ Error restoring cookie: $e", name: "SessionManager");
          }
        }

        developer.log("✅ Session restored: $restoredCount cookies", name: "SessionManager");
        return restoredCount > 0;
      } catch (e) {
        developer.log("❌ Error parsing cookies: $e", name: "SessionManager");
        return false;
      }
    } else {
      developer.log("⚠️ No saved cookies found", name: "SessionManager");
      return false;
    }
  } catch (e) {
    developer.log("❌ Error restoring session: $e", name: "SessionManager");
    return false;
  }
}

/// Saves credentials for auto-login if cookies don't work
Future<void> saveLoginCredentials(
    BuildContext context,
    String username,
    String password,
    {bool promptForUpdate = true}) async {

  final prefs = await SharedPreferences.getInstance();
  String? storedUsername = prefs.getString(_kUsernameKey);

  // If we already have different credentials stored
  if (storedUsername != null && storedUsername != username && promptForUpdate) {
    bool shouldUpdate = await _showUpdateCredentialsDialog(context);
    if (!shouldUpdate) return;
  }

  // Save the credentials
  await prefs.setString(_kUsernameKey, username);
  await prefs.setString(_kPasswordKey, password);

  // Record login timestamp
  await prefs.setInt(_kLoginTimestamp, DateTime.now().millisecondsSinceEpoch);

  developer.log("✅ Credentials saved for user: $username", name: "SessionManager");
}

/// Shows a dialog asking if the user wants to update stored credentials
Future<bool> _showUpdateCredentialsDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Update Login Details"),
        content: const Text(
            "You're logging in with different credentials. Would you like to save these new login details?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      );
    },
  ) ?? false;
}

/// Get auto-submit setting
Future<bool> isAutoSubmitEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kAutoSubmitKey) ?? true; // Default to true
}

/// Set auto-submit setting
Future<void> setAutoSubmitEnabled(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kAutoSubmitKey, enabled);
  developer.log("✅ Auto-submit ${enabled ? 'enabled' : 'disabled'}", name: "SessionManager");
}

/// Attempts to autofill login fields and submit the form
Future<bool> autofillLogin(InAppWebViewController controller) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString(_kUsernameKey);
    String? password = prefs.getString(_kPasswordKey);
    bool autoSubmit = await isAutoSubmitEnabled();

    if (username == null || password == null) {
      developer.log("⚠️ No stored credentials for autofill", name: "SessionManager");
      return false;
    }

    // Check if we're on a login page first
    final hasLoginForm = await controller.evaluateJavascript(source: '''
      (document.querySelector("input[name='username']") !== null && 
       document.querySelector("input[name='password']") !== null)
    ''');

    if (hasLoginForm != true) {
      developer.log("⚠️ No login form detected for autofill", name: "SessionManager");
      return false;
    }

    // Apply the improved filling approach
    final result = await controller.evaluateJavascript(source: '''
      (function() {
        try {
          // Get the form elements
          const usernameField = document.querySelector("input[name='username']");
          const passwordField = document.querySelector("input[name='password']");
          const loginForm = usernameField ? usernameField.closest('form') : null;
          
          if (!usernameField || !passwordField) {
            console.log("Login fields not found");
            return false;
          }
          
          console.log("Starting autofill process");
          
          // Update the saved values used by our protection mechanism
          window.savedUsername = "$username";
          window.savedPassword = "$password";
          
          // Apply values carefully
          const fillFields = () => {
            // Force focus on username field first
            usernameField.focus();
            
            // Username field - directly set value and trigger events
            usernameField.value = "$username";
            usernameField.setAttribute('data-filled', 'true');
            usernameField.dispatchEvent(new Event('input', { bubbles: true }));
            usernameField.dispatchEvent(new Event('change', { bubbles: true }));
            usernameField.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
            
            // Small delay between fields
            setTimeout(() => {
              // Password field
              passwordField.focus();
              passwordField.value = "$password";
              passwordField.setAttribute('data-filled', 'true');
              passwordField.dispatchEvent(new Event('input', { bubbles: true }));
              passwordField.dispatchEvent(new Event('change', { bubbles: true }));
              passwordField.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
              
              // Option to submit the form automatically
              const shouldSubmit = ${autoSubmit.toString()};
              
              if (shouldSubmit && loginForm) {
                // Allow time for form validation
                setTimeout(() => {
                  console.log("Attempting to submit login form");
                  
                  // Find the submit button with various detection methods
                  const submitButton = 
                    loginForm.querySelector('button[type="submit"]') || 
                    loginForm.querySelector('input[type="submit"]') ||
                    Array.from(loginForm.querySelectorAll('button')).find(btn => 
                      btn.textContent.toLowerCase().includes('sign in') || 
                      btn.textContent.toLowerCase().includes('login') ||
                      btn.textContent.toLowerCase().includes('log in'));
                  
                  if (submitButton) {
                    console.log("Found submit button, clicking");
                    submitButton.click();
                  } else {
                    console.log("No submit button found, trying form.submit()");
                    try {
                      loginForm.submit();
                    } catch(e) {
                      console.error("Form submission error:", e);
                    }
                  }
                }, 700);
              }
            }, 200);
          };
          
          // Execute fill immediately
          fillFields();
          
          // Backup: Try again after a short delay in case of any timing issues
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
      developer.log("✅ Login fields autofilled successfully" +
          (autoSubmit ? " with auto-submit" : ""), name: "SessionManager");
      return true;
    } else {
      developer.log("⚠️ Autofill failed", name: "SessionManager");
      return false;
    }
  } catch (e) {
    developer.log("❌ Error during autofill: $e", name: "SessionManager");
    return false;
  }
}

/// Prevent form inputs from being cleared
/// Prevent form inputs from being cleared with enhanced protection
Future<void> preventInputClearing(InAppWebViewController controller) async {
  await controller.evaluateJavascript(source: '''
    (function() {
      // Store original values when set
      let savedUsername = '';
      let savedPassword = '';
      
      // Function to restore values (will be called from various observers)
      window.restoreFormValues = function() {
        const usernameField = document.querySelector("input[name='username']");
        const passwordField = document.querySelector("input[name='password']");
        
        if (usernameField && savedUsername && usernameField.value === '') {
          console.log('Restoring username field from saved value');
          usernameField.value = savedUsername;
          usernameField.dispatchEvent(new Event('input', { bubbles: true }));
        }
        
        if (passwordField && savedPassword && passwordField.value === '') {
          console.log('Restoring password field from saved value');
          passwordField.value = savedPassword;
          passwordField.dispatchEvent(new Event('input', { bubbles: true }));
        }
      };
      
      // 1. SAVE VALUES WHEN USER TYPES
      document.addEventListener('input', function(event) {
        if (event.target.name === 'username' && event.target.value) {
          savedUsername = event.target.value;
          console.log('Saved username value:', savedUsername);
        }
        if (event.target.name === 'password' && event.target.value) {
          savedPassword = event.target.value;
          console.log('Saved password value:', savedPassword);
        }
      }, true);
      
      // 2. MUTATION OBSERVER FOR DOM CHANGES
      const inputObserver = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          // Check for attribute changes to value
          if (mutation.type === 'attributes' && 
              mutation.attributeName === 'value') {
              
            const target = mutation.target;
            
            if (target.name === 'username' && target.value === '' && savedUsername) {
              console.log('Username value was cleared by attribute change');
              setTimeout(() => restoreFormValues(), 50);
            }
            
            if (target.name === 'password' && target.value === '' && savedPassword) {
              console.log('Password value was cleared by attribute change');
              setTimeout(() => restoreFormValues(), 50);
            }
          }
        });
      });
      
      // 3. PROTECT AGAINST VALUE PROPERTY CHANGES
      function protectInputField(inputField, savedValueName) {
        if (!inputField) return;
        
        // Use Object.defineProperty to intercept value property changes
        const originalDescriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
        if (originalDescriptor && originalDescriptor.configurable) {
          Object.defineProperty(inputField, 'value', {
            set: function(val) {
              const currentValue = this.value;
              // Call the original setter
              originalDescriptor.set.call(this, val);
              
              // If the value was cleared and we have a saved value
              if (val === '' && currentValue && currentValue === window[savedValueName]) {
                console.log('Value setter intercepted attempt to clear', savedValueName);
                setTimeout(() => {
                  if (this.value === '') {
                    console.log('Restoring value from setter protection');
                    originalDescriptor.set.call(this, window[savedValueName]);
                    this.dispatchEvent(new Event('input', { bubbles: true }));
                  }
                }, 50);
              }
            },
            get: originalDescriptor.get
          });
        }
      }
      
      // 4. SET UP ALL PROTECTION MECHANISMS
      const setupProtection = function() {
        const usernameField = document.querySelector("input[name='username']");
        const passwordField = document.querySelector("input[name='password']");
        
        if (usernameField) {
          console.log("Setting up protection for username field");
          // Make the saved value available to our protection function
          window.savedUsername = savedUsername;
          
          // Add mutation observer
          inputObserver.observe(usernameField, { 
            attributes: true, 
            attributeFilter: ['value'] 
          });
          
          // Add property descriptor protection
          protectInputField(usernameField, 'savedUsername');
          
          // Save initial value if present
          if (usernameField.value) {
            savedUsername = usernameField.value;
            window.savedUsername = savedUsername;
          }
        }
        
        if (passwordField) {
          console.log("Setting up protection for password field");
          // Make the saved value available to our protection function
          window.savedPassword = savedPassword;
          
          // Add mutation observer  
          inputObserver.observe(passwordField, { 
            attributes: true, 
            attributeFilter: ['value'] 
          });
          
          // Add property descriptor protection
          protectInputField(passwordField, 'savedPassword');
          
          // Save initial value if present
          if (passwordField.value) {
            savedPassword = passwordField.value;
            window.savedPassword = savedPassword;
          }
        }
      };
      
      // Setup protection immediately
      setupProtection();
      
      // Also handle dynamic forms by checking again after a delay
      setTimeout(setupProtection, 500);
      
      // 5. BACKUP PROTECTION: PERIODIC CHECK
      setInterval(function() {
        const usernameField = document.querySelector("input[name='username']");
        const passwordField = document.querySelector("input[name='password']");
        
        if (usernameField && savedUsername && usernameField.value === '') {
          console.log('Periodic check: Username field was cleared');
          restoreFormValues();
        }
        
        if (passwordField && savedPassword && passwordField.value === '') {
          console.log('Periodic check: Password field was cleared');
          restoreFormValues();
        }
      }, 300);
    })();
  ''');
}

Future<void> clearSession() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Clear stored credentials but keep username for convenience
    String? username = prefs.getString(_kUsernameKey);
    await prefs.remove(_kPasswordKey);
    await prefs.remove(_kCookiesKey);
    await prefs.remove(_kSessionExpiry);

    // Clear all cookies
    await _cookieManager.deleteAllCookies();

    developer.log("✅ Session cleared" + (username != null ? " for user: $username" : ""),
        name: "SessionManager");
  } catch (e) {
    developer.log("❌ Error clearing session: $e", name: "SessionManager");
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

    // Check if session is expired
    final now = DateTime.now().millisecondsSinceEpoch;
    return now < expiryTime;
  } catch (e) {
    developer.log("⚠️ Error checking login status: $e", name: "SessionManager");
    return false;
  }
}

