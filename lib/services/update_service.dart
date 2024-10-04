import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String?> getLatestVersionFromGitHub() async {
  final String url = "https://api.github.com/repos/Tawkie/tawkie-app/releases/latest";
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    String latestVersion = data['tag_name']; // Retrieves the tag for the latest version

    // Remove the first character 'v'
    if (latestVersion.startsWith('v')) {
      latestVersion = latestVersion.substring(1);
    }
    return latestVersion;
  } else {
    if (kDebugMode) {
      print('Error retrieving version information: ${response.statusCode}');
    }
    return null;
  }
}

Future<String?> getWindowsExeDownloadUrl() async {
  try {
    final String url = "https://api.github.com/repos/Tawkie/tawkie-app/releases/latest";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> assets = data['assets'];

      // Browse asset list to find URL of Windows file (.exe)
      for (var asset in assets) {
        if (asset['name'].endsWith('.exe')) {
          print("URL du fichier .exe : ${asset['browser_download_url']}");
          return asset['browser_download_url'];
        }
      }
      if (kDebugMode) {
        print('No .exe files found in release assets.');
      }
      return null;
    } else {
      if (kDebugMode) {
        print('Error retrieving release information: ${response.statusCode}');
      }
      return null;
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error retrieving URL:$e");
    }
    return null;
  }
}
