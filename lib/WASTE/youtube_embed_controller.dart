// youtube_embed_controller.dart
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// List of domains that should be opened in external apps
final List<String> _externalDomains = [
  'youtube.com',
  'youtu.be',
  'maps.google.com',
  'drive.google.com',
  'docs.google.com',
  'play.google.com',
  'meet.google.com',
  'zoom.us',
  'microsoft.com',
  'teams.microsoft.com',
  'linkedin.com',
];

/// List of file extensions that should be downloaded/opened externally
final List<String> _externalFileExtensions = [
  '.pdf',
  '.doc',
  '.docx',
  '.xls',
  '.xlsx',
  '.ppt',
  '.pptx',
  '.csv',
  '.zip',
  '.rar',
  '.apk',
];

/// Handles navigation to determine if URLs should be opened externally
Future<NavigationActionPolicy> handleExternalNavigation(
    InAppWebViewController controller, NavigationAction navigationAction) async {

  final Uri? url = navigationAction.request.url;
  if (url == null) return NavigationActionPolicy.ALLOW;

  final String host = url.host.toLowerCase();
  final String path = url.path.toLowerCase();

  try {
    // Check if URL should be opened in an external app
    bool shouldOpenExternally = _externalDomains.any((domain) => host.contains(domain));

    // Check if it's a file that should be handled externally
    bool isExternalFile = _externalFileExtensions.any((ext) => path.endsWith(ext));

    // Handle external URLs
    if (shouldOpenExternally || isExternalFile) {
      developer.log("🌐 Opening external URL: $url", name: "UrlHandler");

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        developer.log("❌ Cannot launch URL: $url", name: "UrlHandler");
      }
      return NavigationActionPolicy.CANCEL;
    }

    // Handle mailto: links
    if (url.scheme == 'mailto') {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
      return NavigationActionPolicy.CANCEL;
    }

    if (url.scheme == 'tel') {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
      return NavigationActionPolicy.CANCEL;
    }

    // Handle SMS links
    if (url.scheme == 'sms') {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
      return NavigationActionPolicy.CANCEL;
    }

    // For all other URLs, allow the WebView to handle them
    return NavigationActionPolicy.ALLOW;
  } catch (e) {
    developer.log("❌ Error handling URL: $e", name: "UrlHandler");
    return NavigationActionPolicy.ALLOW;
  }
}