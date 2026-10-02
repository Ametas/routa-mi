import 'package:fl_clash/common/icons.dart';
import 'package:fl_clash/common/context.dart';
import 'package:fl_clash/widgets/surge/surge_motion.dart';
import 'package:fl_clash/widgets/surge/surge_theme_extension.dart';
import 'package:fl_clash/widgets/surge/surge_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InitErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace stack;

  const InitErrorScreen({super.key, required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.appLocalizations.initFailed),
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SurgeSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    SurgeIcons.warning,
                    color: colorScheme.error,
                    size: SurgeIconSize.hero,
                  ),
                  const SizedBox(width: SurgeSpace.m),
                  Expanded(
                    child: Text(
                      context.appLocalizations.initFailedDescription,
                      style: context.typography.cardTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SurgeSpace.xxl),
              _buildSectionLabel(
                context,
                context.appLocalizations.errorDetails,
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SurgeSpace.m),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(
                    alpha: SurgeAlpha.a48,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: SurgeAlpha.a48),
                  ),
                ),
                child: SelectableText(
                  error.toString(),
                  style: context.typography.technical.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: SurgeSpace.xxl),
              _buildSectionLabel(context, context.appLocalizations.stackTrace),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SurgeSpace.m),
                decoration: BoxDecoration(
                  color: SurgeTheme.of(context).fill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SurgeTheme.of(context).separator),
                ),
                child: SelectableText(
                  stack.toString(),
                  style: context.typography.technical,
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _copyToClipboard(context),
        label: Text(context.appLocalizations.copyDetails),
        icon: const Icon(SurgeIcons.copy),
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SurgeSpace.s),
      child: Text(text, style: context.typography.sectionTitle),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final text = '=== ERROR ===\n$error\n\n=== STACK TRACE ===\n$stack';
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.appLocalizations.errorDetailsCopied),
        duration: SurgeMotion.snackBar,
      ),
    );
  }
}
