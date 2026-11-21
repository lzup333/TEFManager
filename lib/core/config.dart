import 'dart:convert';
import 'dart:io';

import 'i18n.dart';

/// Theme mode names match the Kotlin enum so existing `app_config.json`
/// files keep working.
enum AppThemeMode { light, dark, auto, system }

extension AppThemeModeX on AppThemeMode {
  String get storageName => switch (this) {
    AppThemeMode.light => 'LIGHT',
    AppThemeMode.dark => 'DARK',
    AppThemeMode.auto => 'AUTO',
    AppThemeMode.system => 'SYSTEM',
  };

  String get labelKey => switch (this) {
    AppThemeMode.light => 'settings.appearance.lightTheme',
    AppThemeMode.dark => 'settings.appearance.darkTheme',
    AppThemeMode.auto => 'settings.appearance.autoTheme',
    AppThemeMode.system => 'settings.followSystem',
  };

  static AppThemeMode parse(String? raw) => switch (raw) {
    'LIGHT' => AppThemeMode.light,
    'DARK' => AppThemeMode.dark,
    'AUTO' => AppThemeMode.auto,
    _ => AppThemeMode.system,
  };
}

class AppConfig {
  AppConfig({
    this.initialized = false,
    this.kernelVersion = '1.0.0',
    this.language = AppLanguage.system,
    this.themeMode = AppThemeMode.system,
    this.themeSeedColor = 0xFF2196F3,
    this.fontSizeScale = 1.0,
    this.autoUpdate = true,
    this.dynamicColor = true,
    this.kernelLogEnabled = true,
    this.softwareLogEnabled = true,
    this.autoCleanLogs = true,
    this.autoCleanTime = 60,
    this.maxAppLogFiles = 10,
    this.maxAppLogSizeMB = 5,
    this.modSupportEnabled = true,
    this.redirectSavesEnabled = false,
    this.backgroundImage = '',
    this.backgroundDim = 0.25,
  });

  bool initialized;
  String kernelVersion;
  AppLanguage language;
  AppThemeMode themeMode;
  int themeSeedColor;
  double fontSizeScale;
  bool autoUpdate;
  bool dynamicColor;
  bool kernelLogEnabled;
  bool softwareLogEnabled;
  bool autoCleanLogs;
  int autoCleanTime;
  int maxAppLogFiles;
  int maxAppLogSizeMB;
  bool modSupportEnabled;
  bool redirectSavesEnabled;

  /// File name under `<files>/backgrounds/`, or an absolute path.
  String backgroundImage;

  /// 背景遮罩不透明度 0.0 ~ 0.8。
  double backgroundDim;

  Map<String, dynamic> toJson() => {
    'initialized': initialized,
    'kernelVersion': kernelVersion,
    'language': language.storageName,
    'themeMode': themeMode.storageName,
    'themeSeedColor': themeSeedColor,
    'fontSizeScale': fontSizeScale,
    'autoUpdate': autoUpdate,
    'dynamicColor': dynamicColor,
    'kernelLogEnabled': kernelLogEnabled,
    'softwareLogEnabled': softwareLogEnabled,
    'autoCleanLogs': autoCleanLogs,
    'autoCleanTime': autoCleanTime,
    'maxAppLogFiles': maxAppLogFiles,
    'maxAppLogSizeMB': maxAppLogSizeMB,
    'modSupportEnabled': modSupportEnabled,
    'redirectSavesEnabled': redirectSavesEnabled,
    'backgroundImage': backgroundImage,
    'backgroundDim': backgroundDim,
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) => v is num
        ? v.toInt()
        : (v is String ? int.tryParse(v) ?? fallback : fallback);
    double asDouble(dynamic v, double fallback) => v is num
        ? v.toDouble()
        : (v is String ? double.tryParse(v) ?? fallback : fallback);
    bool asBool(dynamic v, bool fallback) => v is bool ? v : fallback;

    return AppConfig(
      initialized: asBool(json['initialized'], false),
      kernelVersion: json['kernelVersion']?.toString() ?? '1.0.0',
      language: AppLanguageX.parse(json['language']?.toString()),
      themeMode: AppThemeModeX.parse(json['themeMode']?.toString()),
      // The Kotlin config stores ULong; Dart reads it as int.
      themeSeedColor: asInt(json['themeSeedColor'], 0xFF2196F3),
      fontSizeScale: asDouble(json['fontSizeScale'], 1.0).clamp(0.5, 2.0),
      autoUpdate: asBool(json['autoUpdate'], true),
      dynamicColor: asBool(json['dynamicColor'], true),
      kernelLogEnabled: asBool(json['kernelLogEnabled'], true),
      softwareLogEnabled: asBool(json['softwareLogEnabled'], true),
      autoCleanLogs: asBool(json['autoCleanLogs'], true),
      autoCleanTime: asInt(json['autoCleanTime'], 60),
      maxAppLogFiles: asInt(json['maxAppLogFiles'], 10),
      maxAppLogSizeMB: asInt(json['maxAppLogSizeMB'], 5),
      modSupportEnabled: asBool(json['modSupportEnabled'], true),
      redirectSavesEnabled: asBool(json['redirectSavesEnabled'], false),
      backgroundImage: json['backgroundImage']?.toString() ?? '',
      backgroundDim: asDouble(json['backgroundDim'], 0.25).clamp(0.0, 0.8),
    );
  }
}

/// Reads/writes `app_config.json` in the manager's external files dir.
class ConfigStore {
  ConfigStore(this.file);

  final File file;

  Future<AppConfig> load() async {
    try {
      if (!await file.exists()) {
        final config = AppConfig();
        await save(config);
        return config;
      }
      final raw = await file.readAsString();
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return AppConfig.fromJson(map);
    } catch (_) {
      return AppConfig();
    }
  }

  Future<void> save(AppConfig config) async {
    try {
      await file.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(config.toJson()));
    } catch (_) {
      // Config persistence is best-effort, matching the Kotlin behaviour.
    }
  }
}
