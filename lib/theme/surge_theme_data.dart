import 'package:fl_clash/widgets/surge/surge_theme_extension.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

/// The app [ThemeData]: Material component themes derived from [SurgeTheme]
/// and [SurgeTypography], so bare Material widgets look like Surge ones
/// without per-screen styling.
///
/// Text fields are intentionally not themed here: several are plain on
/// purpose (app bar search, editor title), and styled fields go through
/// `surgeInputDecoration`.
ThemeData buildSurgeThemeData({
  required ColorScheme colorScheme,
  required TextTheme textTheme,
  required SurgeTheme surge,
  required SurgeTypography typography,
  PageTransitionsTheme? pageTransitionsTheme,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    pageTransitionsTheme: pageTransitionsTheme,
    textTheme: textTheme,
    extensions: [surge, typography],
    scaffoldBackgroundColor: surge.background,
    canvasColor: surge.background,
    appBarTheme: SurgeComponentThemes.appBar(surge, typography),
    navigationBarTheme: SurgeComponentThemes.navigationBar(surge, typography),
    switchTheme: SurgeComponentThemes.switchTheme(surge),
    radioTheme: SurgeComponentThemes.radio(surge),
    checkboxTheme: SurgeComponentThemes.checkbox(surge),
    dividerTheme: SurgeComponentThemes.divider(surge),
    dialogTheme: SurgeComponentThemes.dialog(surge, typography),
    bottomSheetTheme: SurgeComponentThemes.bottomSheet(surge),
    progressIndicatorTheme: SurgeComponentThemes.progressIndicator(surge),
    snackBarTheme: SurgeComponentThemes.snackBar(),
    textSelectionTheme: SurgeComponentThemes.textSelection(surge),
  );
}

abstract final class SurgeComponentThemes {
  static AppBarTheme appBar(SurgeTheme surge, SurgeTypography typography) {
    return AppBarTheme(
      backgroundColor: surge.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: surge.textPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
      iconTheme: IconThemeData(color: surge.textPrimary),
      actionsIconTheme: IconThemeData(color: surge.textPrimary),
      titleTextStyle: typography.appBarTitle.copyWith(color: surge.textPrimary),
    );
  }

  static NavigationBarThemeData navigationBar(
    SurgeTheme surge,
    SurgeTypography typography,
  ) {
    return NavigationBarThemeData(
      backgroundColor: surge.card,
      indicatorColor: surge.selectedFill,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return typography.navigationLabel.copyWith(
          color: selected ? surge.primary : surge.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? surge.primary : surge.textSecondary,
          size: 22,
        );
      }),
    );
  }

  static SwitchThemeData switchTheme(SurgeTheme surge) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return surge.textSecondary.withValues(alpha: SurgeAlpha.a48);
        }
        if (states.contains(WidgetState.selected)) {
          return surge.semantic.state.onToggleActive;
        }
        return surge.elevatedCard;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return surge.textSecondary.withValues(alpha: SurgeAlpha.a12);
        }
        if (states.contains(WidgetState.selected)) {
          return surge.semantic.state.toggleActive;
        }
        return surge.fill;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return surge.separator;
      }),
    );
  }

  static RadioThemeData radio(SurgeTheme surge) {
    return RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return surge.primary;
        }
        return surge.textSecondary.withValues(alpha: SurgeAlpha.a82);
      }),
    );
  }

  static CheckboxThemeData checkbox(SurgeTheme surge) {
    return CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return surge.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(surge.onPrimary),
      side: BorderSide(color: surge.separator, width: 1.2),
    );
  }

  /// Colour only: dividers keep their own height and hairline thickness.
  static DividerThemeData divider(SurgeTheme surge) {
    return DividerThemeData(color: surge.separator);
  }

  /// Surface and title; the shape stays Material 3 (`CommonDialog`).
  static DialogThemeData dialog(SurgeTheme surge, SurgeTypography typography) {
    return DialogThemeData(
      backgroundColor: surge.card,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: typography.dialogTitle.copyWith(color: surge.textPrimary),
    );
  }

  static BottomSheetThemeData bottomSheet(SurgeTheme surge) {
    return BottomSheetThemeData(
      surfaceTintColor: Colors.transparent,
      dragHandleColor: surge.separator,
    );
  }

  static ProgressIndicatorThemeData progressIndicator(SurgeTheme surge) {
    return ProgressIndicatorThemeData(
      color: surge.primary,
      linearTrackColor: surge.fill,
    );
  }

  static SnackBarThemeData snackBar() {
    return const SnackBarThemeData(behavior: SnackBarBehavior.floating);
  }

  static TextSelectionThemeData textSelection(SurgeTheme surge) {
    return TextSelectionThemeData(
      cursorColor: surge.primary,
      selectionColor: surge.primary.withValues(alpha: SurgeAlpha.a38),
      selectionHandleColor: surge.primary,
    );
  }
}
