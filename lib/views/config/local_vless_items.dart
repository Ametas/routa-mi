import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/local_vless.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings of the optional local VLESS inbound, laid out like the SOCKS
/// authentication: a switch under "Inbound" and a section of its own.

void _updateLocalVless(
  WidgetRef ref,
  LocalVlessProps Function(LocalVlessProps) update,
) {
  ref
      .read(networkSettingProvider.notifier)
      .update((state) => state.copyWith(localVless: update(state.localVless)));
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    context.showNotifier(context.appLocalizations.copySuccess);
  }
}

class LocalVlessItem extends ConsumerWidget {
  const LocalVlessItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      networkSettingProvider.select((state) => state.localVless.enable),
    );
    // Turning it on fills in the UUID (keepLocalProxyCredentials).
    return ListItem.switchItem(
      leading: const Icon(SurgeIcons.vpn),
      title: Text(appLocalizations.localVless),
      subtitle: Text(appLocalizations.localVlessDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) =>
            _updateLocalVless(ref, (state) => state.copyWith(enable: value)),
      ),
    );
  }
}

class LocalVlessPortItem extends ConsumerWidget {
  const LocalVlessPortItem({super.key});

  Future<void> _handleEdit(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final current = ref.read(networkSettingProvider).localVless.port;
    final value = await globalState.showCommonDialog<String>(
      context: context,
      child: InputDialog(
        title: appLocalizations.port,
        value: '$current',
        validator: (value) {
          final port = int.tryParse(value?.trim() ?? '');
          if (port == null) {
            return appLocalizations.numberTip(appLocalizations.port);
          }
          final error = LocalVless.portError(
            port,
            ref.read(patchClashConfigProvider),
          );
          if (error == null) return null;
          return port < LocalVless.minPort || port > LocalVless.maxPort
              ? error
              : appLocalizations.portConflictTip;
        },
      ),
    );
    final port = int.tryParse(value?.trim() ?? '');
    if (port == null) return;
    _updateLocalVless(ref, (state) => state.copyWith(port: port));
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final port = ref.watch(
      networkSettingProvider.select((state) => state.localVless.port),
    );
    final allowLan = ref.watch(
      patchClashConfigProvider.select((state) => state.allowLan),
    );
    return ListItem(
      leading: const Icon(SurgeIcons.selector),
      title: Text(appLocalizations.port),
      subtitle: Text(
        allowLan
            ? '0.0.0.0:$port · ${appLocalizations.allowLan}'
            : '127.0.0.1:$port',
      ),
      onTap: () => _handleEdit(context, ref),
    );
  }
}

class LocalVlessUuidItem extends ConsumerStatefulWidget {
  const LocalVlessUuidItem({super.key});

  @override
  ConsumerState<LocalVlessUuidItem> createState() => _LocalVlessUuidItemState();
}

class _LocalVlessUuidItemState extends ConsumerState<LocalVlessUuidItem> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final uuid = ref.watch(
      networkSettingProvider.select((state) => state.localVless.uuid),
    );
    return ListItem(
      leading: const Icon(SurgeIcons.vpnKey),
      title: const Text('UUID'),
      subtitle: Text(
        _visible ? uuid : '•' * 12,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: _visible ? appLocalizations.hide : appLocalizations.show,
            child: SoftOsIconButton(
              icon: _visible ? SurgeIcons.visibilityOff : SurgeIcons.visibility,
              onPressed: () => setState(() => _visible = !_visible),
            ),
          ),
          SoftOsIconButton(
            icon: SurgeIcons.copy,
            onPressed: () => _copy(context, uuid),
          ),
        ],
      ),
    );
  }
}

class LocalVlessLinkItem extends ConsumerWidget {
  const LocalVlessLinkItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final vless = ref.watch(
      networkSettingProvider.select((state) => state.localVless),
    );
    return ListItem(
      leading: const Icon(SurgeIcons.copy),
      title: Text(appLocalizations.copyLink),
      subtitle: Text(appLocalizations.localVlessLinkDesc),
      onTap: () => _copy(context, vless.shareLink()),
    );
  }
}

class LocalVlessRegenerateItem extends ConsumerWidget {
  const LocalVlessRegenerateItem({super.key});

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await globalState.showMessage(
      context: context,
      title: appLocalizations.regenerateUuid,
      message: TextSpan(text: appLocalizations.regenerateUuidDesc),
    );
    if (confirmed != true) return;
    _updateLocalVless(
      ref,
      (state) => state.copyWith(uuid: LocalVless.generateUuid()),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    return ListItem(
      leading: const Icon(SurgeIcons.refresh),
      title: Text(appLocalizations.regenerateUuid),
      subtitle: Text(appLocalizations.regenerateUuidDesc),
      onTap: () => _handleTap(context, ref),
    );
  }
}
