import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/common/profile_link.dart';
import 'package:fl_clash/enum/profile_core.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/profiles/profile_core_widgets.dart';
import 'package:fl_clash/views/profiles/profile_select.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How a profile is added (design 3.1 "RoutaMi Add Profile").
enum AddProfileMethod { link, qr, file }

/// Update intervals offered as chips.
const addProfileIntervals = <Duration>[
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(days: 1),
  Duration(days: 3),
];

String addProfileIntervalLabel(AppLocalizations l10n, Duration interval) =>
    interval.inHours % 24 == 0 && interval.inHours >= 48
    ? l10n.daysShort(interval.inDays)
    : l10n.hoursShort(interval.inHours);

/// Opens the "New profile" sheet over the whole app.
Future<void> showAddProfileSheet(
  BuildContext context, {
  AddProfileMethod method = AddProfileMethod.link,
  String? url,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(AddProfileRoute(method: method, url: url));
}

class AddProfileRoute extends PageRoute<void> {
  AddProfileRoute({this.method = AddProfileMethod.link, this.url});

  final AddProfileMethod method;
  final String? url;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor =>
      SurgePalette.scrim.withValues(alpha: SurgeAlpha.a62);

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => SurgeMotion.sheetEnter;

  @override
  Duration get reverseTransitionDuration => SurgeMotion.sheetExit;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => AddProfileSheet(method: method, url: url);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AddProfileSheet.asDialog(MediaQuery.sizeOf(context).width)) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: SurgeMotion.enterCurve,
        reverseCurve: SurgeMotion.exitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(
            begin: AddProfileSheet.dialogStartScale,
            end: 1.0,
          ).animate(curved),
          child: child,
        ),
      );
    }
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: SurgeMotion.enterCurve,
          reverseCurve: SurgeMotion.exitCurve,
        ),
      ),
      child: child,
    );
  }
}

enum _Phase { edit, loading, done }

class AddProfileSheet extends ConsumerStatefulWidget {
  const AddProfileSheet({
    super.key,
    this.method = AddProfileMethod.link,
    this.url,
  });

  static const double radius = 28;
  static const double maxHeightFactor = 0.9;
  static const double grabWidth = 40;
  static const double grabHeight = 4;

  /// Windows at least this wide show the sheet as a centred dialog.
  static const double dialogMinWindowWidth = 900;
  static const double dialogWidth = 520;
  static const double dialogStartScale = 0.96;

  static bool asDialog(double windowWidth) =>
      windowWidth >= dialogMinWindowWidth;

  final AddProfileMethod method;
  final String? url;

  @override
  ConsumerState<AddProfileSheet> createState() => _AddProfileSheetState();
}

class _AddProfileSheetState extends ConsumerState<AddProfileSheet> {
  late AddProfileMethod _method = widget.method;
  late final _url = TextEditingController(text: widget.url ?? '');
  final _name = TextEditingController();
  ProfileCore _core = ProfileCore.mihomo;
  bool _autoUpdate = true;
  Duration _interval = defaultUpdateDuration;
  ({String name, Uint8List bytes})? _file;
  _Phase _phase = _Phase.edit;
  String? _error;
  Profile? _added;
  bool _wasFirst = false;

  ProfileLink get _link => parseProfileLink(_url.text);

  @override
  void initState() {
    super.initState();
    _takeName();
  }

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  /// A clash:// link may carry a name; it fills an empty name field.
  void _takeName() {
    final name = _link.name;
    if (name.isNotEmpty && _name.text.isEmpty) _name.text = name;
  }

  void _setUrl(String value) {
    _url.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _onUrlChanged();
  }

  void _onUrlChanged() {
    _takeName();
    setState(() => _error = null);
  }

  Future<void> _paste() async {
    // Read on request only: Android tells the user whenever the clipboard
    // is read, so the sheet does not peek at it when it opens.
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    _setUrl(text);
  }

