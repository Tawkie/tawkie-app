import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tawkie/config/app_config.dart';
import 'package:url_launcher/url_launcher_string.dart';

abstract class PlatformInfos {
  static bool get isWeb => kIsWeb;

  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static bool get isWindows => !kIsWeb && Platform.isWindows;

  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static bool get isCupertinoStyle => isIOS || isMacOS;

  static bool get isMobile => isAndroid || isIOS;

  /// For desktops which don't support ChachedNetworkImage yet
  static bool get isBetaDesktop => isWindows || isLinux;

  static bool get isDesktop => isLinux || isWindows || isMacOS;

  static bool get usesTouchscreen => !isMobile;

  /// Web could also record in theory but currently only wav which is too large
  static bool get platformCanRecord => (isMobile || isMacOS);

  static String get clientName =>
      '${AppConfig.applicationName} ${isWeb ? 'web' : Platform.operatingSystem}${kReleaseMode ? '' : 'Debug'}';

  static bool shouldInitializePurchase() {
    if (!kIsWeb) {
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    } else {
      return false; // Do not initialize web purchases
    }
  }

  static String getPlatform() {
    if (PlatformInfos.isIOS) {
      return 'iOS';
    } else if (PlatformInfos.isAndroid) {
      return 'Android';
    } else if (PlatformInfos.isWeb) {
      return 'Web';
    } else if (PlatformInfos.isLinux) {
      return 'Linux';
    } else if (PlatformInfos.isWindows) {
      return 'Windows';
    } else if (PlatformInfos.isMacOS) {
      return 'MacOS';
    } else {
      return 'Unknown';
    }
  }

  /// Function to obtain the icon according to the platform
  static Widget getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return const Icon(Icons.android, color: Colors.white, size: 16);
      case 'ios':
        return const Icon(Icons.apple, color: Colors.white, size: 16);
      case 'windows':
        return const Icon(Icons.window, color: Colors.white, size: 16);
      case 'macos':
        return const Icon(Icons.laptop_mac, color: Colors.white, size: 16);
      case 'linux':
        return const Icon(Icons.laptop, color: Colors.white, size: 16);
      default:
        return const Icon(Icons.device_unknown, color: Colors.white, size: 16);
    }
  }

  /// Function to obtain the background color of the platForm
  static Color getPlatformBackgroundColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return const Color(0xFF78C257);
      case 'ios':
        return const Color(0xFF555555);
      case 'windows':
        return const Color(0xFF00A4EF);
      case 'macos':
        return const Color(0xFF000000);
      case 'linux':
        return const Color(0xFFFCC624);
      default:
        return Colors.grey;
    }
  }

  static Future<String> getVersion() async {
    var version = kIsWeb ? 'Web' : 'Unknown';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    return version;
  }

  static void showDialog(BuildContext context) async {
    final version = await PlatformInfos.getVersion();
    showAboutDialog(
      context: context,
      children: [
        Text('Version: $version'),
        TextButton.icon(
          onPressed: () => launchUrlString(AppConfig.sourceCodeUrl),
          icon: const Icon(Icons.source_outlined),
          label: Text(L10n.of(context)!.sourceCode),
        ),
        TextButton.icon(
          onPressed: () => launchUrlString(AppConfig.aboutUrl),
          icon: const Icon(Icons.group),
          label: Text(L10n.of(context)!.about),
        ),
        // TextButton.icon(
        //   onPressed: () => launchUrlString(AppConfig.emojiFontUrl),
        //   icon: const Icon(Icons.emoji_emotions_outlined),
        //   label: const Text(AppConfig.emojiFontName),
        // ),
        // Builder(
        //   builder: (innerContext) {
        //     return TextButton.icon(
        //       onPressed: () {
        //         context.go('/logs');
        //         Navigator.of(innerContext).pop();
        //       },
        //       icon: const Icon(Icons.list_outlined),
        //       label: const Text('Logs'),
        //     );
        //   },
        // ),
      ],
      applicationIcon: Image.asset(
        'assets/logo.png',
        width: 64,
        height: 64,
        filterQuality: FilterQuality.medium,
      ),
      applicationName: AppConfig.applicationName,
    );
  }
}
