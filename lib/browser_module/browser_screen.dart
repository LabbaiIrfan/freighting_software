// browser_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../network/network_status_checker.dart';
import 'webview_controller.dart';
import 'webview_handlers/navigation_handler.dart';
import 'webview_handlers/error_handler.dart';
import 'ui_components/splash_screen.dart';
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
                      });
                    }

                    await _webViewController.onLoadStop(url);
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

        // Loading Indicator covers the WebView until loading is complete
        if (_browserState.progress < 1.0)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white, // Ensure it fully covers the WebView
            child: LoadingIndicator(
              progress: _browserState.progress,
              initialLoadComplete: _browserState.initialLoadComplete,
            ),
          ),

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webViewController.dispose();
    super.dispose();
  }
}