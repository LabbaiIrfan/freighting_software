import 'package:flutter/material.dart';

/// Red circular loading indicator for webview page loads
class WebViewLoadingIndicator extends StatelessWidget {
  final double progress;

  const WebViewLoadingIndicator({
    Key? key,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // Transparent background
      color: Colors.transparent,
      child: Center(
        child: SizedBox(
          width: 40,
          height: 40,
          // Just the red circular progress indicator
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
            strokeWidth: 3.0,
            // Use the progress value for determinate progress
            value: progress,
          ),
        ),
      ),
    );
  }
}