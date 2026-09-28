import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';

extension TextStyleExtension on TextStyle {
  TextStyle get toLight =>
      copyWith(color: color?.withValues(alpha: SurgeAlpha.a82));

  TextStyle get toLighter =>
      copyWith(color: color?.withValues(alpha: SurgeAlpha.a62));
}
