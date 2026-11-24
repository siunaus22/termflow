import 'package:shared_preferences/shared_preferences.dart';

/// 本地持久化保存用户自定义的 SUPABASE_URL、SUPABASE_ANON_KEY 及 Material You 主题偏好
class AppConfigStore {
  AppConfigStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keySupabaseUrl = 'termflow_supabase_url';
  static const _keySupabaseAnonKey = 'termflow_supabase_anon_key';
  static const _keyThemeMode = 'termflow_theme_mode';
  static const _keyThemeSeed = 'termflow_theme_seed';
  static const _keyAutoSync = 'termflow_auto_sync';

  String get supabaseUrl => _prefs.getString(_keySupabaseUrl) ?? '';
  String get supabaseAnonKey => _prefs.getString(_keySupabaseAnonKey) ?? '';

  bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  Future<void> saveSupabaseConfig({
    required String url,
    required String anonKey,
  }) async {
    await _prefs.setString(_keySupabaseUrl, url.trim());
    await _prefs.setString(_keySupabaseAnonKey, anonKey.trim());
  }

  Future<void> clearSupabaseConfig() async {
    await _prefs.remove(_keySupabaseUrl);
    await _prefs.remove(_keySupabaseAnonKey);
  }

  /// 'system' | 'light' | 'dark'
  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'system';

  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_keyThemeMode, mode);

  /// Google Material You 主题种子色标识
  String get themeSeed => _prefs.getString(_keyThemeSeed) ?? 'google_blue';

  Future<void> setThemeSeed(String seedKey) =>
      _prefs.setString(_keyThemeSeed, seedKey);

  bool get autoSyncEnabled => _prefs.getBool(_keyAutoSync) ?? true;

  Future<void> setAutoSyncEnabled(bool enabled) =>
      _prefs.setBool(_keyAutoSync, enabled);
}
