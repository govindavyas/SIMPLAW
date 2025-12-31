import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simplaw/models/document_analysis.dart';
import 'package:simplaw/services/app_settings_service.dart';

class ElevenLabsService {
  static const baseUrl = 'https://api.elevenlabs.io/v1';
  final AppSettingsService _settings = AppSettingsService();

  // Default English-only voices mapped by tone. Used when language is English.
  final Map<VoiceTone, String> _voiceIds = {
    VoiceTone.calm: 'EXAVITQu4vr4xnSDxMaL', // Sarah - calm and reassuring
    VoiceTone.professional: 'pNInz6obpgDQGcFmaJgB', // Adam - professional and clear
    VoiceTone.friendly: 'cgSgspJ2msm6clMCkdW9', // Jessica - friendly and warm
  };

  /// Preferred models (newer free-tier compatible first), then fallbacks.
  /// We try them in order if the server responds with a model deprecation error.
  static const List<String> _modelPreference = [
    'eleven_turbo_v2',
    'eleven_multilingual_v2',
  ];

  // Cache discovered voices for specific languages within app lifetime.
  final Map<String, String> _languageVoiceCache = {};

  // Keywords used to detect language-capable voices from ElevenLabs /v1/voices payload
  // We search name, description, and labels for these markers.
  static const Map<String, List<String>> _languageKeywords = {
    'Hindi': ['hindi', 'hindustani', 'hinglish', 'india', 'bharat', 'hi-in', 'hi_in', '🇮🇳'],
    'Marathi': ['marathi', 'मराठी', 'mr-in', 'mr_in', 'maharashtra'],
    'Gujarati': ['gujarati', 'ગુજરાતી', 'gu-in', 'gu_in'],
    'Punjabi': ['punjabi', 'ਪੰਜਾਬੀ', 'panjabi', 'pa-in', 'pa_in'],
    'English': ['english', 'en', 'us', 'uk'],
  };

  /// Quick key verification against ElevenLabs /v1/user endpoint.
  /// Returns true if the key is valid; logs subscription info if available.
  Future<bool> verifyKey({String? overrideRawKey}) async {
    try {
      final rawKey = overrideRawKey ?? await _settings.resolveElevenLabsApiKeyOrDefault();
      final apiKey = _settings.sanitizeKeyForHeaders(rawKey);
      if (apiKey.isEmpty) {
        debugPrint('verifyKey: No ElevenLabs key provided.');
        return false;
      }
      final url = Uri.parse('$baseUrl/user');
      final res = await http.get(url, headers: {
        'Accept': 'application/json',
        'xi-api-key': apiKey,
      });
      if (res.statusCode == 200) {
        try {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final sub = json['subscription'] as Map<String, dynamic>?;
          final tier = sub != null ? (sub['tier']?.toString() ?? 'unknown') : 'unknown';
          debugPrint('ElevenLabs key verified. Subscription tier: $tier');
        } catch (_) {}
        return true;
      }
      debugPrint('verifyKey failed: ${res.statusCode} - ${res.body}');
      return false;
    } catch (e) {
      debugPrint('verifyKey error: $e');
      return false;
    }
  }

