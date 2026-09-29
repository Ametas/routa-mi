import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/theme/static_theme.dart';
import 'package:fl_clash/theme/surge_theme_data.dart';
import 'package:fl_clash/theme/typography/text_theme.dart';
import 'package:fl_clash/widgets/dialog.dart';
import 'package:fl_clash/widgets/input.dart';
import 'package:fl_clash/widgets/list.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One canonical component in a representative state.
class CatalogEntry {
  const CatalogEntry(this.name, this.builder);

  final String name;
  final WidgetBuilder builder;
}

void _noop() {}

/// The reference set new screens are assembled from (design-system audit,
/// stage 4). Long labels are deliberate: entries must survive narrow screens
/// and large font scales.
final componentCatalog = <CatalogEntry>[
  CatalogEntry(
    'SurgeCard',
    (_) => const SurgeCard(
      child: Text('Card content that is long enough to wrap onto two lines'),
    ),
  ),
  for (final variant in SurgeActionCardVariant.values)
    CatalogEntry(
      'SurgeActionCard.${variant.name}',
      (_) => SurgeActionCard(
        variant: variant,
        padding: const EdgeInsets.all(SurgeSpace.l),
        onTap: _noop,
        child: const Text('Action card with a long descriptive label'),
      ),
    ),
  CatalogEntry(
    'SurgeActionCard.selected',
    (_) => const SurgeActionCard(
      selected: true,
      padding: EdgeInsets.all(SurgeSpace.l),
      onTap: _noop,
      child: Text('Selected action card'),
    ),
  ),
  CatalogEntry(
    'SurgeSection',
    (_) => const SurgeSection(
      title: 'Section title',
      subtitle: '3',
      footer: 'Footer text explaining what the rows above change.',
      showDividers: true,
      children: [
        SurgeListTile(
          leading: Icon(SurgeIcons.dashboard),
          title: 'Row with leading icon and a rather long title',
          subtitle: 'Subtitle that also wraps on small screens',
          showChevron: true,
          onTap: _noop,
        ),
        SurgeListTile(
          title: 'Destructive row',
          destructive: true,
          onTap: _noop,
        ),
        SurgeListTile(title: 'Disabled row', enabled: false),
      ],
    ),
  ),
  CatalogEntry(
    'SurgeIconTile',
    (context) => Row(
      children: [
        SurgeIconTile(
          icon: SurgeIcons.mediaCheck,
          color: SurgeTheme.of(context).primary,
        ),
        const SizedBox(width: SurgeSpace.s),
        SurgeIconTile(
          icon: SurgeIcons.hub,
          color: SurgeTheme.of(context).textSecondary,
          shape: SurgeIconTileShape.circle,
          backgroundAlpha: SurgeAlpha.a04,
          foregroundAlpha: SurgeAlpha.a62,
        ),
      ],
    ),
  ),
  CatalogEntry(
    'SurgeRow',
    (_) => const SurgeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SurgeRow(
            leading: Icon(SurgeIcons.logs),
            title: Text('Row layout shared by every list row'),
            subtitle: Text('Subtitle in the secondary colour'),
            trailing: Icon(SurgeIcons.chevronRight),
            contentPadding: EdgeInsets.symmetric(horizontal: SurgeSpace.l),
            minVerticalPadding: SurgeSpace.m,
            titleAlignment: ListTileTitleAlignment.center,
            onTap: _noop,
          ),
          SurgeRow(
            title: Text('Disabled row'),
            enabled: false,
            contentPadding: EdgeInsets.symmetric(horizontal: SurgeSpace.l),
            minVerticalPadding: SurgeSpace.m,
            titleAlignment: ListTileTitleAlignment.center,
            onTap: _noop,
          ),
        ],
      ),
    ),
  ),
  CatalogEntry(
    'ListItem',
    (_) => const Column(
      children: [
        ListItem(
          leading: Icon(SurgeIcons.proxies),
          title: Text('Plain list item with a long title'),
          subtitle: Text('Subtitle'),
          trailing: Icon(SurgeIcons.chevronRight),
          onTap: _noop,
        ),
        ListItem.switchItem(
          title: Text('Switch item with a long title'),
          subtitle: Text('Subtitle'),
          delegate: SwitchDelegate(value: true, onChanged: null),
        ),
        ListItem.checkbox(
          title: Text('Checkbox item'),
          delegate: CheckboxDelegate(value: true),
        ),
      ],
    ),
  ),
  for (final position in SurgeSelectableRowPosition.values)
    CatalogEntry(
      'SurgeSelectableRow.${position.name}',
      (_) => SurgeSelectableRow(
        selected: position == SurgeSelectableRowPosition.first,
        position: position,
        showBorder: true,
        showDivider: position != SurgeSelectableRowPosition.last,
        onTap: _noop,
        child: const Padding(
          padding: EdgeInsets.all(SurgeSpace.l),
          child: Text('Selectable row'),
        ),
      ),
    ),
  CatalogEntry(
    'SurgeSegmentedControl',
    (_) => SurgeSegmentedControl<int>(
      value: 1,
      items: const [
        SurgeSegmentedItem(value: 0, label: 'Rule'),
        SurgeSegmentedItem(value: 1, label: 'Global'),
        SurgeSegmentedItem(value: 2, label: 'Direct'),
      ],
      onChanged: (_) {},
    ),
  ),
  CatalogEntry(
    'SoftOsSelectPill',
    (_) => SoftOsSelectPill<int>(
      value: 0,
      semanticLabel: 'Select',
      items: const [
        SoftOsSelectItem(value: 0, label: 'Automatic selection'),
        SoftOsSelectItem(value: 1, label: 'Manual'),
      ],
      onChanged: (_) {},
    ),
  ),
  CatalogEntry(
    'SoftOsStatusPill',
    (_) => const Wrap(
      spacing: SurgeSpace.s,
      runSpacing: SurgeSpace.s,
      children: [
        SoftOsStatusPill(child: Text('Connected')),
        SoftOsStatusPill(loading: true, child: Text('Connecting')),
      ],
    ),
  ),
  CatalogEntry(
    'SurgeDelayPill',
    (_) => const Wrap(
      spacing: SurgeSpace.s,
      runSpacing: SurgeSpace.s,
      children: [
        SurgeDelayPill(delay: null, onTap: null),
        SurgeDelayPill(delay: 0, onTap: null),
        SurgeDelayPill(delay: 120, onTap: null),
        SurgeDelayPill(delay: 900, onTap: null),
        SurgeDelayPill(delay: -1, onTap: null),
      ],
    ),
  ),
  CatalogEntry(
    'SurgeStatusButton',
    (_) => const Wrap(
      spacing: SurgeSpace.s,
      runSpacing: SurgeSpace.s,
      children: [
        SurgeStatusButton(
          isActive: true,
          activeLabel: 'Stop',
          inactiveLabel: 'Start',
          onPressed: _noop,
        ),
        SurgeStatusButton(
          isActive: false,
          activeLabel: 'Stop',
          inactiveLabel: 'Start',
          loading: true,
          onPressed: _noop,
        ),
      ],
    ),
  ),
  CatalogEntry(
    'SurgeSelectIndicator',
    (_) => const Row(
      children: [
        SurgeSelectIndicator(selected: true),
        SizedBox(width: SurgeSpace.s),
        SurgeSelectIndicator(selected: false),
      ],
    ),
  ),
  CatalogEntry(
    'SoftOsActionDock.inset',
    (_) => const Row(
      children: [
        SoftOsActionDock(
          style: SoftOsDockStyle.inset,
          children: [
            SoftOsActionDockButton(
              tooltip: 'Search',
              icon: SurgeIcons.search,
              onPressed: _noop,
            ),
            SoftOsDockDivider(),
            SoftOsActionDockButton(
              tooltip: 'Add',
              icon: SurgeIcons.add,
              onPressed: _noop,
            ),
          ],
        ),
      ],
    ),
  ),
  CatalogEntry(
    'SoftOsActionDock.raised',
    (_) => const Row(
      children: [
        SoftOsActionDock(
          children: [
            SoftOsActionDockButton(icon: SurgeIcons.edit, onPressed: _noop),
            SoftOsActionDockButton(icon: SurgeIcons.more, onPressed: _noop),
          ],
        ),
      ],
    ),
  ),
  CatalogEntry(
    'surgeInputDecoration',
    (context) => TextField(
      decoration: surgeInputDecoration(
        context,
        labelText: 'Subscription URL',
        helperText: 'Helper text below the field',
      ),
    ),
  ),
  CatalogEntry(
    'CommonDialog',
    (context) => const CommonDialog(
      title: 'Dialog title',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Dialog body text that explains the action.'),
          SizedBox(height: SurgeSpace.l),
          SurgeDialogActionRow(
            cancelLabel: 'Cancel',
            submitLabel: 'Confirm',
            onCancel: _noop,
            onSubmit: _noop,
          ),
        ],
      ),
    ),
  ),
];

/// The app theme for [brightness] on the default preset.
ThemeData catalogTheme(Brightness brightness) {
  final spec = StaticThemeSpec.resolve(StaticThemePreset.blueWhite, brightness);
  final textTheme = buildSlclashTextTheme();
  return buildSurgeThemeData(
    colorScheme: spec.colorScheme,
    textTheme: textTheme,
    surge: SurgeTheme.fromColors(spec.colors, stateColors: spec.stateColors),
    typography: SurgeTypography.fromTextTheme(textTheme),
  );
}

/// Narrow phone width the catalog is checked at.
const catalogWidth = 320.0;

/// Hosts catalog content in the real app theme at [textScale].
Widget catalogApp({
  required Brightness brightness,
  required double textScale,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      viewSizeProvider.overrideWithBuild(
        (_, _) => const Size(catalogWidth, 800),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      theme: catalogTheme(brightness),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}
