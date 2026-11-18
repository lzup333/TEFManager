import 'dart:convert';

import 'package:flutter/services.dart';

/// Language options mirror `StringsResource.Language` in the Kotlin app.
enum AppLanguage { system, zhHans, en, ru }

extension AppLanguageX on AppLanguage {
  String get storageName => switch (this) {
        AppLanguage.system => 'System',
        AppLanguage.zhHans => 'ZhHans',
        AppLanguage.en => 'En',
        AppLanguage.ru => 'Ru',
      };

  String get label => switch (this) {
        AppLanguage.system => 'settings.followSystem',
        AppLanguage.zhHans => '简体中文',
        AppLanguage.en => 'English',
        AppLanguage.ru => 'Русский',
      };

  static AppLanguage parse(String? raw) {
    return switch (raw) {
      'ZhHans' => AppLanguage.zhHans,
      'En' => AppLanguage.en,
      'Ru' => AppLanguage.ru,
      _ => AppLanguage.system,
    };
  }
}

/// Lightweight JSON i18n. The resource files are the original TEFManager
/// string tables (`assets/i18n/*.json`), so wording stays identical.
class I18n {
  I18n._();

  static final I18n instance = I18n._();

  final Map<String, Map<String, String>> _bundles = {};
  String _code = 'zh';