  Future<String?> generateVoice({
    required String text,
    required VoiceTone voiceTone,
    required String language, // Human-readable: e.g., 'Hindi', 'Marathi', 'English'
  }) async {
    final rawKey = await _settings.resolveElevenLabsApiKeyOrDefault();
    final apiKey = _settings.sanitizeKeyForHeaders(rawKey);
    if (apiKey.isEmpty) {
      debugPrint('ElevenLabs API key not configured (no saved key and no default)');
      return null;
    }

    try {
      // Determine voiceId based on requested explanation language.
      // - For English, keep using tone-specific defaults
      // - For Indian languages, pick a native or multilingual-trained voice explicitly
      // - If not available, MANDATORY SILENT FALLBACK to Hindi voice
      String? voiceId;
      final lang = language.trim();
      if (lang.toLowerCase() == 'english') {
        voiceId = _voiceIds[voiceTone] ?? _voiceIds[VoiceTone.calm]!;
      } else {
        voiceId = await _resolveVoiceIdForLanguage(lang, apiKey: apiKey);
        if (voiceId == null) {
          // Silent fallback mapping for Indian languages to Hindi
          final lower = lang.toLowerCase();
          if (lower == 'marathi' || lower == 'punjabi' || lower == 'gujarati') {
            debugPrint('TTS fallback: Using Hindi voice for "$lang" (no native voice).');
            final hindiId = await _resolveVoiceIdForLanguage('Hindi', apiKey: apiKey);
            if (hindiId != null) {
              voiceId = hindiId;
            } else {
              // As last resort, avoid failure by using calm English voice
              debugPrint('TTS fallback: No Hindi voice found. Using English calm voice as final fallback.');
              voiceId = _voiceIds[VoiceTone.calm]!;
            }
          } else {
            // Try a generic multilingual voice before giving up
            final multiId = await _resolveVoiceIdForLanguage('multilingual', apiKey: apiKey);
            if (multiId != null) {
              debugPrint('TTS fallback: Using a multilingual voice for "$lang".');
              voiceId = multiId;
            } else {
              // Final fallback to English calm to ensure audio always plays
              debugPrint('TTS fallback: No suitable voice found. Using English calm voice.');
              voiceId = _voiceIds[VoiceTone.calm]!;
            }
          }
        }
      }

      final url = Uri.parse('$baseUrl/text-to-speech/$voiceId');

      http.Response? response;
      String? usedModel;
      final models = _modelsForLanguage(lang);
      for (final model in models) {
        usedModel = model;
        response = await http.post(
          url,
          headers: {
            'Accept': 'audio/mpeg',
            'Content-Type': 'application/json',
            'xi-api-key': apiKey,
          },
          body: jsonEncode({
            'text': text,
            'model_id': model,
            // Explicit output format to ensure stable decoding across platforms.
            'output_format': 'mp3_44100_128',
            'voice_settings': {
              // Keep tone soft, clear, and instructional.
              // You can tune these per VoiceTone if needed in the future.
              'stability': voiceTone == VoiceTone.calm ? 0.45 : (voiceTone == VoiceTone.friendly ? 0.55 : 0.6),
              'similarity_boost': 0.75,
            }
          }),
        );

        // 200 OK -> break; 4xx with model_deprecated_free_tier -> try next model
        if (response.statusCode == 200) break;

        // Inspect body for model-specific errors and fall back
        final body = response.body;
        try {
          final parsed = jsonDecode(body) as Map<String, dynamic>;
          final detail = parsed['detail'];
          final status = detail is Map<String, dynamic> ? (detail['status'] as String?) : null;
          if (status != null && status.contains('model_deprecated')) {
            debugPrint('Model $model not allowed: $status. Trying next model...');
            continue;
          }
        } catch (_) {
          // Non-JSON or unexpected, proceed to handle as error below
        }
        break; // Different error; stop retrying
      }

      if (response == null) return null;

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (kIsWeb) {
          // On web, return a base64 data URL so the audio player can use UrlSource
          final b64 = base64Encode(bytes);
          final dataUrl = 'data:audio/mpeg;base64,$b64';
          debugPrint('ElevenLabs audio generated using model: $usedModel (web data URL)');
          return dataUrl;
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${directory.path}/audio_$timestamp.mp3';
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          debugPrint('ElevenLabs audio saved to: $filePath using model: $usedModel');
          return filePath;
        }
      } else {
        // Try to log a concise message
        String reason = response.body;
        try {
          final parsed = jsonDecode(response.body);
          reason = jsonEncode(parsed);
        } catch (_) {}
        debugPrint('ElevenLabs API error (model: $usedModel): ${response.statusCode} - $reason');
        return null;
      }
    } catch (e) {
      debugPrint('Error generating voice: $e');
      return null;
    }
  }

  /// Returns a preferred model order for a given language.
  /// For non-English languages we prefer the multilingual model first to avoid accent issues.
  List<String> _modelsForLanguage(String lang) {
    if (lang.toLowerCase() == 'english') return _modelPreference;
    return const ['eleven_multilingual_v2', 'eleven_turbo_v2'];
  }

  /// Resolve a language-appropriate voice id.
  /// Strategy:
  /// 1) Use cached/persisted mapping if present
  /// 2) Query /v1/voices and pick a native or multilingual-trained voice using language keywords
  /// 3) If none found, return null (never fallback to English silently)
  Future<String?> _resolveVoiceIdForLanguage(String language, {required String apiKey}) async {
    final lang = language.trim();
    // 1) Check in-memory cache
    if (_languageVoiceCache.containsKey(lang)) return _languageVoiceCache[lang];

    // 2) Check persisted mapping (allows advanced users to set exact voice ids)
    try {
      final persisted = await _settings.getVoiceIdForLanguage(lang);
      if (persisted != null && persisted.isNotEmpty) {
        _languageVoiceCache[lang] = persisted;
        debugPrint('Using persisted voice for "$lang": $persisted');
        return persisted;
      }
    } catch (_) {}

    try {
      final url = Uri.parse('$baseUrl/voices');
      final res = await http.get(url, headers: {
        'Accept': 'application/json',
        'xi-api-key': apiKey,
      });
      if (res.statusCode != 200) {
        debugPrint('Failed to fetch voices (${res.statusCode}). Body: ${res.body}');
        return null;
      }

      final payload = jsonDecode(res.body) as Map<String, dynamic>;
      final voices = (payload['voices'] as List?)?.cast<dynamic>() ?? const [];

      final lowerLang = lang.toLowerCase();
      final keywords = _languageKeywords.entries
          .firstWhere((e) => e.key.toLowerCase() == lowerLang, orElse: () => const MapEntry('Unknown', []))
          .value;

      String? bestVoiceId;
      String? bestVoiceName;

      bool matchesLanguage(Map<String, dynamic> v) {
        final name = (v['name'] ?? '').toString().toLowerCase();
        final desc = (v['description'] ?? '').toString().toLowerCase();
        final labels = (v['labels'] is Map<String, dynamic>) ? (v['labels'] as Map<String, dynamic>) : const {};
        final labelsStr = labels.entries.map((e) => '${e.key}:${e.value}').join(' ').toLowerCase();

        // If specific keywords exist for the language, require a match.
        if (keywords.isNotEmpty) {
          for (final k in keywords) {
            final lk = k.toLowerCase();
            if (name.contains(lk) || desc.contains(lk) || labelsStr.contains(lk)) return true;
          }
          return false;
        }

        // Otherwise, prefer any multilingual indicator for unknown languages
        return name.contains('multilingual') || desc.contains('multilingual') || labelsStr.contains('multi');
      }

      // 2a) Try strict match for the target language
      for (final v in voices) {
        final vm = (v as Map).cast<String, dynamic>();
        if (matchesLanguage(vm)) {
          bestVoiceId = vm['voice_id']?.toString();
          bestVoiceName = vm['name']?.toString();
          break;
        }
      }

      // 2b) If not found, try any explicitly multilingual voice as a controlled fallback
      if (bestVoiceId == null) {
        for (final v in voices) {
          final vm = (v as Map).cast<String, dynamic>();
          final name = (vm['name'] ?? '').toString().toLowerCase();
          final desc = (vm['description'] ?? '').toString().toLowerCase();
          final labels = (vm['labels'] is Map<String, dynamic>) ? (vm['labels'] as Map<String, dynamic>) : const {};
          final labelsStr = labels.entries.map((e) => '${e.key}:${e.value}').join(' ').toLowerCase();
          if (name.contains('multilingual') || desc.contains('multilingual') || labelsStr.contains('multi')) {
            bestVoiceId = vm['voice_id']?.toString();
            bestVoiceName = vm['name']?.toString();
            break;
          }
        }
      }

      if (bestVoiceId != null) {
        _languageVoiceCache[lang] = bestVoiceId!;
        debugPrint('Selected ${bestVoiceName ?? 'voice'} for "$lang" (id=$bestVoiceId).');
        return bestVoiceId;
      }

      debugPrint('No suitable voice found for "$lang" (no native or multilingual voice detected).');
      return null;
    } catch (e) {
      debugPrint('Error resolving voice for "$lang": $e');
      return null;
    }
  }
}
