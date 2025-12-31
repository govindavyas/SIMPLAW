import 'package:flutter/material.dart';
import 'package:simplaw/theme.dart';

class LanguageOption {
  final String name;
  final String flag;
  final IconData icon;

  const LanguageOption({required this.name, required this.flag, required this.icon});
}

/// Premium language selector: a responsive grid with flag icons.
class LanguageGridSelector extends StatelessWidget {
  final List<LanguageOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  const LanguageGridSelector({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossAxisCount = w >= 720 ? 6 : w >= 520 ? 5 : w >= 380 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.15,
          ),
          itemCount: options.length,
          itemBuilder: (context, i) {
            final opt = options[i];
            final selected = opt.name == value;
            return _LanguageTile(
              option: opt,
              selected: selected,
              onTap: () => onChanged(opt.name),
              scheme: scheme,
            );
          },
        );
      },
    );
  }
}

class _LanguageTile extends StatefulWidget {
  final LanguageOption option;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _LanguageTile({required this.option, required this.selected, required this.onTap, required this.scheme});

  @override
  State<_LanguageTile> createState() => _LanguageTileState();
}

class _LanguageTileState extends State<_LanguageTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final selected = widget.selected;
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.10)
        : scheme.surface.withValues(alpha: _hovered ? 0.92 : 0.80);
    final border = selected ? scheme.primary.withValues(alpha: 0.55) : scheme.outline.withValues(alpha: 0.22);
    final fg = selected ? scheme.primary : scheme.onSurface;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.option.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Icon(widget.option.icon, size: 16, color: fg),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.option.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.labelMedium?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