  Future<void> _scanCamera() async {
    final url = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScanPage()));
    if (url == null || !mounted) return;
    setState(() => _method = AddProfileMethod.link);
    _setUrl(url);
  }

  Future<void> _scanImage() async {
    try {
      final url = await picker.pickerConfigQRCode();
      if (url == null || !mounted) return;
      setState(() => _method = AddProfileMethod.link);
      _setUrl(url);
    } catch (error) {
      if (mounted) context.showNotifier(error.toString());
    }
  }

  Future<void> _pickFile() async {
    final file = await globalState.safeRun(picker.pickerFile);
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;
    setState(() {
      _file = (name: file.name, bytes: bytes);
      _error = null;
    });
  }

  bool get _canSubmit => switch (_method) {
    AddProfileMethod.link => _link.isValid,
    AddProfileMethod.file => _file != null,
    AddProfileMethod.qr => false,
  };

  String _suggestedName() => switch (_method) {
    AddProfileMethod.file =>
      _file?.name.replaceFirst(RegExp(r'\.(ya?ml|json)$'), '') ?? '',
    _ => _link.name.isNotEmpty ? _link.name : _link.host,
  };

  Future<void> _submit() async {
    if (!_canSubmit || _phase == _Phase.loading) return;
    final action = ref.read(profilesActionProvider.notifier);
    final typed = _name.text.trim();
    final label = typed.isNotEmpty ? typed : _suggestedName();
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final Profile profile;
      if (_method == AddProfileMethod.file) {
        final file = _file!;
        profile = await action.withSourceCore(
          () => Profile.normal(
            label: label,
          ).copyWith(core: _core).saveFile(file.bytes),
        );
      } else {
        profile = await action.withSourceCore(
          Profile.normal(url: _link.url, label: label)
              .copyWith(
                autoUpdate: _autoUpdate,
                autoUpdateDuration: _interval,
                core: _core,
              )
              .update,
        );
      }
      if (!mounted) return;
      _wasFirst = ref.read(currentProfileIdProvider) == null;
      action.putProfile(profile);
      setState(() {
        _added = profile;
        _phase = _Phase.done;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.edit;
        _error = error.toString();
      });
    }
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final media = MediaQuery.of(context);
    final done = _phase == _Phase.done;
    // A wide window gets a centred dialog (design artifact "RoutaMi for
    // Windows"); phones keep the sheet.
    final dialog = AddProfileSheet.asDialog(media.size.width);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: dialog ? Alignment.center : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialog ? AddProfileSheet.dialogWidth : double.infinity,
            maxHeight:
                (media.size.height - media.viewInsets.bottom) *
                AddProfileSheet.maxHeightFactor,
          ),
          child: Material(
            color: surge.elevatedCard,
            shape: RoundedRectangleBorder(
              borderRadius: dialog
                  ? BorderRadius.circular(AddProfileSheet.radius)
                  : const BorderRadius.vertical(
                      top: Radius.circular(AddProfileSheet.radius),
                    ),
              side: BorderSide(color: surge.separator),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dialog)
                    const SizedBox(height: SurgeSpace.m)
                  else ...[
                    const SizedBox(height: SurgeSpace.s + SurgeSpace.xxs),
                    Center(
                      child: Container(
                        width: AddProfileSheet.grabWidth,
                        height: AddProfileSheet.grabHeight,
                        decoration: BoxDecoration(
                          color: surge.separator,
                          borderRadius: BorderRadius.circular(
                            surge.radii.button,
                          ),
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SurgeSpace.xl,
                      SurgeSpace.s,
                      SurgeSpace.l,
                      SurgeSpace.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            done ? l10n.profileAdded : l10n.newProfile,
                            style: context.typography.sheetTitle.copyWith(
                              color: surge.textPrimary,
                            ),
                          ),
                        ),
                        ProxyRoundAction(
                          icon: SurgeIcons.close,
                          tooltip: l10n.close,
                          onPressed: _close,
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        SurgeSpace.xl,
                        SurgeSpace.s,
                        SurgeSpace.xl,
                        SurgeSpace.m,
                      ),
                      child: AnimatedSize(
                        duration: SurgeMotion.container,
                        curve: SurgeMotion.stateCurve,
                        alignment: Alignment.topCenter,
                        child: done ? _doneBody(context) : _editBody(context),
                      ),
                    ),
                  ),
                  if (_method != AddProfileMethod.qr || done)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: surge.separator)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          SurgeSpace.xl,
                          SurgeSpace.m,
                          SurgeSpace.xl,
                          SurgeSpace.l,
                        ),
                        child: done ? _doneActions(context) : _submitButton(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _submitButton() {
    final l10n = context.appLocalizations;
    final loading = _phase == _Phase.loading;
    return OutlinePillButton(
      key: const ValueKey('add-profile-submit'),
      label: loading ? l10n.loadingProfile : l10n.add,
      accent: true,
      busy: loading,
      onPressed: _canSubmit ? _submit : null,
    );
  }

  Widget _editBody(BuildContext context) {
    final l10n = context.appLocalizations;
    return Column(
      key: ValueKey(_method),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurgeSegmentedControl<AddProfileMethod>(
          value: _method,
          onChanged: (method) => setState(() {
            _method = method;
            _error = null;
          }),
          items: [
            SurgeSegmentedItem(
              value: AddProfileMethod.link,
              label: l10n.url,
              icon: SurgeIcons.link,
            ),
            SurgeSegmentedItem(
              value: AddProfileMethod.qr,
              label: l10n.qrcode,
              icon: SurgeIcons.qrCode,
            ),
            SurgeSegmentedItem(
              value: AddProfileMethod.file,
              label: l10n.file,
              icon: SurgeIcons.file,
            ),
          ],
        ),
        const SizedBox(height: SurgeSpace.l),
        ...switch (_method) {
          AddProfileMethod.link => _linkPane(context),
          AddProfileMethod.qr => _qrPane(context),
          AddProfileMethod.file => _filePane(context),
        },
      ],
    );
  }

  List<Widget> _linkPane(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final link = _link;
    final bad = switch (link.kind) {
      ProfileLinkKind.node ||
      ProfileLinkKind.clashWithoutUrl ||
      ProfileLinkKind.invalid => true,
      _ => false,
    };
    final (IconData icon, Color color, String text) = switch (link.kind) {
      ProfileLinkKind.empty => (
        SurgeIcons.info,
        surge.textSecondary,
        l10n.linkHint,
      ),
      ProfileLinkKind.subscription => (
        SurgeIcons.confirm,
        surge.green,
        [
          l10n.linkSubscription(link.host),
          if (link.plainHttp) l10n.linkPlainHttp,
        ].join(' · '),
      ),
      ProfileLinkKind.clash => (
        SurgeIcons.confirm,
        surge.green,
        [
          l10n.linkClash(link.host),
          if (link.plainHttp) l10n.linkPlainHttp,
        ].join(' · '),
      ),
      ProfileLinkKind.node => (SurgeIcons.warning, surge.red, l10n.linkNode),
      ProfileLinkKind.clashWithoutUrl => (
        SurgeIcons.warning,
        surge.red,
        l10n.linkClashNoUrl,
      ),
      ProfileLinkKind.invalid => (
        SurgeIcons.warning,
        surge.red,
        l10n.linkInvalid,
      ),
    };
    return [
      SurgeField(
        label: l10n.subscriptionLink,
        child: TextField(
          key: const ValueKey('add-profile-url'),
          controller: _url,
          autofocus: widget.url == null,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => _onUrlChanged(),
          onSubmitted: (_) => _submit(),
          style: context.typography.technical.copyWith(
            color: surge.textPrimary,
          ),
          decoration: surgeInputDecoration(
            context,
            hintText: 'https://',
            suffixIcon: Padding(
              padding: const EdgeInsets.all(SurgeSpace.xs),
              child: OutlinePillButton(
                label: l10n.paste,
                icon: SurgeIcons.paste,
                compact: true,
                onPressed: _paste,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: SurgeSpace.s),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: SurgeIconSize.inline, color: color),
          const SizedBox(width: SurgeSpace.xs + SurgeSpace.xxs),
          Expanded(
            child: Text(
              text,
              style: context.typography.supporting.copyWith(
                color: bad || link.isValid ? color : surge.textSecondary,
              ),
            ),
          ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: SurgeSpace.m),
        _ErrorCard(message: _error!, onRetry: _submit),
      ],
      if (link.isValid) ...[
        const SizedBox(height: SurgeSpace.l),
        ..._details(context, autoUpdate: true),
      ],
    ];
  }

  List<Widget> _qrPane(BuildContext context) {
    final l10n = context.appLocalizations;
    return [
      _Viewfinder(
        hint: l10n.qrCameraHint,
        onTap: system.isDesktop ? _scanImage : _scanCamera,
      ),
      const SizedBox(height: SurgeSpace.m),
      Wrap(
        spacing: SurgeSpace.s,
        runSpacing: SurgeSpace.s,
        children: [
          if (!system.isDesktop)
            OutlinePillButton(
              label: l10n.scanWithCamera,
              icon: SurgeIcons.camera,
              accent: true,
              compact: true,
              onPressed: _scanCamera,
            ),
          OutlinePillButton(
            label: l10n.qrFromImage,
            icon: SurgeIcons.image,
            accent: system.isDesktop,
            compact: true,
            onPressed: _scanImage,
          ),
        ],
      ),
      const SizedBox(height: SurgeSpace.m),
      _Hint(l10n.qrToLinkHint),
    ];
  }

  List<Widget> _filePane(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final file = _file;
    return [
      Semantics(
        button: true,
        label: l10n.chooseProfileFile,
        child: SurgePressable(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(SurgeSpace.xl),
          child: CustomPaint(
            painter: _DashedBorder(
              color: surge.separator,
              radius: SurgeSpace.xl,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SurgeSpace.xxl,
                horizontal: SurgeSpace.l,
              ),
              child: Column(
                children: [
                  Icon(
                    SurgeIcons.upload,
                    size: SurgeIconSize.hero,
                    color: surge.primary,
                  ),
                  const SizedBox(height: SurgeSpace.s),
                  Text(
                    l10n.chooseProfileFile,
                    style: context.typography.controlLabel.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                  Text(
                    l10n.profileFileTypes,
                    style: context.typography.supporting.copyWith(
                      color: surge.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (file != null) ...[
        const SizedBox(height: SurgeSpace.m),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SurgeSpace.m,
            vertical: SurgeSpace.s + SurgeSpace.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(surge.radii.list),
            border: Border.all(color: surge.separator),
          ),
          child: Row(
            children: [
              Icon(
                SurgeIcons.file,
                size: SurgeIconSize.regular,
                color: surge.primary,
              ),
              const SizedBox(width: SurgeSpace.s + SurgeSpace.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.technical.copyWith(
                        color: surge.textPrimary,
                      ),
                    ),
                    Text(
                      file.bytes.length.traffic.show,
                      style: context.typography.supporting.copyWith(
                        color: surge.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.delete,
                onPressed: () => setState(() => _file = null),
                icon: const Icon(SurgeIcons.close),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: SurgeSpace.m),
          _ErrorCard(message: _error!, onRetry: _submit),
        ],
        const SizedBox(height: SurgeSpace.l),
        ..._details(context, autoUpdate: false),
        const SizedBox(height: SurgeSpace.m),
        _Hint(l10n.fileNoUpdates),
      ],
    ];
  }

  List<Widget> _details(BuildContext context, {required bool autoUpdate}) {
    final l10n = context.appLocalizations;
    return [
      SurgeField(
        label: l10n.name,
        child: TextField(
          key: const ValueKey('add-profile-name'),
          controller: _name,
          textInputAction: TextInputAction.done,
          decoration: surgeInputDecoration(
            context,
            hintText: _suggestedName().isNotEmpty
                ? _suggestedName()
                : l10n.optional,
          ),
        ),
      ),
      const SizedBox(height: SurgeSpace.l),
      ProfileCoreField(
        value: _core,
        onChanged: (core) => setState(() => _core = core),
        helperText: _core == ProfileCore.mihomo
            ? l10n.coreMihomoHint
            : l10n.coreXrayHint,
      ),
      if (autoUpdate) ...[
        const SizedBox(height: SurgeSpace.l),
        SurgeToggleFieldRow(
          label: l10n.autoUpdate,
          subtitle: _autoUpdate
              ? l10n.updateEvery(addProfileIntervalLabel(l10n, _interval))
              : l10n.updateManually,
          value: _autoUpdate,
          onChanged: (value) => setState(() => _autoUpdate = value),
        ),
        SurgeAnimatedReveal(
          visible: _autoUpdate,
          child: Padding(
            padding: const EdgeInsets.only(top: SurgeSpace.m),
            child: Wrap(
              spacing: SurgeSpace.xs + SurgeSpace.xxs,
              runSpacing: SurgeSpace.xs + SurgeSpace.xxs,
              children: [
                for (final interval in addProfileIntervals)
                  _IntervalChip(
                    label: addProfileIntervalLabel(l10n, interval),
                    selected: interval == _interval,
                    onTap: () => setState(() => _interval = interval),
                  ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  Widget _doneBody(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    final added = _added!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SurgeSpace.l),
      child: Column(
        children: [
          Container(
            width: SurgeSpace.huge + SurgeSpace.l,
            height: SurgeSpace.huge + SurgeSpace.l,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surge.green.withValues(alpha: SurgeAlpha.a12),
            ),
            child: Icon(
              SurgeIcons.confirm,
              size: SurgeIconSize.hero,
              color: surge.green,
            ),
          ),
          const SizedBox(height: SurgeSpace.m),
          Text(
            l10n.profileAddedTitle(added.realLabel),
            textAlign: TextAlign.center,
            style: context.typography.cardTitle.copyWith(
              color: surge.textPrimary,
            ),
          ),
          const SizedBox(height: SurgeSpace.s),
          Text(
            [
              added.core.label,
              if (added.type == ProfileType.url && added.autoUpdate)
                l10n.updateEvery(
                  addProfileIntervalLabel(l10n, added.autoUpdateDuration),
                ),
            ].join(' · '),
            style: context.typography.technical.copyWith(
              color: surge.textSecondary,
            ),
          ),
          const SizedBox(height: SurgeSpace.s),
          Text(
            _wasFirst ? l10n.firstProfileIsCurrent : l10n.previousProfileStays,
            textAlign: TextAlign.center,
            style: context.typography.supporting.copyWith(
              color: surge.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneActions(BuildContext context) {
    final l10n = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_wasFirst) ...[
          OutlinePillButton(
            label: l10n.makeCurrent,
            accent: true,
            onPressed: () {
              selectProfile(ref, _added!.id);
              _close();
            },
          ),
          const SizedBox(height: SurgeSpace.s),
        ],
        OutlinePillButton(
          label: l10n.done,
          accent: _wasFirst,
          onPressed: _close,
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.typography.supporting.copyWith(
      color: SurgeTheme.of(context).textSecondary,
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(SurgeSpace.m + SurgeSpace.xxs),
        decoration: BoxDecoration(
          color: surge.red.withValues(alpha: SurgeAlpha.a08),
          borderRadius: BorderRadius.circular(surge.radii.list),
          border: Border.all(
            color: surge.red.withValues(alpha: SurgeAlpha.a48),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileLoadFailed,
              style: context.typography.controlLabel.copyWith(color: surge.red),
            ),
            const SizedBox(height: SurgeSpace.xs),
            Text(
              message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: context.typography.supporting.copyWith(
                color: surge.textSecondary,
              ),
            ),
            const SizedBox(height: SurgeSpace.s),
            OutlinePillButton(
              label: l10n.retry,
              compact: true,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _IntervalChip extends StatelessWidget {
  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = BorderRadius.circular(surge.radii.button);
    return Semantics(
      button: true,
      selected: selected,
      child: SurgePressable(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: SurgeMotion.state,
          padding: const EdgeInsets.symmetric(
            horizontal: SurgeSpace.m + SurgeSpace.xxs,
            vertical: SurgeSpace.s,
          ),
          decoration: BoxDecoration(
            color: selected
                ? surge.primary.withValues(alpha: SurgeAlpha.a16)
                : null,
            borderRadius: radius,
            border: Border.all(
              color: selected ? surge.primary : surge.separator,
            ),
          ),
          child: Text(
            label,
            style: context.typography.controlLabel.copyWith(
              color: selected ? surge.primary : surge.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The camera frame of the QR tab; tapping it opens the scanner.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.hint, required this.onTap});

  static const double height = 200;

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final radius = BorderRadius.circular(SurgeSpace.xl);
    return Semantics(
      button: true,
      label: hint,
      child: SurgePressable(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: height,
          decoration: BoxDecoration(color: surge.fill, borderRadius: radius),
          child: CustomPaint(
            painter: _Corners(color: surge.primary),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(SurgeSpace.xxxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      SurgeIcons.qrCode,
                      size: SurgeIconSize.hero,
                      color: surge.primary,
                    ),
                    const SizedBox(height: SurgeSpace.s),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: context.typography.supporting.copyWith(
                        color: surge.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Corners extends CustomPainter {
  _Corners({required this.color});

  static const double inset = SurgeSpace.l + SurgeSpace.xs;
  static const double arm = SurgeSpace.xxl + SurgeSpace.s;
  static const double stroke = 3;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [
      (1.0, 1.0),
      (-1.0, 1.0),
      (1.0, -1.0),
      (-1.0, -1.0),
    ]) {
      final x = dx > 0 ? inset : size.width - inset;
      final y = dy > 0 ? inset : size.height - inset;
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * arm)
          ..lineTo(x, y)
          ..lineTo(x + dx * arm, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Corners old) => old.color != color;
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});

  static const double dash = 6;
  static const double gap = 5;
  static const double stroke = 1.5;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += dash + gap) {
        canvas.drawPath(metric.extractPath(at, at + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}
