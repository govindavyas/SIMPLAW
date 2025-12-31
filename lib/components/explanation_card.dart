import 'package:flutter/material.dart';
import 'package:simplaw/models/document_analysis.dart';
import 'package:simplaw/theme.dart';

class ExplanationCard extends StatelessWidget {
  final DocumentAnalysis analysis;

  const ExplanationCard({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What This Means for You',
              style: context.textStyles.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildInfoRow(
              context,
              icon: Icons.description_outlined,
              label: 'Document Type',
              value: analysis.documentType,
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: Theme.of(context).colorScheme.outline, height: 1),
            const SizedBox(height: AppSpacing.md),
            _buildInfoRow(
              context,
              icon: Icons.lightbulb_outline,
              label: 'Simple Explanation',
              value: analysis.simpleExplanation,
              isMultiline: true,
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: Theme.of(context).colorScheme.outline, height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    context,
                    icon: Icons.task_alt_outlined,
                    label: 'Action Required',
                    value: analysis.actionRequired ? 'Yes' : 'No',
                    valueColor: analysis.actionRequired
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildInfoRow(
                    context,
                    icon: Icons.warning_amber_outlined,
                    label: 'Risk Level',
                    value: analysis.riskLevel.displayName,
                    valueColor: _getRiskLevelColor(context, analysis.riskLevel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: Theme.of(context).colorScheme.outline, height: 1),
            const SizedBox(height: AppSpacing.md),
            _buildInfoRow(
              context,
              icon: Icons.calendar_today_outlined,
              label: 'Deadline',
              value: analysis.deadline ?? 'No clear deadline mentioned',
              valueColor: analysis.deadline != null
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: Theme.of(context).colorScheme.outline, height: 1),
            const SizedBox(height: AppSpacing.md),
            _buildInfoRow(
              context,
              icon: Icons.directions_outlined,
              label: 'Suggested Next Step',
              value: analysis.suggestedNextStep,
              isMultiline: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: context.textStyles.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            value,
            style: context.textStyles.bodyMedium?.copyWith(
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              height: isMultiline ? 1.6 : 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Color _getRiskLevelColor(BuildContext context, RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Theme.of(context).colorScheme.error;
    }
  }
}
