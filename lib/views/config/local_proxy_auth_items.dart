import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/local_proxy_auth.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inbound settings of the local proxy port's credentials (layout follows
/// FlClash: a switch under "Inbound" and a section of its own when on).

void _updateAuthentication(
  WidgetRef ref,
  AuthenticationProps Function(AuthenticationProps) update,
) {
  ref
      .read(networkSettingProvider.notifier)
      .update(
        (state) => state.copyWith(authentication: update(state.authentication)),
      );
}

Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    context.showNotifier(context.appLocalizations.copySuccess);
  }
}

class AuthenticationItem extends ConsumerWidget {
  const AuthenticationItem({super.key});

  Future<void> _handleChanged(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    if (!value) {
      final appLocalizations = context.appLocalizations;
      final confirmed = await globalState.showMessage(
        context: context,
        title: appLocalizations.authentication,
        message: TextSpan(text: appLocalizations.authenticationOffWarning),
        confirmText: appLocalizations.disable,
      );
      if (confirmed != true) return;
    }
    // Turning it on fills in credentials (keepLocalProxyCredentials).
    _updateAuthentication(ref, (state) => state.copyWith(enable: value));
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final enable = ref.watch(
      networkSettingProvider.select((state) => state.authentication.enable),
    );
    return ListItem.switchItem(
      leading: const Icon(SurgeIcons.vpnKey),
      title: Text(appLocalizations.authentication),
      subtitle: Text(appLocalizations.authenticationDesc),
      delegate: SwitchDelegate(
        value: enable,
        onChanged: (value) => _handleChanged(context, ref, value),
      ),
    );
  }
}

class AuthenticationAccountItem extends ConsumerWidget {
  const AuthenticationAccountItem({super.key});

  Future<void> _handleEdit(
    BuildContext context,
    WidgetRef ref,
    String username,
  ) async {
    final appLocalizations = context.appLocalizations;
    final value = await globalState.showCommonDialog<String>(
      context: context,
      child: InputDialog(
        title: appLocalizations.account,
        value: username,
        validator: (value) => _validate(value, appLocalizations),
      ),
    );
    if (value == null) return;
    _updateAuthentication(
      ref,
      (state) => state.copyWith(username: value.trim()),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final username = ref.watch(
      networkSettingProvider.select((state) => state.authentication.username),
    );
    return ListItem(
      leading: const Icon(SurgeIcons.account),
      title: Text(appLocalizations.account),
      subtitle: Text(username, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: SoftOsIconButton(
        icon: SurgeIcons.copy,
        onPressed: () => _copy(context, username),
      ),
      onTap: () => _handleEdit(context, ref, username),
    );
  }
}

class AuthenticationPasswordItem extends ConsumerStatefulWidget {
  const AuthenticationPasswordItem({super.key});

  @override
  ConsumerState<AuthenticationPasswordItem> createState() =>
      _AuthenticationPasswordItemState();
}

class _AuthenticationPasswordItemState
    extends ConsumerState<AuthenticationPasswordItem> {
  bool _visible = false;

  Future<void> _handleEdit(String password) async {
    final appLocalizations = context.appLocalizations;
    final value = await globalState.showCommonDialog<String>(
      context: context,
      child: InputDialog(
        title: appLocalizations.password,
        value: password,
        validator: (value) => _validate(value, appLocalizations),
      ),
    );
    if (value == null) return;
    _updateAuthentication(
      ref,
      (state) => state.copyWith(password: value.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final password = ref.watch(
      networkSettingProvider.select((state) => state.authentication.password),
    );
    return ListItem(
      leading: const Icon(SurgeIcons.password),
      title: Text(appLocalizations.password),
      subtitle: Text(
        _visible ? password : '•' * 12,
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
            onPressed: () => _copy(context, password),
          ),
        ],
      ),
      onTap: () => _handleEdit(password),
    );
  }
}

class AuthenticationRegenerateItem extends ConsumerWidget {
  const AuthenticationRegenerateItem({super.key});

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await globalState.showMessage(
      context: context,
      title: appLocalizations.regenerateCredentials,
      message: TextSpan(text: appLocalizations.regenerateCredentialsDesc),
    );
    if (confirmed != true) return;
    final generated = LocalProxyAuth.generate();
    _updateAuthentication(
      ref,
      (state) => state.copyWith(
        username: generated.username,
        password: generated.password,
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    return ListItem(
      leading: const Icon(SurgeIcons.refresh),
      title: Text(appLocalizations.regenerateCredentials),
      subtitle: Text(appLocalizations.regenerateCredentialsDesc),
      onTap: () => _handleTap(context, ref),
    );
  }
}

String? _validate(String? value, AppLocalizations appLocalizations) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return appLocalizations.emptyTip(appLocalizations.value);
  }
  return LocalProxyAuth.allowedPattern.hasMatch(text)
      ? null
      : appLocalizations.credentialCharactersTip;
}