  /// Keys introduced by the Flutter rewrite that are not present in the
  /// original Kotlin string tables. Kept here so the upstream JSON assets stay
  /// untouched and easy to regenerate.
  static const Map<String, Map<String, String>> _extras = {
    'zh': {
      'home.game.count': '个游戏',
      'home.game.launchFailed': '启动失败，请检查游戏是否已安装',
      'home.add.step.pick': '选择原版 APK 安装包',
      'home.add.step.patch': '自动注入 TEFLoader 并重新签名',
      'home.add.step.install': '安装修补后的 APK 并回到这里',
      'home.add.hint': '外部模式需要保持本应用在后台运行',
      'home.add.chooseApk': '选择 APK 并修补',
      'home.add.notReady': '原生修补流程尚未接入',
      'manager.install.opening': '打开包',
      'manager.install.copying': '复制文件',
      'manager.install.database': '更新数据库',
      'manager.install.dependency': '安装内联依赖',
      'manager.install.ready': '准备安装',
      'manager.delete.title': '删除 \${name}？',
      'manager.delete.body': '会同时删除包文件、图标与私有数据，此操作不可撤销。',
      'manager.install.installing': '正在安装…',
      'manager.install.result': '成功 \${ok} 个，失败 \${fail} 个',
      'manager.install.failDetail': '失败原因',
      'manager.installed.count': '已安装 \${count} 个',
      'manager.detail.basic': '基本信息',
      'manager.action.details': '详情',
      'manager.action.delete': '删除',
      'manager.loader.enabled': '已启用',
      'manager.loader.disabled': '未启用',
      'manager.import.empty': '没有选择文件',
      'manager.add': '导入组件',
      'manager.add.desc': '选择一个或多个 .tefpkg 组件包，管理器会自动识别类型并安装。',
      'manager.add.choose': '选择文件',
      'manager.tab.installed': '已安装',
      'manager.tab.repository': '模组仓库',
      'manager.empty.title': '暂无组件',
      'manager.empty.message': '点击右下角导入 .tefpkg 包',
      'manager.kind.module': '模块',
      'manager.kind.plugin': '插件',
      'manager.kind.loader': '加载器',
      'manager.kind.mod': 'Mod',
      'manager.store.empty': '没有可用的模组仓库',
      'manager.store.emptyDesc': '启用一个带仓库地址的 ModLoader 后即可浏览',
      'onboarding.install.statusFailed': '失败',
      'settings.about.reinstall': '重新安装内置组件',
      'settings.about.reinstalling': '正在安装内置组件…',
      'resource.action.up': '上移',
      'resource.action.down': '下移',
      'resource.action.select': '设为当前',
      'resource.action.deselect': '取消选择',
      'resource.limit': '语言包最多同时启用 \${count} 个',
      'resource.delete.title': '删除 \${name}？',
      'resource.delete.body': '会删除资源包文件与配置，此操作不可撤销。',
      'resource.installing': '正在安装资源包…',
      'resource.install.result': '成功 \${ok} 个，失败 \${fail} 个',
      'resource.empty': '暂无资源包',
      'resource.emptyDesc': '点击右下角导入资源包 ZIP',
      'settings.about.openSource': '开源声明',
      'oss.title': '开源声明',
      'oss.project': '本项目',
      'oss.projectDesc': 'TEFManager 以 AGPL-3.0 协议开源',
      'oss.projectText': 'TEFManager 是 TEFKernel 生态的官方图形化管理工具，完全开源。你可以自由查看、修改和分发本软件；任何衍生作品也必须以 AGPL-3.0 协议开源发布。',
      'oss.thirdParty': '第三方组件',
      'oss.thirdPartyDesc': '本应用随附或依赖的开源软件',
      'oss.viewLicenses': '查看完整依赖许可证',
      'oss.notice': '以上许可证文本随应用一同分发。Terraria 为 Re-Logic 公司的注册商标，本应用未获其官方授权，属于第三方社区工具。',
      'settings.logs': '日志',
      'settings.clearLogs': '清除日志',
      'settings.exportLogs': '导出日志',
      'settings.done': '完成',
      'onboarding.skip': '跳过',
      'onboarding.next': '下一步',
      'onboarding.finish': '开始使用',
      'loading': '正在启动…',
    },
    'en': {
      'home.game.count': 'games',
      'home.game.launchFailed': 'Launch failed. Is the game installed?',
      'home.add.step.pick': 'Pick the original game APK',
      'home.add.step.patch': 'TEFLoader is injected and the APK re-signed',
      'home.add.step.install': 'Install the patched APK and come back',
      'home.add.hint': 'External mode requires this app to stay in background',
      'home.add.chooseApk': 'Pick APK and patch',
      'home.add.notReady': 'Native patch flow is not wired up yet',
      'manager.install.opening': 'Opening package',
      'manager.install.copying': 'Copying files',
      'manager.install.database': 'Updating database',
      'manager.install.dependency': 'Installing inline dependency',
      'manager.install.ready': 'Ready',
      'manager.delete.title': 'Delete \${name}?',
      'manager.delete.body': 'The package, icon and private data will be removed. This cannot be undone.',
      'manager.install.installing': 'Installing…',
      'manager.install.result': '\${ok} succeeded, \${fail} failed',
      'manager.install.failDetail': 'Failure',
      'manager.installed.count': '\${count} installed',
      'manager.detail.basic': 'Basic information',
      'manager.action.details': 'Details',
      'manager.action.delete': 'Delete',
      'manager.loader.enabled': 'Enabled',
      'manager.loader.disabled': 'Disabled',
      'manager.import.empty': 'No files selected',
      'manager.add': 'Import component',
      'manager.add.desc': 'Pick one or more .tefpkg packages; the manager detects their type automatically.',
      'manager.add.choose': 'Choose files',
      'manager.tab.installed': 'Installed',
      'manager.tab.repository': 'Repository',
      'manager.empty.title': 'No components',
      'manager.empty.message': 'Use the button below to import a .tefpkg',
      'manager.kind.module': 'Modules',
      'manager.kind.plugin': 'Plugins',
      'manager.kind.loader': 'Loaders',
      'manager.kind.mod': 'Mods',
      'manager.store.empty': 'No mod repository available',
      'manager.store.emptyDesc': 'Enable a ModLoader with a repository URL first',
      'onboarding.install.statusFailed': 'Failed',
      'settings.about.reinstall': 'Reinstall bundled components',
      'settings.about.reinstalling': 'Installing bundled components…',
      'resource.action.up': 'Move up',
      'resource.action.down': 'Move down',
      'resource.action.select': 'Use this pack',
      'resource.action.deselect': 'Deselect',
      'resource.limit': 'At most \${count} language packs can be enabled',
      'resource.delete.title': 'Delete \${name}?',
      'resource.delete.body': 'The pack file and configuration will be removed. This cannot be undone.',
      'resource.installing': 'Installing resource packs…',
      'resource.install.result': '\${ok} succeeded, \${fail} failed',
      'resource.empty': 'No resource packs',
      'resource.emptyDesc': 'Use the button below to import a pack ZIP',
      'settings.about.openSource': 'Open source',
      'oss.title': 'Open source',
      'oss.project': 'This project',
      'oss.projectDesc': 'TEFManager is released under AGPL-3.0',
      'oss.projectText': 'TEFManager is the official graphical manager for the TEFKernel ecosystem and is fully open source. You may study, modify and redistribute it; derivative works must also be released under AGPL-3.0.',
      'oss.thirdParty': 'Third-party components',
      'oss.thirdPartyDesc': 'Open-source software bundled with or used by this app',
      'oss.viewLicenses': 'View full dependency licenses',
      'oss.notice': 'The license texts above are distributed with the app. Terraria is a trademark of Re-Logic; this is an unofficial community tool.',
      'settings.logs': 'Logs',
      'settings.clearLogs': 'Clear logs',
      'settings.exportLogs': 'Export logs',
      'settings.done': 'Done',
      'onboarding.skip': 'Skip',
      'onboarding.next': 'Next',
      'onboarding.finish': 'Get started',
      'loading': 'Starting…',
    },
    'ru': {
      'home.game.count': 'игр',
      'home.game.launchFailed': 'Не удалось запустить игру',
      'home.add.step.pick': 'Выберите оригинальный APK игры',
      'home.add.step.patch': 'TEFLoader внедряется, APK подписывается заново',
      'home.add.step.install': 'Установите пропатченный APK и вернитесь',
      'home.add.hint': 'Для внешнего режима приложение должно работать в фоне',
      'home.add.chooseApk': 'Выбрать APK и пропатчить',
      'home.add.notReady': 'Нативный патчер ещё не подключён',
      'manager.install.opening': 'Открытие пакета',
      'manager.install.copying': 'Копирование файлов',
      'manager.install.database': 'Обновление базы',
      'manager.install.dependency': 'Установка зависимости',
      'manager.install.ready': 'Готово',
      'manager.delete.title': 'Удалить \${name}?',
      'manager.delete.body': 'Пакет, значок и личные данные будут удалены безвозвратно.',
      'manager.install.installing': 'Установка…',
      'manager.install.result': 'Успешно: \${ok}, ошибок: \${fail}',
      'manager.install.failDetail': 'Ошибка',
      'manager.installed.count': 'Установлено: \${count}',
      'manager.detail.basic': 'Основное',
      'manager.action.details': 'Подробности',
      'manager.action.delete': 'Удалить',
      'manager.loader.enabled': 'Включён',
      'manager.loader.disabled': 'Выключен',
      'manager.import.empty': 'Файлы не выбраны',
      'manager.add': 'Импорт компонента',
      'manager.add.desc': 'Выберите один или несколько пакетов .tefpkg.',
      'manager.add.choose': 'Выбрать файлы',
      'manager.tab.installed': 'Установлено',
      'manager.tab.repository': 'Репозиторий',
      'manager.empty.title': 'Компонентов нет',
      'manager.empty.message': 'Импортируйте пакет .tefpkg',
      'manager.kind.module': 'Модули',
      'manager.kind.plugin': 'Плагины',
      'manager.kind.loader': 'Загрузчики',
      'manager.kind.mod': 'Моды',
      'manager.store.empty': 'Репозиторий недоступен',
      'manager.store.emptyDesc': 'Сначала включите ModLoader с адресом репозитория',
      'onboarding.install.statusFailed': 'Ошибка',
      'settings.about.reinstall': 'Переустановить встроенные компоненты',
      'settings.about.reinstalling': 'Установка встроенных компонентов…',
      'resource.action.up': 'Вверх',
      'resource.action.down': 'Вниз',
      'resource.action.select': 'Использовать',
      'resource.action.deselect': 'Снять выбор',
      'resource.limit': 'Можно включить не более \${count} языковых паков',
      'resource.delete.title': 'Удалить \${name}?',
      'resource.delete.body': 'Файл пака и его настройки будут удалены безвозвратно.',
      'resource.installing': 'Установка ресурспаков…',
      'resource.install.result': 'Успешно: \${ok}, ошибок: \${fail}',
      'resource.empty': 'Ресурспаков нет',
      'resource.emptyDesc': 'Импортируйте ZIP-пак',
      'settings.about.openSource': 'Открытый код',
      'oss.title': 'Открытый исходный код',
      'oss.project': 'Этот проект',
      'oss.projectDesc': 'TEFManager распространяется по AGPL-3.0',
      'oss.projectText': 'TEFManager — официальный графический менеджер экосистемы TEFKernel с полностью открытым кодом. Вы можете изучать, изменять и распространять его; производные работы также должны быть под AGPL-3.0.',
      'oss.thirdParty': 'Сторонние компоненты',
      'oss.thirdPartyDesc': 'Открытое ПО, входящее в приложение или используемое им',
      'oss.viewLicenses': 'Все лицензии зависимостей',
      'oss.notice': 'Тексты лицензий распространяются вместе с приложением. Terraria — товарный знак Re-Logic; это неофициальный инструмент сообщества.',
      'settings.logs': 'Журналы',
      'settings.clearLogs': 'Очистить',
      'settings.exportLogs': 'Экспорт',
      'settings.done': 'Готово',
      'onboarding.skip': 'Пропустить',
      'onboarding.next': 'Далее',
      'onboarding.finish': 'Начать',
      'loading': 'Запуск…',
    },
  };

