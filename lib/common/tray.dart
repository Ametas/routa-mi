import 'dart:io';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tray_manager/tray_manager.dart';

import 'app_localizations.dart';
import 'constant.dart';
import 'lite.dart';
import 'window.dart';

/// The Windows notification-area icon and menu (ported from FlClash).
class Tray {
  static Tray? _instance;

  Tray._internal();

  factory Tray() {
    _instance ??= Tray._internal();
    return _instance!;
  }

  Future<void> destroy() async {
    await trayManager.destroy();
  }

  static String iconFor({required bool isStart, required bool tunEnable}) {
    final index = !isStart ? 1 : (tunEnable ? 3 : 2);
    return 'assets/images/icon/status_$index.ico';
  }

  Future<void> update({required TrayState trayState}) async {
    await trayManager.setIcon(
      iconFor(isStart: trayState.isStart, tunEnable: trayState.tunEnable),
    );
    await trayManager.setToolTip(appName);
    final container = globalState.container;
    final commonAction = container.read(commonActionProvider.notifier);
    final systemAction = container.read(systemActionProvider.notifier);
    final setupAction = container.read(setupActionProvider.notifier);
    final l10n = currentAppLocalizations;
    final items = <MenuItem>[
      MenuItem(label: l10n.show, onClick: (_) => window?.show()),
      MenuItem(
        label: trayState.isStart ? l10n.stop : l10n.start,
        onClick: (_) => commonAction.updateStart(),
      ),
      MenuItem(
        label: l10n.restartCore,
        onClick: (_) =>
            container.read(coreActionProvider.notifier).restartCore(),
      ),
      MenuItem(label: l10n.liteMode, onClick: (_) => liteMode.enter()),
      MenuItem.separator(),
      for (final mode in Mode.values)
        MenuItem.checkbox(
          label: Intl.message(mode.name),
          checked: mode == trayState.mode,
          onClick: (_) => setupAction.changeMode(mode),
        ),
      MenuItem.separator(),
      if (trayState.isStart) ...[
        MenuItem.checkbox(
          label: l10n.tun,
          checked: trayState.tunEnable,
          onClick: (_) => systemAction.updateTun(),
        ),
        MenuItem.checkbox(
          label: l10n.systemProxy,
          checked: trayState.systemProxy,
          onClick: (_) => systemAction.updateSystemProxy(),
        ),
        MenuItem.separator(),
      ],
      MenuItem.checkbox(
        label: l10n.autoLaunch,
        checked: trayState.autoLaunch,
        onClick: (_) => systemAction.updateAutoLaunch(),
      ),
      MenuItem(
        label: l10n.copyEnvVar,
        onClick: (_) => Clipboard.setData(
          ClipboardData(
            text: '\$env:all_proxy="http://127.0.0.1:${trayState.port}"',
          ),
        ),
      ),
      MenuItem.separator(),
      MenuItem(label: l10n.exit, onClick: (_) => systemAction.handleExit()),
    ];
    await trayManager.setContextMenu(Menu(items: items));
  }
}

final tray = Platform.isWindows ? Tray() : null;
