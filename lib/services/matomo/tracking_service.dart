import 'package:flutter/foundation.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:tawkie/services/nps_service.dart';
import 'package:tawkie/utils/platform_infos.dart';

enum DeviceType {
  android,
  ios,
  windows,
  linux,
  macos,
  unknown,
}

enum MessageType {
  voice,
  image,
  file,
  video,
  location,
}

class TrackingService extends ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch();

  void startStopwatch() {
    _stopwatch.start();
    if (kDebugMode) {
      print("Stopwatch started: ${_stopwatch.elapsedMilliseconds} ms");
    }
  }

  void stopAndTrackEvent(String eventName) {
    _stopwatch.stop();
    final elapsedTime = _stopwatch.elapsedMilliseconds;

    if (kDebugMode) {
      print("Stopwatch stopped: $elapsedTime ms");
    }

    _stopwatch.reset();
    notifyListeners();
  }

  Future<void> trackConnectionTimes() async {
    final elapsedTime = _stopwatch.elapsedMilliseconds;
    if (kDebugMode) {
      print('Elapsed Time: $elapsedTime ms');
    }

    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'register',
        action: 'connection',
        name: 'Average Connection Time',
        value: elapsedTime.toDouble(),
      ),
    );
  }

  // Method to track attempts to add a bridge
  void trackRegisterBridgeAddAttempt(String bridgeName) {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'register',
        action: 'attempt to adds a bridge',
        name: bridgeName,
      ),
    );
    if (kDebugMode) {
      print('Bridge add attempt tracked: $bridgeName');
    }
  }

  void trackAuthError(String authType, String errorType) {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'auth/register',
        action: authType,
        name: errorType,
      ),
    );
    if (kDebugMode) {
      print('Auth error tracked: $authType - $errorType');
    }
  }

  void trackBridgeConnectionFailure(String bridgeName, String errorMessage) {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'bridge',
        action: 'connection_failure',
        name: '$bridgeName error_message: $errorMessage',
      ),
    );
    if (kDebugMode) {
      print('Bridge connection failure tracked: $bridgeName - $errorMessage');
    }
  }

  // Method to track attempts to add a bridge
  void trackBridgeAddAttempt(String bridgeName) {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'bridge',
        action: 'attempt',
        name: bridgeName,
      ),
    );
    if (kDebugMode) {
      print('Bridge add attempt tracked: $bridgeName');
    }
  }

  // Method to track bridges used by the user
  void trackBridgeUsed(String bridgeName) {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'bridge',
        action: 'used',
        name: bridgeName,
      ),
    );
    if (kDebugMode) {
      print('Bridge used tracked: $bridgeName');
    }
  }

  // Track app open event
  void trackAppOpen(String uuid) {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(category: 'usage', action: 'App open', name: uuid),
    );
    if (kDebugMode) {
      print('App open tracked');
    }
  }

  Duration _accumulatedTime = Duration.zero;

  void accumulateUsageTime(Duration duration) {
    _accumulatedTime += duration;
    if (kDebugMode) {
      print(
          "Accumulated app usage time: ${_accumulatedTime.inMilliseconds} ms");
    }
  }

  void sendUsageData() {
    final usageTimeInSeconds = _accumulatedTime.inSeconds;

    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'usage',
        action: 'how long app has been used on device',
        name: 'Total Usage Time',
        value: usageTimeInSeconds.toDouble(),
      ),
    );

    if (kDebugMode) {
      print('App usage time sent: $usageTimeInSeconds seconds');
    }

    _accumulatedTime = Duration.zero; // Reset after sending
  }

  DeviceType getDeviceType() {
    if (PlatformInfos.isAndroid) {
      return DeviceType.android;
    } else if (PlatformInfos.isIOS) {
      return DeviceType.ios;
    } else if (PlatformInfos.isWindows) {
      return DeviceType.windows;
    } else if (PlatformInfos.isLinux) {
      return DeviceType.linux;
    } else if (PlatformInfos.isMacOS) {
      return DeviceType.macos;
    } else {
      return DeviceType.unknown;
    }
  }

  Future<void> trackDeviceUsage() async {
    DeviceType deviceType = getDeviceType();

    String deviceName;
    switch (deviceType) {
      case DeviceType.android:
        deviceName = 'Android';
        break;
      case DeviceType.ios:
        deviceName = 'iOS';
        break;
      case DeviceType.windows:
        deviceName = 'Windows';
        break;
      case DeviceType.linux:
        deviceName = 'Linux';
        break;
      case DeviceType.macos:
        deviceName = 'macOS';
        break;
      case DeviceType.unknown:
      default:
        deviceName = 'Unknown';
        break;
    }

    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'usage',
        action: 'device used',
        name: deviceName,
      ),
    );

    if (kDebugMode) {
      print('Device used tracked: $deviceName');
    }
  }

  void trackMessageSent() {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'messages',
        action: 'sent',
      ),
    );

    if (kDebugMode) {
      print('Message sent tracked in room');
    }
  }

  void trackMessageLongPress() {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'messages',
        action: 'long-press',
      ),
    );

    if (kDebugMode) {
      print('Message long-press tracked in room');
    }
  }

  void trackMessageDoubleTap() {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'messages',
        action: 'double-tap',
      ),
    );

    if (kDebugMode) {
      print('Message double-tap tracked in room');
    }
  }

  void trackSpecialMessageSent(MessageType messageType) {
    String messageTypeName;
    switch (messageType) {
      case MessageType.voice:
        messageTypeName = 'voice';
        break;
      case MessageType.image:
        messageTypeName = 'image';
        break;
      case MessageType.file:
        messageTypeName = 'file';
        break;
      case MessageType.video:
        messageTypeName = 'video';
        break;
      case MessageType.location:
        messageTypeName = 'location';
        break;
    }

    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'messages',
        action: 'sent-special',
        name: messageTypeName,
      ),
    );

    if (kDebugMode) {
      print('Special message sent tracked: $messageTypeName');
    }
  }

  void trackNotificationOpen() {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'notifications',
        action: 'opened',
      ),
    );

    if (kDebugMode) {
      print('Notification opened tracked');
    }
  }
  void trackNotificationReceived() {
    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'notifications',
        action: 'received',
      ),
    );

    if (kDebugMode) {
      print('Notification received tracked');
    }
  }

  Future<void> trackNPSScore(int score) async {
    final npsService = NPSService();
    final uniqueDaysOpened = await npsService.getUniqueDaysOpened();

    MatomoTracker.instance.trackEvent(
      eventInfo: EventInfo(
        category: 'NPS',
        action: 'User_Recommendation_Score',
        name: uniqueDaysOpened.toString(),
        value: score.toDouble(),
      ),
    );

    if (kDebugMode) {
      print('NPS score tracked: $score in $uniqueDaysOpened');
    }
  }
}
