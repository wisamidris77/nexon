import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool debugMode;

  const AppSettings({this.debugMode = false});

  AppSettings copyWith({bool? debugMode}) {
    return AppSettings(debugMode: debugMode ?? this.debugMode);
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final debugMode = prefs.getBool('debugMode') ?? false;

    state = AppSettings(debugMode: debugMode);
  }

  Future<void> toggleDebugMode() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !state.debugMode;

    await prefs.setBool('debugMode', newValue);
    state = state.copyWith(debugMode: newValue);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
