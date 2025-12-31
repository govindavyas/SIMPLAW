import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized application settings service.
/// Currently manages the ElevenLabs API key.
class AppSettingsService {
  static const String _elevenLabsKeyPref = 'elevenlabs_api_key';
  static const String _preferredLanguagePref = 'preferred_language';
  static const String _languageVoiceMapPrefix = 'language_voice_id_';

  /// Default (compile-time) ElevenLabs API key.
  /// Provide via --dart-define=ELEVENLABS_API_KEY=... if desired.
  static const String defaultElevenLabsKey = String.fromEnvironment('ELEVENLABS_API_KEY');

  /// Returns the saved ElevenLabs API key, or null if absent.
  Future<String?> getElevenLabsApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_elevenLabsKeyPref);
      return (value == null || value.trim().isEmpty) ? null : value.trim();
    } catch (e) {
      debugPrint('Failed to read ElevenLabs API key: $e');
      return null;
    }
  }

  /// Saves the ElevenLabs API key. Empty values clear the setting.
  Future<bool> setElevenLabsApiKey(String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null || value.trim().isEmpty) {
        return await prefs.remove(_elevenLabsKeyPref);
      }
      return await prefs.setString(_elevenLabsKeyPref, value.trim());
    } catch (e) {
      debugPrint('Failed to save ElevenLabs API key: $e');
      return false;
    }
  }

  /// Retrieves a persisted ElevenLabs voice_id mapped to a human-readable language.
  /// Returns null if no mapping is stored.
  Future<String?> getVoiceIdForLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _languageVoiceMapPrefix + language.trim().toLowerCase();
      final value = prefs.getString(key);
      return (value == null || value.trim().isEmpty) ? null : value.trim();
    } catch (e) {
      debugPrint('Failed to read voice id for language "$language": $e');
      return null;
    }
  }

  /// Persists a mapping from language to ElevenLabs voice_id.
  /// Passing null/empty clears the mapping.
  Future<bool> setVoiceIdForLanguage(String language, String? voiceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _languageVoiceMapPrefix + language.trim().toLowerCase();
      if (voiceId == null || voiceId.trim().isEmpty) {
        return await prefs.remove(key);
      }
      return await prefs.setString(key, voiceId.trim());
    } catch (e) {
      debugPrint('Failed to save voice id for language "$language": $e');
      return false;
    }
  }

  /// Resolves a usable ElevenLabs API key.
  /// Priority: User-saved key > compile-time default > empty string.
  Future<String> resolveElevenLabsApiKeyOrDefault() async {
    try {
      final saved = await getElevenLabsApiKey();
      if (saved != null && saved.isNotEmpty) return saved;
    } catch (e) {
      debugPrint('Error resolving saved ElevenLabs key: $e');
    }
    return defaultElevenLabsKey;
  }

  /// Returns the user's preferred explanation language, or null if unset.
  Future<String?> getPreferredLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_preferredLanguagePref);
      return (value == null || value.trim().isEmpty) ? null : value.trim();
    } catch (e) {
      debugPrint('Failed to read preferred language: $e');
      return null;
    }
  }

  /// Saves the user's preferred explanation language. Empty/null clears it.
  Future<bool> setPreferredLanguage(String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null || value.trim().isEmpty) {
        return await prefs.remove(_preferredLanguagePref);
      }
      return await prefs.setString(_preferredLanguagePref, value.trim());
    } catch (e) {
      debugPrint('Failed to save preferred language: $e');
      return false;
    }
  }

  /// Attempts to extract a valid ElevenLabs key if the user pasted a full header,
  /// JSON, curl command, or other noisy content. Then sanitizes for HTTP headers.
  /// This does NOT persist the sanitized value; only for request usage.
  String sanitizeKeyForHeaders(String key) {
    // 1) Trim and normalize quotes/newlines first.
    var v = key.trim();
    const quoteChars = ['"', "'", '“', '”', '‘', '’'];
    bool strippedOnce = true;
    while (v.length >= 2 && strippedOnce) {
      strippedOnce = false;
      for (final q in quoteChars) {
        if (v.startsWith(q) && v.endsWith(q)) {
          v = v.substring(1, v.length - 1).trim();
          strippedOnce = true;
          break;
        }
      }
    }
    // 2) If user pasted common formats, try to extract the token value.
    final candidates = <String?>[
      // xi-api-key: XXXXX
      _firstMatchGroup(v, RegExp(r'xi-api-key\s*[:=]\s*([A-Za-z0-9_\-]{16,})', caseSensitive: false)),
      // Authorization: Bearer XXXXX
      _firstMatchGroup(v, RegExp(r'Authorization\s*:\s*Bearer\s+([A-Za-z0-9\-\._~\+/=]{16,})', caseSensitive: false)),
      // JSON {"api_key":"XXXXX"} or {"api-key":"XXXXX"}
      _firstMatchGroup(v, RegExp(r'"api[_-]?key"\s*:\s*"([^"]{16,})"', caseSensitive: false)),
      // Generic key=XXXXX
      _firstMatchGroup(v, RegExp(r'(?:key|apikey|token)\s*[=:]\s*([A-Za-z0-9_\-]{16,})', caseSensitive: false)),
    ].whereType<String>().toList();

    if (candidates.isNotEmpty) {
      v = candidates.first;
      debugPrint('Extracted ElevenLabs key from pasted content (length ${v.length}).');
    } else if (v.contains('\n') || v.contains(' ') || v.length > 128) {
      // As a last resort, pick the longest plausible token-looking substring.
      final tokenRegex = RegExp(r'[A-Za-z0-9_\-]{16,}');
      final matches = tokenRegex.allMatches(v).map((m) => m.group(0)!).toList();
      if (matches.isNotEmpty) {
        matches.sort((a, b) => b.length.compareTo(a.length));
        v = matches.first;
        debugPrint('Heuristically extracted ElevenLabs key candidate (length ${v.length}).');
      }
    }

    // 3) Remove ASCII control characters.
    v = String.fromCharCodes(v.runes.where((c) => (c >= 0x20 && c != 0x7F)));
    // 4) Keep ASCII only (0x00 - 0x7F). Headers on web may reject non-Latin1.
    final asciiRunes = v.runes.where((c) => c <= 0x7F).toList();
    final sanitized = String.fromCharCodes(asciiRunes);
    if (sanitized != key) {
      debugPrint('Sanitized ElevenLabs key for headers (length ${sanitized.length}).');
    }
    return sanitized;
  }

  /// Cleans a raw pasted value to a likely true API key and returns it.
  /// Use this when saving the value so we persist a clean token.
  String prepareKeyForStorage(String raw) {
    final cleaned = sanitizeKeyForHeaders(raw);
    // If result still looks implausible (e.g., extremely long), don't truncate silently.
    // We keep it but log a hint for debugging.
    if (cleaned.length > 256) {
      debugPrint('Warning: Saved ElevenLabs key length (${cleaned.length}) seems unusually long.');
    }
    return cleaned;
  }

  // Helper: returns first capturing group, or null.
  String? _firstMatchGroup(String input, RegExp re) {
    final m = re.firstMatch(input);
    return m != null && m.groupCount >= 1 ? m.group(1) : null;
  }
}
