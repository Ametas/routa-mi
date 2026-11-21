import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/common.dart';
import 'package:fl_clash/views/profiles/add_profile_sheet.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// The title row of the profiles page (design 3.1 "RoutaMi Add Profile"):
/// the outlined "+" opens the add sheet, the menu keeps sync and order.
class ProfilesTopBar extends StatelessWidget {
  const ProfilesTopBar({
    super.key,
    this.menuItems = const [],
    this.isLoading = false,
  });

  final List<PopupMenuItemData> menuItems;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SurgeSpace.l,
        SurgeSpace.m,
        SurgeSpace.l,
        SurgeSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.profiles,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.rootAppBarTitle.copyWith(
                    color: surge.textPrimary,
                  ),
                ),
              ),
              ProxyRoundAction(
                key: const ValueKey('profiles-add'),
                icon: SurgeIcons.add,
                tooltip: l10n.addProfile,
                accent: true,
                onPressed: () => showAddProfileSheet(context),
              ),
              if (menuItems.isNotEmpty) ...[
                const SizedBox(width: SurgeSpace.s),
                CommonPopupBox(
                  popup: CommonPopupMenu(items: menuItems),
                  targetBuilder: (open) => ProxyRoundAction(
                    icon: SurgeIcons.moreVertical,
                    tooltip: l10n.more,
                    onPressed: () => open(
                      offset: const Offset(
                        ProxyGroupBits.action,
                        ProxyGroupBits.action + SurgeSpace.xs,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(top: SurgeSpace.s),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

/// No profiles yet: what to do next, with the three ways to add one.
class ProfilesEmptyState extends StatelessWidget {
  const ProfilesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final l10n = context.appLocalizations;
    return Align(
      alignment: const Alignment(0, -0.3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SurgeSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProfileEmptyIllustration(),
            const SizedBox(height: SurgeSpace.l),
            Text(
              l10n.noProfilesTitle,
              textAlign: TextAlign.center,
              style: context.typography.cardTitle.copyWith(
                color: surge.textPrimary,
              ),
            ),
            const SizedBox(height: SurgeSpace.s),
            Text(
              l10n.noProfilesHint,
              textAlign: TextAlign.center,
              style: context.typography.supporting.copyWith(
                color: surge.textSecondary,
              ),
            ),
            const SizedBox(height: SurgeSpace.l),
            OutlinePillButton(
              label: l10n.addProfile,
              icon: SurgeIcons.link,
              accent: true,
              onPressed: () => showAddProfileSheet(context),
            ),
            const SizedBox(height: SurgeSpace.s),
            Wrap(
              spacing: SurgeSpace.s,
              children: [
                OutlinePillButton(
                  label: l10n.qrcode,
                  icon: SurgeIcons.qrCode,
                  compact: true,
                  onPressed: () =>
                      showAddProfileSheet(context, method: AddProfileMethod.qr),
                ),
                OutlinePillButton(
                  label: l10n.file,
                  icon: SurgeIcons.file,
                  compact: true,
                  onPressed: () => showAddProfileSheet(
                    context,
                    method: AddProfileMethod.file,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
