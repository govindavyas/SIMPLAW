import 'package:flutter/material.dart';
import 'package:simplaw/theme.dart';

/// Premium upload zone with animated pulse + hover micro-interactions.
///
/// Note: Actual file selection still uses the platform picker (tap/click).
/// This widget focuses on instant feedback and polished affordances.
class UploadDropZone extends StatefulWidget {
  final bool busy;
  final VoidCallback? onPick;

  const UploadDropZone({super.key, required this.busy, required this.onPick});

  @override
  State<UploadDropZone> createState() => _UploadDropZoneState();
}

class _UploadDropZoneState extends State<UploadDropZone> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (!widget.busy) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant UploadDropZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy && _pulse.isAnimating) {
      _pulse.stop();
    } else if (!widget.busy && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canTap = widget.onPick != null && !widget.busy;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: canTap ? widget.onPick : null,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = _hovered ? 1.0 : _pulse.value;
            final glow = widget.busy ? 0.0 : (0.08 + (t * 0.08));
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: (canTap ? scheme.secondary : scheme.outline).withValues(alpha: canTap ? 0.45 : 0.22),
                  width: canTap ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.secondary.withValues(alpha: glow),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      widget.busy ? Icons.document_scanner_rounded : Icons.cloud_upload_rounded,
                      size: 34,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    widget.busy ? 'Analyzing your document…' : 'Drag & drop or tap to upload',
                    textAlign: TextAlign.center,
                    style: context.textStyles.titleSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDF and TXT supported',
                    textAlign: TextAlign.center,
                    style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _FileTypeChip(label: 'PDF', icon: Icons.picture_as_pdf_rounded),
                      _FileTypeChip(label: 'TXT', icon: Icons.description_rounded),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FileTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _FileTypeChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: context.textStyles.labelLarge?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
