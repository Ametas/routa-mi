import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/config.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// The Windows app window (ported from FlClash). RoutaMi keeps the native
/// title bar and opens phone-sized: the interface is designed for a phone.
class Window {
  static Window? _instance;

  Window._internal();

  factory Window() {
    _instance ??= Window._internal();
    return _instance!;
  }

  static const defaultSize = Size(1100, 720);

  Future<void> init(WindowProps props) async {
    if (!await singleInstanceLock.acquire()) {
      exit(0);
    }
    for (final scheme in const ['clash', 'clashmeta', 'flclash', 'routami']) {
      protocol.register(scheme);
    }
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: props.width == 0 || props.height == 0 ? defaultSize : props.size,
      minimumSize: const Size(400, 600),
      title: appName,
    );
    await _restorePosition(props);
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
    });
  }

  Future<void> _restorePosition(WindowProps props) async {
    final left = props.left ?? 0;
    final top = props.top ?? 0;
    if (left == 0 && top == 0) {
      await windowManager.setAlignment(Alignment.center);
      return;
    }
    final displays = await screenRetriever.getAllDisplays();
    final visible = displays.any((display) {
      final bounds = Rect.fromLTWH(
        display.visiblePosition?.dx ?? 0,
        display.visiblePosition?.dy ?? 0,
        display.size.width,
        display.size.height,
      );
      return bounds.contains(Offset(left, top)) ||
          bounds.contains(Offset(left + props.width, top + props.height));
    });
    if (visible) {
      await windowManager.setPosition(Offset(left, top));
    } else {
      await windowManager.setAlignment(Alignment.center);
    }
  }

  Future<void> show() async {
    render?.resume();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
  }

  Future<bool> get isVisible => windowManager.isVisible();

  Future<void> close() async {
    await windowManager.close();
  }

  void forceExit() {
    exit(0);
  }

  Future<void> hide() async {
    render?.pause();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }
}

final window = Platform.isWindows ? Window() : null;
