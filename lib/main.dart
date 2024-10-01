import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matrix/matrix.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawkie/config/app_config.dart';
import 'package:tawkie/services/update_service.dart';
import 'package:tawkie/utils/app_info.dart';
import 'package:tawkie/utils/client_manager.dart';
import 'package:tawkie/utils/platform_infos.dart';
import 'package:tawkie/widgets/error_widget.dart';
import 'package:updat/updat.dart';
import 'config/setting_keys.dart';
import 'utils/background_push.dart';
import 'widgets/fluffy_chat_app.dart';

void main() async {
  Logs().i('Welcome to ${AppConfig.applicationName} <3');

  // Our background push shared isolate accesses flutter-internal things very early in the startup proccess
  // To make sure that the parts of flutter needed are started up already, we need to ensure that the
  // widget bindings are initialized already.
  WidgetsFlutterBinding.ensureInitialized();
  if (PlatformInfos.shouldInitializePurchase()) {
    await initPlatformState();
  }

  // Update check only for Windows
  if (PlatformInfos.isWindows) {

    final String currentVersion = await getAppVersion();

    UpdatWidget(
      currentVersion: currentVersion,
      getLatestVersion: () => getLatestVersionFromGitHub(),
      getBinaryUrl: (latestVersion) async {
        final url = await getWindowsExeDownloadUrl();
        return url ?? "";
      },
      // Lastly, enter your app name so we know what to call your files.
      appName: AppConfig.applicationName,
    );
  }

  Logs().nativeColors = !PlatformInfos.isIOS;
  final store = await SharedPreferences.getInstance();
  final clients = await ClientManager.getClients(store: store);

  // If the app starts in detached mode, we assume that it is in
  // background fetch mode for processing push notifications. This is
  // currently only supported on Android.
  if (PlatformInfos.isAndroid &&
      AppLifecycleState.detached == WidgetsBinding.instance.lifecycleState) {
    // Do not send online presences when app is in background fetch mode.
    for (final client in clients) {
      client.backgroundSync = false;
      client.syncPresence = PresenceType.offline;
    }

    // In the background fetch mode we do not want to waste ressources with
    // starting the Flutter engine but process incoming push notifications.
    BackgroundPush.clientOnly(clients.first);
    // To start the flutter engine afterwards we add an custom observer.
    WidgetsBinding.instance.addObserver(AppStarter(clients, store));
    Logs().i(
      '${AppConfig.applicationName} started in background-fetch mode. No GUI will be created unless the app is no longer detached.',
    );
    return;
  }

  // Started in foreground mode.
  Logs().i(
    '${AppConfig.applicationName} started in foreground mode. Rendering GUI...',
  );
  await startGui(clients, store);
}

// Function to initialize Revenu Cat
Future<void> initPlatformState() async {
  if (kDebugMode) await Purchases.setDebugLogsEnabled(true);

  PurchasesConfiguration configuration;
  if (PlatformInfos.shouldInitializePurchase()) {
    if (Platform.isAndroid) {
      configuration =
          PurchasesConfiguration("goog_lhTZglaLiBBNlhsGkdTyfcltutm");
    } else {
      //For iOS and MacOS
      configuration =
          PurchasesConfiguration("appl_vgoGBkjRMINLCIEFTYHxdGDRrKK");
    }

    await Purchases.configure(configuration);
  }
}

/// Fetch the pincode for the applock and start the flutter engine.
Future<void> startGui(List<Client> clients, SharedPreferences store) async {
  // Fetch the pin for the applock if existing for mobile applications.
  String? pin;
  if (PlatformInfos.isMobile) {
    try {
      pin =
          await const FlutterSecureStorage().read(key: SettingKeys.appLockKey);
    } catch (e, s) {
      Logs().d('Unable to read PIN from Secure storage', e, s);
    }
  }

  // Preload first client
  final firstClient = clients.firstOrNull;
  await firstClient?.roomsLoading;
  await firstClient?.accountDataLoading;

  ErrorWidget.builder = (details) => FluffyChatErrorWidget(details);
  runApp(FluffyChatApp(clients: clients, pincode: pin, store: store));
}

/// Watches the lifecycle changes to start the application when it
/// is no longer detached.
class AppStarter with WidgetsBindingObserver {
  final List<Client> clients;
  final SharedPreferences store;
  bool guiStarted = false;

  AppStarter(this.clients, this.store);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (guiStarted) return;
    if (state == AppLifecycleState.detached) return;

    Logs().i(
      '${AppConfig.applicationName} switches from the detached background-fetch mode to ${state.name} mode. Rendering GUI...',
    );
    // Switching to foreground mode needs to reenable send online sync presence.
    for (final client in clients) {
      client.backgroundSync = true;
      client.syncPresence = PresenceType.online;
    }
    startGui(clients, store);
    // We must make sure that the GUI is only started once.
    guiStarted = true;
  }
}
