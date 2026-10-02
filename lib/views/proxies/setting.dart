import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/setting.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxiesSetting extends ConsumerWidget {
  const ProxiesSetting({super.key});

  String _sortLabel(BuildContext context, ProxiesSortType type) {
    final appLocalizations = context.appLocalizations;
    return switch (type) {
      ProxiesSortType.none => appLocalizations.defaultText,
      ProxiesSortType.delay => appLocalizations.delay,
      ProxiesSortType.name => appLocalizations.name,
    };
  }

  IconData _sortIcon(ProxiesSortType type) {
    return switch (type) {
      ProxiesSortType.none => SurgeIcons.sort,
      ProxiesSortType.delay => SurgeIcons.networkPing,
      ProxiesSortType.name => SurgeIcons.sortAlphabetically,
    };
  }

  String _iconStyleLabel(BuildContext context, ProxiesIconStyle style) {
    final appLocalizations = context.appLocalizations;
    return switch (style) {
      ProxiesIconStyle.standard => appLocalizations.standard,
      ProxiesIconStyle.none => appLocalizations.none,
      ProxiesIconStyle.icon => appLocalizations.onlyIcon,
    };
  }

  IconData _iconStyleIcon(ProxiesIconStyle style) {
    return switch (style) {
      ProxiesIconStyle.standard => SurgeIcons.agenda,
      ProxiesIconStyle.none => SurgeIcons.alignLeft,
      ProxiesIconStyle.icon => SurgeIcons.apps,
    };
  }

  void _setListStyle(WidgetRef ref) {
    ref.read(proxiesStyleSettingProvider.notifier).update((state) {
      return state.copyWith(type: ProxiesType.list);
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final state = ref.watch(proxiesStyleSettingProvider);

    if (state.type != ProxiesType.list) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setListStyle(ref));
    }

    final surge = SurgeTheme.of(context);
    Widget option({
      required IconData icon,
      required String label,
      required bool selected,
      required bool last,
      required VoidCallback onTap,
    }) {
      return SurgeSettingOption(
        leading: SurgeIconTile(
          icon: icon,
          color: selected ? surge.primary : surge.textSecondary,
        ),
        title: label,
        selected: selected,
        showDivider: !last,
        onTap: onTap,
      );
    }

    const sortTypes = ProxiesSortType.values;
    const iconStyles = ProxiesIconStyle.values;
    return SurgeSectionList(
      sections: [
        SurgeSection(
          title: appLocalizations.sort,
          children: [
            for (final item in sortTypes)
              option(
                icon: _sortIcon(item),
                label: _sortLabel(context, item),
                selected: state.sortType == item,
                last: item == sortTypes.last,
                onTap: () {
                  ref.read(proxiesStyleSettingProvider.notifier).update((
                    state,
                  ) {
                    return state.copyWith(sortType: item);
                  });
                },
              ),
          ],
        ),
        SurgeSection(
          title: appLocalizations.iconStyle,
          children: [
            for (final item in iconStyles)
              option(
                icon: _iconStyleIcon(item),
                label: _iconStyleLabel(context, item),
                selected: state.iconStyle == item,
                last: item == iconStyles.last,
                onTap: () {
                  ref.read(proxiesStyleSettingProvider.notifier).update((
                    state,
                  ) {
                    return state.copyWith(iconStyle: item);
                  });
                },
              ),
          ],
        ),
      ],
    );
  }
}
