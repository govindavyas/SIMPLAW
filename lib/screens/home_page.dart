import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:simplaw/theme.dart';
import 'package:simplaw/models/document_analysis.dart';
import 'package:simplaw/components/disclaimer_banner.dart';
import 'package:simplaw/services/app_settings_service.dart';
import 'package:simplaw/components/minimal_header.dart';
import 'package:flutter/scheduler.dart';
import 'package:simplaw/components/glass_card.dart';
import 'package:simplaw/components/language_grid_selector.dart';
import 'package:simplaw/components/upload_drop_zone.dart';
import 'package:simplaw/components/voice_tone_selector.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  String _selectedLanguage = 'English';
  VoiceTone _selectedVoiceTone = VoiceTone.calm;
  bool _isFileFlowBusy = false;
  late TabController _tabController;
  int _tabIndex = 0;
  final _settings = AppSettingsService();
  bool _voiceConfigured = true;

  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Portuguese',
    'Arabic',
    'Chinese',
    'Japanese',
    // Indian languages (extension only)
    'Hindi',
    'Marathi',
    'Gujarati',
    'Punjabi',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      final newIndex = _tabController.index;
      if (_tabIndex != newIndex) setState(() => _tabIndex = newIndex);
    });
    // Load preferred explanation language (persisted)
    _loadPreferredLanguage();
    _checkVoiceSetup();
  }

  @override
  void dispose() {
    _textController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferredLanguage() async {
    try {
      final saved = await _settings.getPreferredLanguage();
      if (!mounted) return;
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          if (!_languages.contains(saved)) {
            // Keep existing options intact; temporarily include saved so user sees it
            _languages.insert(0, saved);
          }
          _selectedLanguage = saved;
        });
      }
    } catch (e) {
      // Non-fatal; default remains English
    }
  }

  Future<void> _checkVoiceSetup() async {
    try {
      final key = await _settings.resolveElevenLabsApiKeyOrDefault();
      if (!mounted) return;
      setState(() => _voiceConfigured = key.trim().isNotEmpty);
    } catch (e) {
      if (!mounted) return;
      setState(() => _voiceConfigured = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      if (_isFileFlowBusy) return;
      setState(() => _isFileFlowBusy = true);

      // Ensure the inline loader paints BEFORE the platform file picker opens.
      // This prevents the “stuck for a second” perception.
      await SchedulerBinding.instance.endOfFrame;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
        // Always request bytes so we can process in-memory without UI freezes
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final bytes = file.bytes;
        if (bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Could not read file bytes. Please try another file.'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }

        // Do NOT dump file content into the text box. Process silently.
        // Navigate to results to start background analysis immediately.
        if (mounted) {
          await context.push('/results', extra: {
            'fileName': file.name,
            'fileBytes': bytes,
            'language': _selectedLanguage,
            'voiceTone': _selectedVoiceTone,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      // Clear any “selected file” state (we don’t keep one) and ensure the UI
      // reflects reality when user returns from Results.
      if (mounted) setState(() => _isFileFlowBusy = false);
    }
  }

  void _analyzeDocument() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please paste or upload a document first'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    context.push('/results', extra: {
      'documentText': _textController.text.trim(),
      'language': _selectedLanguage,
      'voiceTone': _selectedVoiceTone,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _isFileFlowBusy ? null : _pickFile,
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
              elevation: 0,
              icon: Icon(Icons.upload_file_rounded, color: colorScheme.onSecondary),
              label: Text(
                'Upload',
                style: context.textStyles.labelLarge?.copyWith(color: colorScheme.onSecondary, fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.75),
                colorScheme.surface.withValues(alpha: 0.96),
              ],
            ),
          ),
          child: Column(
            children: [
              const MinimalHeader(padding: EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.lg, right: AppSpacing.lg)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        'Simplify legal documents in seconds',
                        style: context.textStyles.headlineSmall?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload a file or paste text — we’ll explain it clearly and read it out loud.',
                        style: context.textStyles.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildTabSelector(context),
                      const SizedBox(height: AppSpacing.sm),
                      _buildTabContent(context),
                      const SizedBox(height: AppSpacing.md),
                      if (!_voiceConfigured) ...[
                        _buildVoiceSetupNotice(context),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const DisclaimerBanner(),
                      const SizedBox(height: AppSpacing.md),
                      _buildOptionsSection(context),
                      const SizedBox(height: AppSpacing.lg),
                      if (_tabIndex == 0) _buildAnalyzeButton(context),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceSetupNotice(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.volume_off_rounded, color: colorScheme.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Voice narration needs a quick setup in Settings. You can still analyze text now.',
              style: context.textStyles.bodyMedium?.copyWith(color: colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/settings'),
            child: const Text('Set up'),
          )
        ],
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(16),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: context.textStyles.labelLarge,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note_rounded, size: 20),
                SizedBox(width: 8),
                Text('Paste Text'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file_rounded, size: 20),
                SizedBox(width: 8),
                Text('Upload File'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _tabController.index == 0
              ? _buildTextInputSection(context)
              : _buildFileUploadSection(context),
        );
      },
    );
  }

  Widget _buildTextInputSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      key: const ValueKey('text'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _textController,
            maxLines: 10,
            style: context.textStyles.bodyMedium?.copyWith(color: colorScheme.onSurface, height: 1.6),
            decoration: InputDecoration(
              hintText: 'Paste your legal document, contract, or notice here…',
              hintStyle: context.textStyles.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(AppSpacing.lg),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Supports contracts, notices, court letters, tax documents, and more.',
                style: context.textStyles.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFileUploadSection(BuildContext context) {
    return Column(
      key: const ValueKey('file'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, axisAlignment: -1, child: child),
          ),
          child: _isFileFlowBusy
              ? const _InlineAnalysisLoader(key: ValueKey('inline-loader'))
              : const SizedBox(key: ValueKey('inline-loader-empty')),
        ),
        const SizedBox(height: AppSpacing.sm),
        UploadDropZone(busy: _isFileFlowBusy, onPick: _isFileFlowBusy ? null : _pickFile),
      ],
    );
  }

  Widget _buildOptionsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tune_rounded, color: colorScheme.secondary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Options',
                      style: context.textStyles.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose explanation language and narration tone.',
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
          _buildLanguageSelector(context),
          const SizedBox(height: AppSpacing.lg),
          _buildVoiceToneCards(context),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = <LanguageOption>[
      const LanguageOption(name: 'English', flag: '🇺🇸', icon: Icons.language_rounded),
      const LanguageOption(name: 'Spanish', flag: '🇪🇸', icon: Icons.translate_rounded),
      const LanguageOption(name: 'French', flag: '🇫🇷', icon: Icons.translate_rounded),
      const LanguageOption(name: 'German', flag: '🇩🇪', icon: Icons.translate_rounded),
      const LanguageOption(name: 'Italian', flag: '🇮🇹', icon: Icons.translate_rounded),
      const LanguageOption(name: 'Portuguese', flag: '🇵🇹', icon: Icons.translate_rounded),
      const LanguageOption(name: 'Arabic', flag: '🇸🇦', icon: Icons.translate_rounded),
      const LanguageOption(name: 'Chinese', flag: '🇨🇳', icon: Icons.text_fields_rounded),
      const LanguageOption(name: 'Japanese', flag: '🇯🇵', icon: Icons.text_fields_rounded),
      const LanguageOption(name: 'Hindi', flag: '🇮🇳', icon: Icons.flag_rounded),
      const LanguageOption(name: 'Marathi', flag: '🇮🇳', icon: Icons.flag_rounded),
      const LanguageOption(name: 'Gujarati', flag: '🇮🇳', icon: Icons.flag_rounded),
      const LanguageOption(name: 'Punjabi', flag: '🇮🇳', icon: Icons.flag_rounded),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Explanation Language',
          style: context.textStyles.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'We’ll explain and narrate in your chosen language.',
          style: context.textStyles.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        LanguageGridSelector(
          options: options,
          value: _selectedLanguage,
          onChanged: (value) async {
            if (_isFileFlowBusy) return;
            setState(() => _selectedLanguage = value);
            await _settings.setPreferredLanguage(value);
          },
        ),
      ],
    );
  }

  Widget _buildVoiceToneCards(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const toneOptions = [
      VoiceToneOption(
        tone: VoiceTone.calm,
        title: 'Calm & Reassuring',
        subtitle: 'Gentle, steady, and easy to follow — ideal for stressful notices.',
        icon: Icons.self_improvement_rounded,
      ),
      VoiceToneOption(
        tone: VoiceTone.professional,
        title: 'Professional & Authoritative',
        subtitle: 'Clear, direct, and confident — ideal for contracts and formal language.',
        icon: Icons.gavel_rounded,
      ),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Voice Tone',
          style: context.textStyles.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        VoiceToneSelector(
          options: toneOptions,
          value: _selectedVoiceTone == VoiceTone.friendly ? VoiceTone.calm : _selectedVoiceTone,
          onChanged: (tone) {
            if (_isFileFlowBusy) return;
            setState(() => _selectedVoiceTone = tone);
          },
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ElevatedButton(
      onPressed: _isFileFlowBusy ? null : _analyzeDocument,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 20, color: colorScheme.onSecondary),
          const SizedBox(width: 10),
          Text(
            'Analyze Document',
            style: context.textStyles.labelLarge?.copyWith(
              color: colorScheme.onSecondary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineAnalysisLoader extends StatelessWidget {
  const _InlineAnalysisLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Analyzing your document…',
              style: context.textStyles.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
