// ui_components/error_view.dart
import 'package:flutter/material.dart';
import '../../network/network_status_checker.dart'; // Import your ConnectivityHandler

/// Error display when page fails to load
class ErrorView extends StatefulWidget {
  final VoidCallback onTryAgain;
  final bool initialLoadingState;

  const ErrorView({
    Key? key,
    required this.onTryAgain,
    this.initialLoadingState = false,
  }) : super(key: key);

  @override
  State<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<ErrorView> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLoading = widget.initialLoadingState;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Replace this with your actual image asset
              Image.asset(
                'assets/no_internet.png',
                width: 270,
                height: 270,
              ),

              const SizedBox(height: 40),

              // "Ooops!" with slight opacity
              Text(
                'Ooops!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black.withOpacity(0.85), // ~85% opacity
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'No Internet Connection found\nCheck your connection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.5,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 35),

              SizedBox(
                width: 150,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                    setState(() {
                      _isLoading = true;
                    });

                    // Check if there's actual internet connectivity before proceeding
                    final hasInternet = await ConnectivityHandler.hasActualInternetConnectivity();

                    if (hasInternet) {
                      widget.onTryAgain();
                    } else {
                      // If still no internet, show a message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Still no internet connection. Please check your settings.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }

                    setState(() {
                      _isLoading = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF4B4B), // Red button color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}