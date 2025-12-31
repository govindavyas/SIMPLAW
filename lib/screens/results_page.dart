import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:simplaw/theme.dart';
import 'package:simplaw/models/document_analysis.dart';
import 'package:simplaw/openai/openai_config.dart';
import 'package:simplaw/services/elevenlabs_service.dart';
import 'package:simplaw/services/document_analysis_service.dart';
import 'package:simplaw/components/custom_audio_player.dart';
import 'package:simplaw/components/explanation_card.dart';
import 'package:simplaw/components/disclaimer_banner.dart';
import 'package:simplaw/components/minimal_header.dart';
import 'package:simplaw/services/app_settings_service.dart';
import 'package:flutter/foundation.dart';

class ResultsPage extends StatefulWidget {
  final String? documentText;
  final String? fileName;
  final Uint8List? fileBytes;
  final String language;
  final VoiceTone voiceTone;

  const ResultsPage({
    super.key,
    this.documentText,
    this.fileName,
    this.fileBytes,
    required this.language,
    required this.voiceTone,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final OpenAIService _openAIService = OpenAIService();
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  final DocumentAnalysisService _analysisService = DocumentAnalysisService();

  bool _isAnalyzing = true;
  bool _isGeneratingAudio = false;
  DocumentAnalysis? _analysis;
  String? _errorMessage;
  bool _shownConfigDialog = false;

  @override
  void initState() {
    super.initState();
    _performAnalysis();
  }

  Future<void> _performAnalysis() async {
    try {
      setState(() {
        _isAnalyzing = true;
        _errorMessage = null;
      });

      Map<String, dynamic> analysisResult;
      String originalRef;
      if (widget.fileBytes != null && widget.fileBytes!.isNotEmpty) {
        debugPrint('Starting background PDF/TXT analysis for: ${widget.fileName ?? 'file'}');
        final parsed = await _analysisService.extractAndSummarizeFromBytes(
          bytes: widget.fileBytes!,
          fileName: widget.fileName ?? 'document.pdf',
          language: widget.language,
          voiceTone: widget.voiceTone.name,
        );
        analysisResult = parsed;
        originalRef = 'Uploaded file: ${widget.fileName ?? 'document'} (content not displayed)';
      } else {
        // Fallback to direct text analysis
        final safeText = widget.documentText?.trim() ?? '';
        analysisResult = await _openAIService.analyzeDocument(
          documentText: safeText,
          language: widget.language,
          voiceTone: widget.voiceTone.name,
        );
        originalRef = safeText;
      }

      final now = DateTime.now();
      final analysis = DocumentAnalysis(
        id: const Uuid().v4(),
        userId: 'default_user',
        originalText: originalRef,
        documentType: analysisResult['documentType'] as String,
        simpleExplanation: analysisResult['simpleExplanation'] as String,
        actionRequired: analysisResult['actionRequired'] as bool,
        deadline: analysisResult['deadline'] as String?,
        riskLevel: _parseRiskLevel(analysisResult['riskLevel'] as String),
        suggestedNextStep: analysisResult['suggestedNextStep'] as String,
        language: widget.language,
        voiceTone: widget.voiceTone,
        createdAt: now,
        updatedAt: now,
      );

      setState(() {
        _analysis = analysis;
        _isAnalyzing = false;
      });

      _generateVoiceNarration(analysis);
    } catch (e) {
      debugPrint('Analysis error: $e');
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Failed to analyze document. Please check your internet connection and try again.';
      });
    }
  }

  Future<void> _generateVoiceNarration(DocumentAnalysis analysis) async {
    try {
      setState(() => _isGeneratingAudio = true);

      final narrationScript = await _openAIService.generateNarrationScript(
        documentType: analysis.documentType,
        simpleExplanation: analysis.simpleExplanation,
        actionRequired: analysis.actionRequired,
        deadline: analysis.deadline,
        riskLevel: analysis.riskLevel.name,
        suggestedNextStep: analysis.suggestedNextStep,
        language: widget.language,
      );

      final audioPath = await _elevenLabsService.generateVoice(
        text: narrationScript,
        voiceTone: widget.voiceTone,
        language: widget.language,
      );

      final updatedAnalysis = analysis.copyWith(
        voiceScript: narrationScript,
        audioUrl: audioPath,
        updatedAt: DateTime.now(),
      );
      // Update UI first so audio is available even if persistence fails
      setState(() => _analysis = updatedAnalysis);
      try {
        await _analysisService.saveAnalysis(updatedAnalysis);
      } catch (e) {
        // Defensive: saveAnalysis already swallows, but keep guard in case of future changes
        debugPrint('Non-fatal: could not persist updated analysis: $e');
      }

      // If audio failed due to missing configuration, surface a helpful dialog
      if (audioPath == null) {
        final key = await AppSettingsService().resolveElevenLabsApiKeyOrDefault();
        if (mounted && key.trim().isEmpty) {
          _maybeShowMissingConfigDialog();
        }
      }
    } catch (e) {
      debugPrint('Voice generation error: $e');
    } finally {
      setState(() => _isGeneratingAudio = false);
    }
  }

  void _maybeShowMissingConfigDialog() {
    if (_shownConfigDialog) return;
    _shownConfigDialog = true;
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
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
                  Icon(Icons.volume_off_rounded, color: colorScheme.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Voice narration needs setup',
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
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'To play the explanation out loud, add your ElevenLabs API key in Settings. We\'ll match the voice to your explanation language for natural pronunciation.',
                style: context.textStyles.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.pop();
                        context.push('/settings');
                      },
                      icon: Icon(Icons.settings_rounded, color: colorScheme.onPrimary),
                      label: Text('Open Settings', style: context.textStyles.labelLarge?.copyWith(color: colorScheme.onPrimary)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  RiskLevel _parseRiskLevel(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return RiskLevel.high;
      case 'medium':
        return RiskLevel.medium;
      case 'low':
      default:
        return RiskLevel.low;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isAnalyzing
            ? _buildLoadingState()
            : _errorMessage != null
                ? _buildErrorState()
                : _buildResultsState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Analyzing your document...',
            style: context.textStyles.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This may take a few moments',
            style: context.textStyles.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Analysis Failed',
              style: context.textStyles.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _performAnalysis,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsState() {
    if (_analysis == null) return const SizedBox();

    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MinimalHeader(),
          const SizedBox(height: AppSpacing.md),
          if (_analysis!.audioUrl != null)
            CustomAudioPlayer(audioPath: _analysis!.audioUrl!)
          else if (_isGeneratingAudio)
            _buildAudioGeneratingCard()
          else
            _buildAudioUnavailableCard(),
          const SizedBox(height: AppSpacing.xl),
          ExplanationCard(analysis: _analysis!),
          const SizedBox(height: AppSpacing.xl),
          const DisclaimerBanner(),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
            label: const Text('Analyze Another Document'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildAudioGeneratingCard() {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Generating voice narration...',
              style: context.textStyles.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioUnavailableCard() {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Icon(Icons.volume_off_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'Voice narration is currently unavailable',
            style: context.textStyles.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: () => context.push('/settings'),
          child: const Text('Configure'),
        ),
      ]),
    );
  }
}
