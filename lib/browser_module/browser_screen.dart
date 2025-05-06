// browser_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../network/network_status_checker.dart';
import 'webview_controller.dart';
import 'webview_handlers/navigation_handler.dart';
import 'webview_handlers/error_handler.dart';
import 'webview_handlers/javascript_handler.dart'; // Make sure to import this for JSHandler
import 'ui_components/splash_screen.dart';
import 'ui_components/loading_indicator.dart'; // Import the new loading indicator
import 'ui_components/error_view.dart';
import 'browser_state.dart';

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;
  final bool showAppBar;
  final bool isNavigationPage;

  const WebViewPage({
    super.key,
    required this.url,
    this.title = 'Freighting App',
    this.showAppBar = false,
    this.isNavigationPage = false,
  });

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> with WidgetsBindingObserver {
  // Controllers and handlers
  final WebViewController _webViewController = WebViewController();
  final ErrorHandler _errorHandler = ErrorHandler();
  final BrowserState _browserState = BrowserState();

  // Google Password Manager detection variables
  bool _googlePasswordManagerDetected = false;
  bool _loginAttemptedWithPM = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _browserState.updateUrl(widget.url);
    _monitorConnectivity();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save session when app goes to background
    if (state == AppLifecycleState.paused && _webViewController.controller != null) {
      _webViewController.dispose();
    }

    // Refresh connection status when app is resumed
    if (state == AppLifecycleState.resumed) {
      _errorHandler.initConnectivity();

      // Reload WebView if needed
      if (_webViewController.controller != null &&
          !_browserState.isLoading &&
          _browserState.initialLoadComplete) {
        _webViewController.reload();
      }
    }
  }

  void _monitorConnectivity() async {
    await _errorHandler.initConnectivity();
    _errorHandler.monitorConnectivity((isConnected) {
      setState(() {
        if (isConnected &&
            _webViewController.controller != null &&
            _browserState.initialLoadComplete) {
          _webViewController.reload();
        }
      });
    });
  }

  // Google Password Manager detection and handling methods
  void _setupGooglePasswordManagerDetection() {
    if (_webViewController.controller == null) return;

    _webViewController.controller!.evaluateJavascript(source: '''
      // Function to handle when Google Password Manager is detected
      window.handleGooglePasswordManager = function() {
        // This function will be called when we detect the Google Password Manager dialog
        window.flutter_inappwebview.callHandler('googlePasswordManagerDetected', {});
        console.log("Google Password Manager detected");
      };
      
      // Look for the Google Password Manager UI by its characteristic elements
      function detectPasswordManager() {
        // Check for Google's password manager bubble/UI
        const googlePMElements = document.querySelectorAll('div[role="dialog"][aria-modal="true"]');
        
        for (const element of googlePMElements) {
          // Check for typical Google Password Manager content
          const text = element.textContent || '';
          if (text.includes("Password Manager") || 
              text.includes("saved password") || 
              text.includes("Use your saved password")) {
            console.log("Found Google Password Manager UI");
            window.handleGooglePasswordManager();
            return true;
          }
        }
        
        // Also check for "Continue" button which often appears in the Google PM dialog
        const continueButtons = document.querySelectorAll('button');
        for (const button of continueButtons) {
          if (button.textContent.trim() === "Continue" && 
              button.closest('div[role="dialog"]')) {
            console.log("Found Continue button in dialog - likely Google PM");
            window.handleGooglePasswordManager();
            return true;
          }
        }
        
        return false;
      }
      
      // Run detection immediately and also set up a mutation observer
      detectPasswordManager();
      
      // Set up an observer to detect when Google PM appears
      const observer = new MutationObserver((mutations) => {
        for (const mutation of mutations) {
          if (mutation.addedNodes.length > 0) {
            if (detectPasswordManager()) {
              observer.disconnect();
              break;
            }
          }
        }
      });
      
      // Start observing
      observer.observe(document.body, { childList: true, subtree: true });
      
      // Also set up a timer as backup
      setTimeout(detectPasswordManager, 1000);
      setTimeout(detectPasswordManager, 2000);
    ''');

    // Add handler for password manager detection
    _webViewController.controller!.addJavaScriptHandler(
        handlerName: 'googlePasswordManagerDetected',
        callback: (args) {
          setState(() {
            _googlePasswordManagerDetected = true;
          });

          // Set up handlers for after the user chooses "Continue" in Google PM
          _handleGooglePasswordSelection();
          return null;
        }
    );
  }

  // Handle what happens after user selects "Continue" in Google Password Manager
  void _handleGooglePasswordSelection() {
    Future.delayed(Duration(milliseconds: 1500), () {
      if (_webViewController.controller == null || _loginAttemptedWithPM) return;

      _loginAttemptedWithPM = true;

      // Force a click on the login button after Google PM fills the fields
      _webViewController.controller!.evaluateJavascript(source: '''
        (function() {
          try {
            // Find inputs first to identify the form
            const usernameField = document.querySelector("input[name='username']");
            const passwordField = document.querySelector("input[name='password']");
            
            if (!usernameField || !passwordField) return false;
            
            // Get the form
            const loginForm = usernameField.closest('form');
            if (!loginForm) return false;
            
            console.log("Found login form after Google PM");
            
            // Ensure the fields are properly "known" to the page
            usernameField.dispatchEvent(new Event('input', { bubbles: true }));
            passwordField.dispatchEvent(new Event('input', { bubbles: true }));
            usernameField.dispatchEvent(new Event('change', { bubbles: true }));
            passwordField.dispatchEvent(new Event('change', { bubbles: true }));
            
            // Find the submit button - be very thorough
            const submitButton = 
              loginForm.querySelector('button[type="submit"]') || 
              loginForm.querySelector('input[type="submit"]') ||
              Array.from(loginForm.querySelectorAll('button')).find(btn => 
                btn.textContent.toLowerCase().includes('sign in') || 
                btn.textContent.toLowerCase().includes('login') ||
                btn.textContent.toLowerCase().includes('log in') ||
                btn.textContent.toLowerCase().includes('submit')) ||
              document.querySelector('.login-btn') ||
              document.querySelector('.signin-btn');
              
            console.log("Submit button found:", !!submitButton);
            
            if (submitButton) {
              // Save values to our own storage first
              window.savedUsername = usernameField.value;
              window.savedPassword = passwordField.value;
              
              // Click the button
              submitButton.click();
              console.log("Clicked submit button after Google PM fill");
              return true;
            } else if (loginForm.submit) {
              // Try direct form submission as fallback
              window.savedUsername = usernameField.value;
              window.savedPassword = passwordField.value;
              
              try {
                loginForm.submit();
                console.log("Submitted form after Google PM fill");
                return true;
              } catch(e) {
                console.error("Error submitting form:", e);
              }
            }
            
            return false;
          } catch(e) {
            console.error("Error handling Google PM:", e);
            return false;
          }
        })();
      ''');
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.isNavigationPage
        ? _buildNavigationPageView()
        : _buildMainWebView();
  }

  Widget _buildNavigationPageView() {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          if (await _webViewController.canGoBack()) {
            _webViewController.goBack();
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: _buildWebViewContent(),
      ),
    );
  }

  Widget _buildMainWebView() {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await NavigationHandler.handleBackNavigation(
            _webViewController.controller,
            context,
            widget.isNavigationPage,
          );
        }
      },
      child: Scaffold(
        appBar: widget.showAppBar ? AppBar(
          title: Text(widget.title),
          backgroundColor: const Color(0xFF3794C8),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _webViewController.reload(),
            ),
          ],
        ) : null,
        body: _buildWebViewContent(),
      ),
    );
  }

  Widget _buildWebViewContent() {
    return Stack(
      children: [
        // WebView is always loaded but only visible when loading is complete
        SafeArea(
          child: Column(
            children: [
              // WebView
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                  initialSettings: _webViewController.getWebViewSettings(),
                  pullToRefreshController: _webViewController.pullToRefreshController,

                  onWebViewCreated: (controller) async {
                    await _webViewController.onWebViewCreated(controller);

                    // Initialize Google Password Manager detection
                    _setupGooglePasswordManagerDetection();
                  },

                  onLoadStart: (controller, url) {
                    if (url != null) {
                      setState(() {
                        _browserState.startPageLoad(url.toString());
                      });
                    }
                  },

                  onLoadStop: (controller, url) async {
                    if (url != null) {
                      setState(() {
                        _browserState.finishPageLoad(url.toString());
                        // Reset the flag when navigating
                        _loginAttemptedWithPM = false;
                      });
                    }

                    await _webViewController.onLoadStop(url);

                    // If on login page, detect Google PM again
                    final bool isLoginPage = await JSHandler.isLoginPage(controller);
                    if (isLoginPage) {
                      _setupGooglePasswordManagerDetection();
                    }
                  },

                  onProgressChanged: (controller, progressValue) {
                    setState(() {
                      _browserState.updateProgress(progressValue / 100);
                    });
                  },

                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    return NavigationHandler.handleUrlOverride(
                      controller,
                      navigationAction,
                      context,
                    );
                  },

                  onPermissionRequest: (controller, request) async {
                    return _webViewController.onPermissionRequest(request);
                  },

                  onLoadError: (controller, url, code, message) {
                    setState(() {
                      _errorHandler.onLoadError();
                      _browserState.setLoading(false);
                      _browserState.setPageError(true);
                    });
                    // Make sure to end refreshing on error
                    if (_webViewController.pullToRefreshController != null) {
                      _webViewController.pullToRefreshController!.endRefreshing();
                    }
                  },

                  onReceivedServerTrustAuthRequest: (controller, challenge) async {
                    return _webViewController.onReceivedServerTrustAuthRequest();
                  },

                  onConsoleMessage: (controller, consoleMessage) async {
                    debugPrint("Console: ${consoleMessage.message}");
                  },
                ),
              ),
            ],
          ),
        ),

        // Loading handling based on initial load vs subsequent loads
        _buildLoadingView(),

        // Display "No Internet" overlay if no connection is available
        ValueListenableBuilder<bool>(
          valueListenable: ConnectivityHandler.isConnected,
          builder: (context, isConnected, child) {
            return !isConnected
                ? Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: ErrorView(
                onTryAgain: _errorHandler.isTryingAgain
                    ? () {} // Empty function when already trying
                    : () => _errorHandler.tryAgain(_webViewController.controller),
                initialLoadingState: _errorHandler.isTryingAgain,
              ),
            )
                : const SizedBox.shrink();
          },
        ),

        // Display error view if page fails to load
        if (_browserState.isPageError && _browserState.initialLoadComplete)
          ErrorView(
            onTryAgain: () {
              setState(() {
                _browserState.setPageError(false);
                _webViewController.reload();
              });
            },
            // isLoading: false, // Set to true when loading, if needed
          ),
      ],
    );
  }

  // New method to handle different loading states
  Widget _buildLoadingView() {
    if (_browserState.progress >= 1.0) {
      // Nothing to show when fully loaded
      return const SizedBox.shrink();
    }

    // For initial app load, show splash screen
    if (!_browserState.initialLoadComplete) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: LoadingIndicator(
          progress: _browserState.progress,
          initialLoadComplete: _browserState.initialLoadComplete,
        ),
      );
    }
    // For subsequent page loads, show red circular loader
    else {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white.withOpacity(0.7),
        child: WebViewLoadingIndicator(
          progress: _browserState.progress,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webViewController.dispose();
    super.dispose();
  }
}