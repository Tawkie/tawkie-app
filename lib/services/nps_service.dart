import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NPSService {
  static const _appOpeningsKey = 'app_openings';
  static const _npsShownKey = 'nps_shown';
  final int requiredOpens;
  final int requiredDays;

  NPSService({this.requiredOpens = 10, this.requiredDays = 15});

  Future<Map<DateTime, int>> _getAppOpenings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_appOpeningsKey);
    if (jsonString == null) {
      return {};
    }

    Map<String, dynamic> jsonMap = json.decode(jsonString);
    return jsonMap.map((key, value) => MapEntry(DateTime.parse(key), value));
  }

  Future<int> getUniqueDaysOpened() async {
    final appOpenings = await _getAppOpenings();
    return appOpenings.keys.length; // The number of unique days
  }

  Future<void> _setAppOpenings(Map<DateTime, int> appOpenings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(appOpenings.map((key, value) => MapEntry(key.toIso8601String(), value)));
    await prefs.setString(_appOpeningsKey, jsonString);
  }

  Future<void> recordAppOpen() async {
    final appOpenings = await _getAppOpenings();
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    if (appOpenings.containsKey(todayKey)) {
      appOpenings[todayKey] = appOpenings[todayKey]! + 1;
    } else {
      appOpenings[todayKey] = 1;
    }

    await _setAppOpenings(appOpenings);
  }

  Future<bool> shouldShowNPS() async {
    final prefs = await SharedPreferences.getInstance();
    final npsShown = prefs.getBool(_npsShownKey) ?? false;

    if (npsShown) return false; // Do not show if already shown

    final appOpenings = await _getAppOpenings();
    final DateTime thresholdDate = DateTime.now().subtract(Duration(days: requiredDays));
    int totalOpens = 0;

    appOpenings.forEach((date, opens) {
      if (date.isAfter(thresholdDate)) {
        totalOpens += opens;
      }
    });

    return totalOpens >= requiredOpens;
  }

  Future<void> setNPSShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_npsShownKey, true);
  }
}
