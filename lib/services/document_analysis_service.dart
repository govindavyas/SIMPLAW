import 'dart:convert';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simplaw/models/document_analysis.dart';
import 'package:flutter/foundation.dart';
import 'package:simplaw/openai/openai_config.dart';

class DocumentAnalysisService {
  static const String _storageKey = 'document_analyses';
  static const int _maxChunkChars = 12000; // keep payload small for fast first response

  Future<List<DocumentAnalysis>> getAllAnalyses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString == null) return [];
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .where((json) => json is Map<String, dynamic>)
          .map((json) {
            try {
              return DocumentAnalysis.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              debugPrint('Skipping corrupted analysis entry: $e');
              return null;
            }
          })
          .whereType<DocumentAnalysis>()
          .toList();
    } catch (e) {
      debugPrint('Failed to load analyses: $e');
      return [];
    } finally {
      // Always ensure loading state is reset in calling code
    }
  }

  Future<void> saveAnalysis(DocumentAnalysis analysis) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analyses = await getAllAnalyses();
      analyses.add(analysis);
      
      final jsonString = jsonEncode(analyses.map((a) => a.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Failed to save analysis: $e');
      rethrow;
    }
  }

  Future<DocumentAnalysis?> getAnalysisById(String id) async {
    final analyses = await getAllAnalyses();
    try {
      return analyses.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteAnalysis(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analyses = await getAllAnalyses();
      analyses.removeWhere((a) => a.id == id);
      
      final jsonString = jsonEncode(analyses.map((a) => a.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Failed to delete analysis: $e');
      rethrow;
    }
  }

  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('Failed to clear analyses: $e');
      rethrow;
    }
  }

  // ===================== Ingestion & Background Analysis =====================

  /// Extracts text from PDF bytes (or returns text for .txt) in an isolate, then
  /// performs early summarization using chunking for fast responses.
  Future<Map<String, dynamic>> extractAndSummarizeFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String language,
    required String voiceTone,
  }) async {
    try {
      final lower = fileName.toLowerCase();
      String text;
      if (lower.endsWith('.pdf')) {
        // Heavy PDF parsing in background
        text = await compute(_extractPdfTextIsolate, bytes);
      } else if (lower.endsWith('.txt')) {
        // Lightweight, decode as UTF-8 with fallback
        try {
          text = utf8.decode(bytes, allowMalformed: true);
        } catch (e) {
          debugPrint('TXT decode failed, using latin1: $e');
          text = latin1.decode(bytes, allowInvalid: true);
        }
      } else {
        // Unknown extension: try UTF-8
        text = utf8.decode(bytes, allowMalformed: true);
      }

      final cleaned = _precleanExtracted(text);
      final payload = _earlySummarizationPayload(cleaned);

      final openai = OpenAIService();
      final result = await openai.analyzeDocumentFromChunks(
        chunks: payload,
        language: language,
        voiceTone: voiceTone,
      );
      return result;
    } catch (e) {
      debugPrint('extractAndSummarizeFromBytes error: $e');
      rethrow;
    }
  }
}

// Top-level isolate entry to avoid main thread jank
String _extractPdfTextIsolate(Uint8List bytes) {
  try {
    final doc = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(doc);
    final text = extractor.extractText();
    doc.dispose();
    return text;
  } catch (e) {
    debugPrint('PDF extraction failed in isolate: $e');
    return '';
  }
}

// Lightweight cleanup to reduce tokens before sending to LLM
String _precleanExtracted(String input) {
  var t = input.replaceAll('\u0000', '');
  // Collapse excessive whitespace
  t = t.replaceAll(RegExp(r'[\t\f\r]+'), ' ');
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return t.trim();
}

// Build early summarization chunks: take head and tail slices to capture context
List<String> _earlySummarizationPayload(String text) {
  if (text.isEmpty) return const ['(No extractable text found in the document.)'];
  if (text.length <= DocumentAnalysisService._maxChunkChars) return [text];

  final head = text.substring(0, 9000);
  final tail = text.substring(text.length - 3000);
  return [
    head,
    '[[[ELLIPSIS_CONTENT_TRUNCATED_${text.length}]]] ',
    tail,
  ];
}
