import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  // UI Settings
  final bool debugMode;
  final bool showAvatars;
  final bool showTimestamps;
  final bool useDarkMode;
  final bool useSystemTheme;

  // Behavior Settings
  final bool startWithNewChat;
  final bool sendOnEnter;
  final bool confirmDeleteConversation;

  // Search Settings
  final bool searchInMessages;
  final bool searchInBotMessages;
  final bool searchInUserMessages;

  // Chat Settings
  final bool autoScrollToBottom;
  final int maxConversationsInHistory;

  const AppSettings({
    this.debugMode = false,
    this.showAvatars = true,
    this.showTimestamps = true,
    this.useDarkMode = false,
    this.useSystemTheme = true,
    this.startWithNewChat = false,
    this.sendOnEnter = true,
    this.confirmDeleteConversation = true,
    this.searchInMessages = false,
    this.searchInBotMessages = true,
    this.searchInUserMessages = true,
    this.autoScrollToBottom = true,
    this.maxConversationsInHistory = 50,
  });

  AppSettings copyWith({
    bool? debugMode,
    bool? showAvatars,
    bool? showTimestamps,
    bool? useDarkMode,
    bool? useSystemTheme,
    bool? startWithNewChat,
    bool? sendOnEnter,
    bool? confirmDeleteConversation,
    bool? searchInMessages,
    bool? searchInBotMessages,
    bool? searchInUserMessages,
    bool? autoScrollToBottom,
    int? maxConversationsInHistory,
  }) {
    return AppSettings(
      debugMode: debugMode ?? this.debugMode,
      showAvatars: showAvatars ?? this.showAvatars,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      useDarkMode: useDarkMode ?? this.useDarkMode,
      useSystemTheme: useSystemTheme ?? this.useSystemTheme,
      startWithNewChat: startWithNewChat ?? this.startWithNewChat,
      sendOnEnter: sendOnEnter ?? this.sendOnEnter,
      confirmDeleteConversation: confirmDeleteConversation ?? this.confirmDeleteConversation,
      searchInMessages: searchInMessages ?? this.searchInMessages,
      searchInBotMessages: searchInBotMessages ?? this.searchInBotMessages,
      searchInUserMessages: searchInUserMessages ?? this.searchInUserMessages,
      autoScrollToBottom: autoScrollToBottom ?? this.autoScrollToBottom,
      maxConversationsInHistory: maxConversationsInHistory ?? this.maxConversationsInHistory,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // UI Settings
    final debugMode = prefs.getBool('debugMode') ?? false;
    final showAvatars = prefs.getBool('showAvatars') ?? true;
    final showTimestamps = prefs.getBool('showTimestamps') ?? true;
    final useDarkMode = prefs.getBool('useDarkMode') ?? false;
    final useSystemTheme = prefs.getBool('useSystemTheme') ?? true;

    // Behavior Settings
    final startWithNewChat = prefs.getBool('startWithNewChat') ?? false;
    final sendOnEnter = prefs.getBool('sendOnEnter') ?? true;
    final confirmDeleteConversation = prefs.getBool('confirmDeleteConversation') ?? true;

    // Search Settings
    final searchInMessages = prefs.getBool('searchInMessages') ?? false;
    final searchInBotMessages = prefs.getBool('searchInBotMessages') ?? true;
    final searchInUserMessages = prefs.getBool('searchInUserMessages') ?? true;

    // Chat Settings
    final autoScrollToBottom = prefs.getBool('autoScrollToBottom') ?? true;
    final maxConversationsInHistory = prefs.getInt('maxConversationsInHistory') ?? 50;

    state = AppSettings(
      debugMode: debugMode,
      showAvatars: showAvatars,
      showTimestamps: showTimestamps,
      useDarkMode: useDarkMode,
      useSystemTheme: useSystemTheme,
      startWithNewChat: startWithNewChat,
      sendOnEnter: sendOnEnter,
      confirmDeleteConversation: confirmDeleteConversation,
      searchInMessages: searchInMessages,
      searchInBotMessages: searchInBotMessages,
      searchInUserMessages: searchInUserMessages,
      autoScrollToBottom: autoScrollToBottom,
      maxConversationsInHistory: maxConversationsInHistory,
    );
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();

    // Save the setting based on its type
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }

    // Update the state using a dynamic approach with copyWith
    switch (key) {
      case 'debugMode':
        state = state.copyWith(debugMode: value as bool);
        break;
      case 'showAvatars':
        state = state.copyWith(showAvatars: value as bool);
        break;
      case 'showTimestamps':
        state = state.copyWith(showTimestamps: value as bool);
        break;
      case 'useDarkMode':
        state = state.copyWith(useDarkMode: value as bool);
        break;
      case 'useSystemTheme':
        state = state.copyWith(useSystemTheme: value as bool);
        break;
      case 'startWithNewChat':
        state = state.copyWith(startWithNewChat: value as bool);
        break;
      case 'sendOnEnter':
        state = state.copyWith(sendOnEnter: value as bool);
        break;
      case 'confirmDeleteConversation':
        state = state.copyWith(confirmDeleteConversation: value as bool);
        break;
      case 'searchInMessages':
        state = state.copyWith(searchInMessages: value as bool);
        break;
      case 'searchInBotMessages':
        state = state.copyWith(searchInBotMessages: value as bool);
        break;
      case 'searchInUserMessages':
        state = state.copyWith(searchInUserMessages: value as bool);
        break;
      case 'autoScrollToBottom':
        state = state.copyWith(autoScrollToBottom: value as bool);
        break;
      case 'maxConversationsInHistory':
        state = state.copyWith(maxConversationsInHistory: value as int);
        break;
    }
  }

  // Specific toggle methods for convenience
  Future<void> toggleDebugMode() async {
    await updateSetting('debugMode', !state.debugMode);
  }

  Future<void> toggleShowAvatars() async {
    await updateSetting('showAvatars', !state.showAvatars);
  }

  Future<void> toggleShowTimestamps() async {
    await updateSetting('showTimestamps', !state.showTimestamps);
  }

  Future<void> toggleStartWithNewChat() async {
    await updateSetting('startWithNewChat', !state.startWithNewChat);
  }

  Future<void> toggleSearchInMessages() async {
    await updateSetting('searchInMessages', !state.searchInMessages);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
