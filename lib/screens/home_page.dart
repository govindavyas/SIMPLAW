import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:simplaw/theme.dart';
import 'package:simplaw/models/document_analysis.dart';
import 'package:simplaw/components/disclaimer_banner.dart';
import 'package:simplaw/services/app_settings_service.dart';
import 'package:simplaw/components/minimal_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  String _selectedLanguage = 'English';
  VoiceTone _selectedVoiceTone = VoiceTone.calm;
  bool _isLoading = false;
  late TabController _tabController;
  final _settings = AppSettingsService();
  bool _voiceConfigured = true;
  String? _selectedFileName;

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
      setState(() => _isLoading = true);
      
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
        setState(() => _selectedFileName = file.name);

        // Navigate to results to start background analysis immediately
        if (mounted) {
          context.push('/results', extra: {
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
      if (mounted) setState(() => _isLoading = false);
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
      body: SafeArea(
        child: Column(
          children: [
            const MinimalHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    if (!_voiceConfigured) _buildVoiceSetupNotice(context),
                    const SizedBox(height: AppSpacing.lg),
                    const DisclaimerBanner(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildTabSelector(context),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTabContent(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildOptionsSection(context),
                    const SizedBox(height: AppSpacing.xl),
                    _buildAnalyzeButton(context),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
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
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
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
        labelStyle: context.textStyles.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
    final colorScheme = Theme.of(context).colorScheme;
    
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
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          child: TextField(
            controller: _textController,
            maxLines: 8,
            style: context.textStyles.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: 'Paste your legal document, contract, or notice here...',
              hintStyle: context.textStyles.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
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
                'Supports legal notices, contracts, tax documents, and more',
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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      key: const ValueKey('file'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _isLoading ? null : _pickFile,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.cloud_upload_outlined,
                          size: 32,
                          color: colorScheme.primary,
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _isLoading ? 'Loading file...' : 'Tap to upload a file',
                  style: context.textStyles.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Supports PDF and TXT files',
                  style: context.textStyles.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_selectedFileName != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Selected: ${_selectedFileName!}',
                    style: context.textStyles.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection(BuildContext context) {
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'We’ll match narration voice to your selected language',
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
          _buildLanguageDropdown(context),
          const SizedBox(height: AppSpacing.lg),
          _buildVoiceToneSelector(context),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
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
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLanguage,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.onSurfaceVariant),
              dropdownColor: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              items: _languages.map((language) {
                return DropdownMenuItem(
                  value: language,
                  child: Text(
                    language,
                    style: context.textStyles.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  setState(() => _selectedLanguage = value);
                  // Persist across sessions (best-effort)
                  await _settings.setPreferredLanguage(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceToneSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
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
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: VoiceTone.values.map((tone) => _buildVoiceToneChip(context, tone)).toList(),
        ),
      ],
    );
  }

  Widget _buildVoiceToneChip(BuildContext context, VoiceTone tone) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedVoiceTone == tone;
    IconData toneIcon;
    switch (tone) {
      case VoiceTone.calm:
        toneIcon = Icons.self_improvement_rounded;
        break;
      case VoiceTone.professional:
        toneIcon = Icons.work_outline_rounded;
        break;
      case VoiceTone.friendly:
        toneIcon = Icons.sentiment_satisfied_alt_rounded;
        break;
    }
    
    return GestureDetector(
      onTap: () => setState(() => _selectedVoiceTone = tone),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 18,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Icon(toneIcon, size: 16, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  tone.displayName,
                  style: context.textStyles.labelLarge?.copyWith(
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                tone.description,
                style: context.textStyles.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ElevatedButton(
      onPressed: _isLoading ? null : _analyzeDocument,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading)
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            )
          else ...[
            Icon(Icons.auto_awesome_rounded, size: 20, color: colorScheme.onPrimary),
            const SizedBox(width: 10),
            Text(
              'Analyze Document',
              style: context.textStyles.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
