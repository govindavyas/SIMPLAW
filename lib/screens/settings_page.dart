import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:simplaw/services/app_settings_service.dart';
import 'package:simplaw/services/elevenlabs_service.dart';
import 'package:simplaw/theme.dart';
import 'package:simplaw/components/minimal_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppSettingsService _settings = AppSettingsService();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;
  bool _checkedDialog = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await _settings.getElevenLabsApiKey();
      if (mounted) _apiKeyController.text = saved ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
      // After initial load, if not configured, show the configuration dialog.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowConfigDialog();
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final cleaned = _settings.prepareKeyForStorage(_apiKeyController.text);
    final ok = await _settings.setElevenLabsApiKey(cleaned);
    if (mounted) {
      setState(() => _saving = false);
      _showSnackBar(
        ok ? 'API key saved successfully' : 'Failed to save key',
        isError: !ok,
      );
    }
  }

  void _maybeShowConfigDialog() {
    if (_checkedDialog) return;
    _checkedDialog = true;
    final missing = _apiKeyController.text.trim().isEmpty &&
        AppSettingsService.defaultElevenLabsKey.trim().isEmpty;
    if (!missing) return;

    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.record_voice_over_rounded, color: colorScheme.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Set up voice narration',
                        style: context.textStyles.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  IconButton(
                      tooltip: 'Close',
                    onPressed: () => context.pop(),
                      icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                    )
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'To hear explanations out loud, add your ElevenLabs API key. This lets the app speak naturally in the language you choose, using a matching voice.',
                  style: context.textStyles.bodyMedium?.copyWith(color: colorScheme.onSurface),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: colorScheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'You can close this for now. We\'ll remind you again until voice is set up.',
                          style: context.textStyles.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                        context.pop();
                          // Scroll to API key field focus
                        },
                        icon: Icon(Icons.settings_rounded, color: colorScheme.onPrimary),
                        label: Text('I\'ll set it up now', style: context.textStyles.labelLarge?.copyWith(color: colorScheme.onPrimary)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Close'),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    ).then((_) {
      // If still missing, keep behavior; the dialog will be shown next time settings is opened
    });
  }

  Future<void> _test() async {
    setState(() => _saving = true);
    final cleaned = _settings.prepareKeyForStorage(_apiKeyController.text);
    final verified = await ElevenLabsService().verifyKey(overrideRawKey: cleaned);
    if (!mounted) return;
    setState(() => _saving = false);
    _showSnackBar(
      verified ? 'API key verified successfully' : 'Invalid or unauthorized key',
      isError: !verified,
    );
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    final ok = await _settings.setElevenLabsApiKey('');
    if (mounted) {
      _apiKeyController.clear();
      setState(() => _saving = false);
      _showSnackBar(
        ok ? 'API key cleared' : 'Failed to clear key',
        isError: !ok,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? colorScheme.error : colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: MinimalHeader(showSettingsButton: false)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildNoticeChip(context),
                        _buildVoiceNarrationSection(context),
                        const SizedBox(height: AppSpacing.xl),
                        _buildAboutSection(context),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNoticeChip(BuildContext context) {
    final missing = _apiKeyController.text.trim().isEmpty &&
        AppSettingsService.defaultElevenLabsKey.trim().isEmpty;
    if (!missing) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.volume_off_rounded, color: colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Voice narration is disabled until you add an ElevenLabs API key.',
              style: context.textStyles.bodyMedium?.copyWith(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceNarrationSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.record_voice_over_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Narration',
                      style: context.textStyles.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Powered by ElevenLabs',
                      style: context.textStyles.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'API Key',
            style: context.textStyles.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _apiKeyController,
              obscureText: _obscure,
              style: context.textStyles.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your ElevenLabs API key',
                hintStyle: context.textStyles.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: _saving ? 'Saving...' : 'Save',
                  icon: Icons.check_rounded,
                  onPressed: _saving ? null : _save,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: 'Test',
                  icon: Icons.play_arrow_rounded,
                  onPressed: _saving ? null : _test,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ActionButton(
                label: 'Clear',
                icon: Icons.close_rounded,
                onPressed: _saving ? null : _clear,
                isDestructive: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'If you leave this empty, the app will use the default key if available.',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: colorScheme.secondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'About SIMPLAW',
                style: context.textStyles.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _AboutItem(
            icon: Icons.description_outlined,
            title: 'Purpose',
            description: 'Explains legal documents in simple terms',
          ),
          const SizedBox(height: AppSpacing.md),
          _AboutItem(
            icon: Icons.gavel_outlined,
            title: 'Disclaimer',
            description: 'Not legal advice. Consult a qualified attorney for legal guidance.',
          ),
          const SizedBox(height: AppSpacing.md),
          _AboutItem(
            icon: Icons.code_rounded,
            title: 'Version',
            description: '1.0.0',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color foregroundColor;

    if (isPrimary) {
      backgroundColor = colorScheme.primary;
      foregroundColor = colorScheme.onPrimary;
    } else if (isDestructive) {
      backgroundColor = colorScheme.error.withValues(alpha: 0.1);
      foregroundColor = colorScheme.error;
    } else {
      backgroundColor = colorScheme.surface;
      foregroundColor = colorScheme.onSurface;
    }

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foregroundColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: context.textStyles.labelMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _AboutItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyles.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: context.textStyles.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
