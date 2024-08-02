import 'package:flutter/widgets.dart';
import 'package:tawkie/services/matomo/tracking_service.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  final TrackingService trackingService;
  DateTime? _startTime;

  AppLifecycleObserver({required this.trackingService});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App has come to the foreground
      _startTime = DateTime.now();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App is going to the background or detached
      if (_startTime != null) {
        final duration = DateTime.now().difference(_startTime!);
        trackingService.accumulateUsageTime(duration);
      }
      // Send usage data when the app is paused or detached
      trackingService.sendUsageData();
    }
  }
}
