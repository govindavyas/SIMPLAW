import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OpenAIService {
  static const apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
  static const endpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT');

  Future<Map<String, dynamic>> analyzeDocument({
    required String documentText,
    required String language,
    required String voiceTone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': '''You are SIMPLAW, a responsible document‑explanation system. You explain legal, financial, or bureaucratic documents clearly and calmly. You do NOT provide legal advice.

GENERAL RULES
- Never sound threatening, alarmist, or bureaucratic
- Prefer short, simple sentences
- One idea per sentence
- Use neutral, reassuring language
- Avoid repeating the document’s formal wording
- Do not speculate beyond what is explicitly stated
- Do not exaggerate consequences

OUTPUT STRUCTURE (MANDATORY)
Return a JSON object with these exact fields:
{
  "documentType": "string",
  "simpleExplanation": "string",
  "actionRequired": boolean,
  "deadline": "string or null",
  "riskLevel": "low" | "medium" | "high",
  "suggestedNextStep": "string"
}

RISK CLASSIFICATION RULES
- LOW: Informational notices, policy updates, confirmations, no deadlines or consequences
- MEDIUM: Payment reminders, warnings, deadlines, conditional consequences using words like "may", "could", "might", "reserves the right"
- HIGH: Explicit legal action, final demand, court proceedings, enforcement notices, or language such as "will initiate", "legal action has begun", "non‑compliance will result"
- Never classify a document as HIGH unless legal action is clearly stated.

TONE RULES FOR simpleExplanation
- Start with what the document is about in one sentence
- Clearly state whether the user needs to act
- Clearly state whether this is urgent or routine
- Include one reassuring sentence if no legal action has started (e.g., "This is a common reminder and does not mean any legal action has started.")

DEADLINE RULES
- If no explicit deadline is stated in the document, set deadline to null (we will display "No clear deadline mentioned").

PROHIBITIONS
- No legal advice
- No fear‑based language
- No assumptions about intent
- No over‑classification of risk
- No repeating long sentences from the original document

 LANGUAGE & TRANSLATION
 - Automatically detect the language of the user's input. The input may be in ANY language.
 - Understand the content regardless of the original language or script.
 - Produce the final explanation in $language, accurately preserving meaning.
 - If quoting or naming terms, translate or paraphrase so the output stays in $language.
 - Tone style: $voiceTone.
'''
            },
            {
              'role': 'user',
              'content': 'Please analyze this document:\n\n$documentText'
            }
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];
        try {
          final parsed = jsonDecode(content) as Map<String, dynamic>;
          return _sanitizeAnalysisJson(parsed);
        } catch (e) {
          debugPrint('Malformed JSON from OpenAI. Attempting recovery: $e');
          return _sanitizeAnalysisJson({
            'documentType': 'Document',
            'simpleExplanation': content.toString(),
            'actionRequired': false,
            'deadline': null,
            'riskLevel': 'low',
            'suggestedNextStep': 'You may want to keep a copy and monitor for updates.'
          });
        }
      } else {
        debugPrint('OpenAI API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to analyze document: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling OpenAI: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeDocumentFromChunks({
    required List<String> chunks,
    required String language,
    required String voiceTone,
  }) async {
    try {
      final joined = chunks.asMap().entries.map((e) => '[CHUNK ${e.key + 1}]\n${e.value}').join('\n\n');
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': '''You are SIMPLAW, a responsible document‑explanation system. You explain legal, financial, or bureaucratic documents clearly and calmly. You do NOT provide legal advice.

INPUT FORMAT
- The user's document was processed from a file and may be chunked and truncated for speed.
- Read all chunks and infer the core purpose and obligations. If content is truncated, still produce a careful, conservative summary.

OUTPUT STRUCTURE (MANDATORY)
Return a JSON object with these exact fields:
{
  "documentType": "string",
  "simpleExplanation": "string",
  "actionRequired": boolean,
  "deadline": "string or null",
  "riskLevel": "low" | "medium" | "high",
  "suggestedNextStep": "string"
}

LANGUAGE & TONE
- Produce the final explanation in $language.
- Tone style: $voiceTone (calm, short sentences).
'''
            },
            {
              'role': 'user',
              'content': 'Analyze this document from chunked text (may be partial):\n\n$joined'
            }
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.6,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];
        try {
          final parsed = jsonDecode(content) as Map<String, dynamic>;
          return _sanitizeAnalysisJson(parsed);
        } catch (e) {
          debugPrint('Malformed JSON (chunks). Attempting recovery: $e');
          return _sanitizeAnalysisJson({
            'documentType': 'Document',
            'simpleExplanation': content.toString(),
            'actionRequired': false,
            'deadline': null,
            'riskLevel': 'low',
            'suggestedNextStep': 'You may want to keep a copy and monitor for updates.'
          });
        }
      } else {
        debugPrint('OpenAI API error (chunks): ${response.statusCode} - ${response.body}');
        throw Exception('Failed to analyze document (chunks): ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error calling OpenAI (chunks): $e');
      rethrow;
    }
  }

  Future<String> generateNarrationScript({
    required String documentType,
    required String simpleExplanation,
    required bool actionRequired,
    required String? deadline,
    required String riskLevel,
    required String suggestedNextStep,
    required String language,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': '''Create a 20–45 second voice narration for SIMPLAW.

VOICE OUTPUT RULES
- Calm, steady, and reassuring
- Free of legal or technical jargon
- Not a warning or demand
- Short sentences. One idea per sentence.
- Exactly one paragraph (no line breaks)
- Start with what the document is about (e.g., "This is a [document type]...")
- State if action is needed and if it is routine or urgent
- If no legal action has started, include a gentle reassurance like: "This is a common reminder and does not mean any legal action has started."
 - Write in $language. If the source analysis is in a different language, translate faithfully to $language.
'''
            },
            {
              'role': 'user',
              'content': '''Create a narration script from this analysis:

Document Type: $documentType
Explanation: $simpleExplanation
Action Required: ${actionRequired ? "Yes" : "No"}
Deadline: ${deadline ?? "None"}
Risk Level: $riskLevel
Next Step: $suggestedNextStep'''
            }
          ],
          'temperature': 0.5,
          'max_tokens': 320,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] as String;
      } else {
        debugPrint('OpenAI API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate narration: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error generating narration: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _sanitizeAnalysisJson(Map<String, dynamic> raw) {
    String _asString(dynamic v, {String fallback = ''}) => v is String ? v : fallback;
    bool _asBool(dynamic v, {bool fallback = false}) => v is bool ? v : fallback;

    final docType = _asString(raw['documentType'], fallback: 'Document');
    final explanation = _asString(raw['simpleExplanation'], fallback: 'A clear summary is unavailable.');
    final action = _asBool(raw['actionRequired'], fallback: false);
    final deadline = raw['deadline'] is String ? raw['deadline'] as String : null;
    final risk = _asString(raw['riskLevel'], fallback: 'low').toLowerCase();
    final next = _asString(raw['suggestedNextStep'], fallback: 'You may want to keep a copy and monitor for updates.');

    final normalizedRisk = (risk == 'high' || risk == 'medium' || risk == 'low') ? risk : 'low';

    return {
      'documentType': docType,
      'simpleExplanation': explanation,
      'actionRequired': action,
      'deadline': deadline,
      'riskLevel': normalizedRisk,
      'suggestedNextStep': next,
    };
  }
}
