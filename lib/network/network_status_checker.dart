// network_status_checker.dart
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io'; // Add this import for HttpClient

/// Handles network network state and monitoring
class ConnectivityHandler {
  /// Value notifier that tracks if the device is connected to a network
  static ValueNotifier<bool> isConnected = ValueNotifier<bool>(true);

  /// Value notifier that indicates network type (wifi, mobile, none)
  static ValueNotifier<ConnectivityResult> connectionType =
  ValueNotifier<ConnectivityResult>(ConnectivityResult.none);

  /// Stream subscription for network changes
  static var _subscription;

  /// Initialize network monitoring
  static void initializeConnectivityMonitoring() {
    try {
      // Check initial network status
      Connectivity().checkConnectivity().then((result) {
        _updateConnectivityState(result);
      });

      // Listen for network changes
      _subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
        _updateConnectivityState(result);
      });

      developer.log('✅ Connectivity monitoring initialized', name: 'ConnectivityHandler');
    } catch (e) {
      developer.log('❌ Error setting up network monitoring: $e', name: 'ConnectivityHandler');
      // Fallback to assume we're connected
      isConnected.value = true;
    }
  }

  /// Updates network state and notifies listeners
  static void _updateConnectivityState(ConnectivityResult result) {
    connectionType.value = result;
    isConnected.value = result != ConnectivityResult.none;

    developer.log('🌐 Connectivity changed: ${result.name} (connected: ${isConnected.value})',
        name: 'ConnectivityHandler');
  }

  /// Manually check network status and update state
  static Future<bool> checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectivityState(result);
      return isConnected.value;
    } catch (e) {
      developer.log('❌ Error checking network: $e', name: 'ConnectivityHandler');
      return true; // Assume connected on error
    }
  }

  /// Check if there's actual internet connectivity by making a test request
  /// This is more reliable than just checking connectivity status
  static Future<bool> hasActualInternetConnectivity() async {
    try {
      // First check if device is connected to a network
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Then make an actual request to verify internet connectivity
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(Uri.parse('https://www.google.com'));
      final response = await request.close();
      await response.drain<void>();

      return response.statusCode == 200;
    } catch (e) {
      developer.log('❌ Internet check failed: $e', name: 'ConnectivityHandler');
      return false;
    }
  }

  /// Dispose of resources when no longer needed
  static void dispose() {
    _subscription?.cancel();
  }

  /// Get a human-readable network type
  static String getNetworkTypeName() {
    switch (connectionType.value) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.none:
        return 'Offline';
      default:
        return 'Unknown';
    }
  }
}