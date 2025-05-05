// file_handlers.dart
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:open_filex/open_filex.dart';

/// Handles opening and downloading file_manager from WebView
class FileOpenHandler {
  /// Opens a file in an external app or downloads it if necessary
  static Future<void> openFileOrDownload(BuildContext context, String url) async {
    try {
      Uri uri = Uri.parse(url);
      final String fileName = _getFileName(uri);

      // Show loading indicator
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(width: 16),
              Text('Preparing file...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Try to open with URL launcher first
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // If can't launch, download the file
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to download: HTTP ${response.statusCode}')),
        );
        return;
      }

      // Get directory to save the file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = path.join(directory.path, fileName);

      // Write the file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Show success message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('File downloaded: $fileName'),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () => _openFile(file.path),
          ),
        ),
      );

      // Try to open the file
      await _openFile(file.path);
    } catch (e) {
      developer.log('❌ Error opening file: $e', name: 'FileHandler');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: ${e.toString()}')),
      );
    }
  }

  /// Extracts filename from URL, with fallback for URLs without a filename
  static String _getFileName(Uri uri) {
    String fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';

    if (fileName.isEmpty) {
      // Generate a filename if none exists
      fileName = 'download_${DateTime.now().millisecondsSinceEpoch}';

      // Add extension based on content-type if possible
      if (uri.queryParameters.containsKey('type')) {
        final type = uri.queryParameters['type']!;
        if (type.contains('pdf')) fileName += '.pdf';
        else if (type.contains('excel')) fileName += '.xlsx';
        else if (type.contains('word')) fileName += '.docx';
      }
    }

    return fileName;
  }

  /// Opens a file with the default app
  static Future<void> _openFile(String filePath) async {
    try {
      await OpenFilex.open(filePath);
    } catch (e) {
      developer.log('❌ Failed to open file: $e', name: 'FileHandler');
    }
  }
}

/// Handles file uploads from the WebView
class FileUploadHandler {
  /// Handles permission requests from WebView
  static Future<PermissionResponse> handlePermissionRequest(
      List<PermissionResourceType> resources) async {
    developer.log('📂 WebView requested permissions: $resources', name: 'FileHandler');

    // Grant permissions for camera, microphone, etc.
    return PermissionResponse(
      resources: resources,
      action: PermissionResponseAction.GRANT,
    );
  }

  /// For older versions of flutter_inappwebview
  static Future<PermissionRequestResponse> handleDeprecatedPermissionRequest(
      List<String> resources) async {
    developer.log('📂 WebView requested permissions (deprecated): $resources', name: 'FileHandler');

    // Grant permissions for camera, microphone, etc.
    return PermissionRequestResponse(
      resources: resources,
      action: PermissionRequestResponseAction.GRANT,
    );
  }

  /// Modified to remove file chooser handling that was causing errors
  /// Implement this function based on your version of flutter_inappwebview
  /// This is a simplified version that just logs the event
  static void handleFileChooser(InAppWebViewController controller) {
    developer.log('📂 File chooser functionality disabled', name: 'FileHandler');
    // File chooser implementation removed to fix compilation errors
  }
}