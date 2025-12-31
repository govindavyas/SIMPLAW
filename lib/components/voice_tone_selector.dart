import 'package:flutter/material.dart';
import 'package:simplaw/models/document_analysis.dart';
import 'package:simplaw/theme.dart';

class VoiceToneOption {
  final VoiceTone tone;
  final String title;
  final String subtitle;
  final IconData icon;

  const VoiceToneOption({
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

/// Premium two-choice tone selector.
class VoiceToneSelector extends StatelessWidget {
  final List<VoiceToneOption> options;
  final VoiceTone value;
  final ValueChanged<VoiceTone> onChanged;

  const VoiceToneSelector({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        final tileWidth = isWide ? (constraints.maxWidth - AppSpacing.sm) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options
              .map(
                (o) => SizedBox(
                  width: tileWidth,
                  child: _ToneTile(
                    option: o,
                    selected: o.tone == value,
                    onTap: () => onChanged(o.tone),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ToneTile extends StatefulWidget {
  final VoiceToneOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ToneTile({required this.option, required this.selected, required this.onTap});

  @override
  State<_ToneTile> createState() => _ToneTileState();
}

class _ToneTileState extends State<_ToneTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.selected;

    final border = selected
        ? scheme.secondary.withValues(alpha: 0.85)
        : scheme.outline.withValues(alpha: _hovered ? 0.30 : 0.22);
    final bg = selected
        ? scheme.secondary.withValues(alpha: 0.14)
        : scheme.surface.withValues(alpha: _hovered ? 0.92 : 0.80);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? scheme.secondary.withValues(alpha: 0.22) : scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.option.icon, color: selected ? scheme.secondary : scheme.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.option.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                          size: 18,
                          color: selected ? scheme.secondary : scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.option.subtitle,
                      style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
