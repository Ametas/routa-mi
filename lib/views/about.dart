import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/scaffold.dart';
import 'package:fl_clash/widgets/changelog_dialog.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  static const _unknown = 'unknown';

  String get _coreVersion {
    final version = globalState.mihomoVersion;
    if (version.isEmpty) return _unknown;
    return version.startsWith('v') ? version : 'v$version';
  }

  String get _coreReleaseDate {
    final releaseDate = globalState.mihomoReleaseDate.takeFirstValid([
      globalState.coreBuildTime,
    ]);
    if (releaseDate.isEmpty) return _unknown;
    final dateTime = DateTime.tryParse(releaseDate);
    if (dateTime == null) return releaseDate;
    return dateTime.toLocal().show;
  }

  String get _coreSourceUrl {
    final version = globalState.mihomoVersion;
    if (version.isEmpty) return 'https://github.com/MetaCubeX/mihomo';
    final tag = version.startsWith('v') ? version : 'v$version';
    return 'https://github.com/MetaCubeX/mihomo/tree/$tag';
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final data = await globalState.safeRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: context.appLocalizations.checkUpdate,
    );
    globalState.container
        .read(commonActionProvider.notifier)
        .checkUpdateResultHandle(data: data, isUser: true);
  }

  Future<void> _showChangelog(BuildContext context) {
    return globalState.showCommonDialog<bool>(
      child: const AppChangelogDialog(),
    );
  }

  Widget _buildMoreSection(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SurgeSection(
      title: appLocalizations.more,
      margin: EdgeInsets.zero,
      showDividers: true,
      children: [
        _AboutLinkItem(
          icon: SurgeIcons.systemUpdate,
          title: appLocalizations.checkUpdate,
          onTap: () => _checkUpdate(context),
        ),
        _AboutLinkItem(
          icon: SurgeIcons.newRelease,
          title: appLocalizations.changelog,
          onTap: () => _showChangelog(context),
        ),
        _AboutLinkItem(
          icon: SurgeIcons.code,
          title: appLocalizations.upstreamProject,
          onTap: () =>
              globalState.openUrl('https://github.com/chen08209/FlClash'),
        ),
        _AboutLinkItem(
          icon: SurgeIcons.proxyGroup,
          title: appLocalizations.project,
          onTap: () => globalState.openUrl('https://github.com/$repository'),
        ),
        _AboutLinkItem(
          icon: SurgeIcons.memory,
          title: appLocalizations.core,
          onTap: () => globalState.openUrl(_coreSourceUrl),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final surge = SurgeTheme.of(context);
    return CommonScaffold(
      title: appLocalizations.about,
      body: ColoredBox(
        color: surge.background,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            SurgeSpace.l,
            SurgeSpace.l,
            SurgeSpace.l,
            SurgeSpace.xxxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            SurgeCard(
              borderRadius: 18,
              shadow: true,
              padding: const EdgeInsets.fromLTRB(
                SurgeSpace.l,
                SurgeSpace.l,
                SurgeSpace.l,
                SurgeSpace.l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer(
                    builder: (_, ref, _) {
                      return _DeveloperModeDetector(
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/icon.png',
                              width: 58,
                              height: 58,
                            ),
                            const SizedBox(width: SurgeSpace.l),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appName,
                                    style: context.typography.appBarTitle
                                        .copyWith(color: surge.textPrimary),
                                  ),
                                  const SizedBox(height: SurgeSpace.xs),
                                  Text(
                                    globalState.packageInfo.version,
                                    style: context.typography.supporting
                                        .copyWith(color: surge.textSecondary),
                                  ),
                                  const SizedBox(height: SurgeSpace.xs),
                                  Text(
                                    appLocalizations.coreReleaseInfo(
                                      _coreVersion,
                                      _coreReleaseDate,
                                    ),
                                    style: context.typography.supporting
                                        .copyWith(color: surge.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onEnterDeveloperMode: () {
                          ref
                              .read(appSettingProvider.notifier)
                              .update(
                                (state) => state.copyWith(developerMode: true),
                              );
                          context.showNotifier(
                            appLocalizations.developerModeEnableTip,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: SurgeSpace.l),
                  const Divider(height: 0),
                  const SizedBox(height: SurgeSpace.m),
                  Text(
                    appLocalizations.aboutDescription,
                    style: context.typography.supporting.copyWith(
                      color: surge.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SurgeSpace.l),
            _buildMoreSection(context),
          ],
        ),
      ),
    );
  }
}

class _AboutLinkItem extends StatelessWidget {
  const _AboutLinkItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgePressable(
      onTap: onTap,
      scaleFeedback: false,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SurgeSpace.l),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 28,
                child: Center(
                  child: Icon(
                    icon,
                    size: SurgeIconSize.regular,
                    color: surge.primary,
                  ),
                ),
              ),
              const SizedBox(width: SurgeSpace.m),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: context.typography.rowTitle.copyWith(
                    color: surge.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: SurgeSpace.m),
              SizedBox.square(
                dimension: 28,
                child: Center(
                  child: Icon(
                    SurgeIcons.openInNew,
                    size: SurgeIconSize.compact,
                    color: surge.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