  String get code => _code;

  static String normalizeLocale(String? locale) {
    final value = (locale ?? '').toLowerCase();
    if (value.startsWith('zh')) return 'zh';
    if (value.startsWith('ru')) return 'ru';
    if (value.startsWith('en')) return 'en';
    return 'zh';
  }

  Future<void> load(AppLanguage language, {String? systemLocale}) async {
    if (_bundles.isEmpty) {
      for (final code in const ['zh', 'en', 'ru']) {
        final raw = await rootBundle.loadString('assets/i18n/$code.json');
        final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
        _bundles[code] = map.map((key, value) => MapEntry(key, '$value'));
      }
    }
    _code = switch (language) {
      AppLanguage.zhHans => 'zh',
      AppLanguage.en => 'en',
      AppLanguage.ru => 'ru',
      AppLanguage.system => normalizeLocale(systemLocale),
    };
  }

  String t(String key, [Map<String, Object?>? vars]) {
    var text = _bundles[_code]?[key] ??
        _extras[_code]?[key] ??
        _bundles['en']?[key] ??
        _extras['en']?[key] ??
        key;
    if (vars != null && vars.isNotEmpty) {
      vars.forEach((name, value) {
        text = text.replaceAll('\${$name}', '${value ?? ''}');
      });
    }
    return text;
  }
}

/// Shorthand used across the UI.
String tr(String key, [Map<String, Object?>? vars]) => I18n.instance.t(key, vars);
