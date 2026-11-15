import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// The Windows shell around the app: window events, tray, global hotkeys and
/// the system proxy. Ported from FlClash's window/tray/hotkey/proxy managers.
class DesktopManager extends StatelessWidget {
  final Widget child;

  const DesktopManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return _WindowManager(
      child: _TrayManager(
        child: _HotKeyManager(child: _SystemProxyManager(child: child)),
      ),
    );
  }
}

class _WindowManager extends ConsumerStatefulWidget {
  final Widget child;

  const _WindowManager({required this.child});

  @override
  ConsumerState<_WindowManager> createState() => _WindowManagerState();
}

class _WindowManagerState extends ConsumerState<_WindowManager>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      appSettingProvider.select(
        (state) => (state.autoLaunch, state.autoLaunchToTray),
      ),
      (prev, next) {
        if (prev != next) {
          debouncer.call(FunctionTag.autoLaunch, () {
            autoLaunch?.updateStatus(next.$1, toTray: next.$2);
          });
        }
      },
    );
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    await ref.read(systemActionProvider.notifier).handleBackOrExit();
    super.onWindowClose();
  }

  @override
  void onWindowFocus() {
    super.onWindowFocus();
    render?.resume();
  }

  @override
  void onWindowMoved() {
    super.onWindowMoved();
    windowManager.getPosition().then((offset) {
      ref
          .read(windowSettingProvider.notifier)
          .update((state) => state.copyWith(top: offset.dy, left: offset.dx));
    });
  }

  @override
  Future<void> onWindowResized() async {
    super.onWindowResized();
    final size = await windowManager.getSize();
    ref
        .read(windowSettingProvider.notifier)
        .update(
          // A fresh WindowProps rather than copyWith(height:), which the
          // typography contract reserves for text styles.
          (state) => WindowProps(
            width: size.width,
            height: size.height,
            top: state.top,
            left: state.left,
          ),
        );
  }

  @override
  void onWindowMinimize() {
    ref.read(storeActionProvider.notifier).savePreferencesDebounce();
    render?.pause();
    super.onWindowMinimize();
  }

  @override
  void onWindowRestore() {
    render?.resume();
    super.onWindowRestore();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TrayManager extends ConsumerStatefulWidget {
  final Widget child;

  const _TrayManager({required this.child});

  @override
  ConsumerState<_TrayManager> createState() => _TrayManagerState();
}

class _TrayManagerState extends ConsumerState<_TrayManager> with TrayListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    ref.listenManual(trayStateProvider, (prev, next) {
      if (prev != next) {
        tray?.update(trayState: next);
      }
    }, fireImmediately: true);
  }

  @override
  void onTrayIconMouseDown() {
    window?.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    render?.active();
    super.onTrayMenuItemClick(menuItem);
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _CloseWindowIntent extends Intent {
  const _CloseWindowIntent();
}

class _HotKeyManager extends ConsumerStatefulWidget {
  final Widget child;

  const _HotKeyManager({required this.child});

  @override
  ConsumerState<_HotKeyManager> createState() => _HotKeyManagerState();
}

class _HotKeyManagerState extends ConsumerState<_HotKeyManager> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(hotKeyActionsProvider, (prev, next) {
      if (!hotKeyActionListEquality.equals(prev, next)) {
        _updateHotKeys(next);
      }
    }, fireImmediately: true);
  }

  Future<void> _toggleWindow() async {
    if (await window?.isVisible ?? false) {
      await window?.hide();
    } else {
      await window?.show();
    }
  }

  void _handle(HotAction action) {
    final container = globalState.container;
    final commonAction = container.read(commonActionProvider.notifier);
    final systemAction = container.read(systemActionProvider.notifier);
    switch (action) {
      case HotAction.mode:
        commonAction.updateMode();
      case HotAction.start:
        commonAction.updateStart();
      case HotAction.view:
        _toggleWindow();
      case HotAction.proxy:
        systemAction.updateSystemProxy();
      case HotAction.tun:
        systemAction.updateTun();
    }
  }

  static HotKeyModifier _modifier(KeyboardModifier modifier) {
    return switch (modifier) {
      KeyboardModifier.alt => HotKeyModifier.alt,
      KeyboardModifier.capsLock => HotKeyModifier.capsLock,
      KeyboardModifier.control => HotKeyModifier.control,
      KeyboardModifier.fn => HotKeyModifier.fn,
      KeyboardModifier.meta => HotKeyModifier.meta,
      KeyboardModifier.shift => HotKeyModifier.shift,
    };
  }

  Future<void> _updateHotKeys(List<HotKeyAction> actions) async {
    await hotKeyManager.unregisterAll();
    await Future.wait(
      actions
          .where((action) => action.key != null && action.modifiers.isNotEmpty)
          .map(
            (action) => hotKeyManager.register(
              HotKey(
                key: PhysicalKeyboardKey(action.key!),
                modifiers: action.modifiers.map(_modifier).toList(),
              ),
              keyDownHandler: (_) => _handle(action.action),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyW, control: true):
            _CloseWindowIntent(),
      },
      child: Actions(
        actions: {
          _CloseWindowIntent: CallbackAction<_CloseWindowIntent>(
            onInvoke: (_) => globalState.container
                .read(systemActionProvider.notifier)
                .handleBackOrExit(),
          ),
        },
        child: widget.child,
      ),
    );
  }
}

class _SystemProxyManager extends ConsumerStatefulWidget {
  final Widget child;

  const _SystemProxyManager({required this.child});

  @override
  ConsumerState<_SystemProxyManager> createState() =>
      _SystemProxyManagerState();
}

class _SystemProxyManagerState extends ConsumerState<_SystemProxyManager> {
  Future<void> _pending = Future.value();

  Future<void> _apply(SystemProxyState state) async {
    final ok = state.enable
        ? await proxy?.startProxy(state.port, state.bypassDomain)
        : await proxy?.stopProxy();
    if (ok == false) {
      commonPrint.log('update system proxy failed', logLevel: LogLevel.warning);
    }
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(systemProxyStateProvider, (prev, next) {
      if (prev != next) {
        _pending = _pending.then((_) => _apply(next)).catchError((Object e) {
          commonPrint.log(
            'update system proxy failed: $e',
            logLevel: LogLevel.warning,
          );
        });
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
