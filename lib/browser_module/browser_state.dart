// browser_state.dart
import 'package:flutter/material.dart';

/// Manages the state of the browser
class BrowserState extends ChangeNotifier {
  /// Current page URL
  String _currentUrl = '';
  String get currentUrl => _currentUrl;

  /// Loading progress (0.0 to 1.0)
  double _progress = 0.0;
  double get progress => _progress;

  /// Whether the page is currently loading
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  /// Whether the initial page load has completed
  bool _initialLoadComplete = false;
  bool get initialLoadComplete => _initialLoadComplete;

  /// Whether there's a page error
  bool _isPageError = false;
  bool get isPageError => _isPageError;

  /// Whether we're trying to reconnect
  bool _isTryingAgain = false;
  bool get isTryingAgain => _isTryingAgain;

  /// Update the current URL
  void updateUrl(String url) {
    _currentUrl = url;
    notifyListeners();
  }

  /// Update the loading progress
  void updateProgress(double value) {
    _progress = value;
    notifyListeners();
  }

  /// Set loading state
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Set initial load complete
  void completeInitialLoad() {
    _initialLoadComplete = true;
    notifyListeners();
  }

  /// Set page error
  void setPageError(bool value) {
    _isPageError = value;
    notifyListeners();
  }

  /// Set trying again status
  void setTryingAgain(bool value) {
    _isTryingAgain = value;
    notifyListeners();
  }

  /// Reset state for a new page load
  void startPageLoad(String url) {
    _currentUrl = url;
    _isLoading = true;
    _isPageError = false;
    notifyListeners();
  }

  /// Complete page load
  void finishPageLoad(String url) {
    _currentUrl = url;
    _isLoading = false;

    if (!_initialLoadComplete) {
      _initialLoadComplete = true;
    }

    notifyListeners();
  }
}