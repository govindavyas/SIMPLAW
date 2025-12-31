class DocumentAnalysis {
  final String id;
  final String userId;
  final String originalText;
  final String documentType;
  final String simpleExplanation;
  final bool actionRequired;
  final String? deadline;
  final RiskLevel riskLevel;
  final String suggestedNextStep;
  final String? audioUrl;
  final String? voiceScript;
  final String language;
  final VoiceTone voiceTone;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentAnalysis({
    required this.id,
    required this.userId,
    required this.originalText,
    required this.documentType,
    required this.simpleExplanation,
    required this.actionRequired,
    this.deadline,
    required this.riskLevel,
    required this.suggestedNextStep,
    this.audioUrl,
    this.voiceScript,
    required this.language,
    required this.voiceTone,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'originalText': originalText,
    'documentType': documentType,
    'simpleExplanation': simpleExplanation,
    'actionRequired': actionRequired,
    'deadline': deadline,
    'riskLevel': riskLevel.name,
    'suggestedNextStep': suggestedNextStep,
    'audioUrl': audioUrl,
    'voiceScript': voiceScript,
    'language': language,
    'voiceTone': voiceTone.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DocumentAnalysis.fromJson(Map<String, dynamic> json) => DocumentAnalysis(
    id: json['id'] as String,
    userId: json['userId'] as String,
    originalText: json['originalText'] as String,
    documentType: json['documentType'] as String,
    simpleExplanation: json['simpleExplanation'] as String,
    actionRequired: json['actionRequired'] as bool,
    deadline: json['deadline'] as String?,
    riskLevel: RiskLevel.values.firstWhere((e) => e.name == json['riskLevel']),
    suggestedNextStep: json['suggestedNextStep'] as String,
    audioUrl: json['audioUrl'] as String?,
    voiceScript: json['voiceScript'] as String?,
    language: json['language'] as String,
    voiceTone: VoiceTone.values.firstWhere((e) => e.name == json['voiceTone']),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  DocumentAnalysis copyWith({
    String? id,
    String? userId,
    String? originalText,
    String? documentType,
    String? simpleExplanation,
    bool? actionRequired,
    String? deadline,
    RiskLevel? riskLevel,
    String? suggestedNextStep,
    String? audioUrl,
    String? voiceScript,
    String? language,
    VoiceTone? voiceTone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DocumentAnalysis(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    originalText: originalText ?? this.originalText,
    documentType: documentType ?? this.documentType,
    simpleExplanation: simpleExplanation ?? this.simpleExplanation,
    actionRequired: actionRequired ?? this.actionRequired,
    deadline: deadline ?? this.deadline,
    riskLevel: riskLevel ?? this.riskLevel,
    suggestedNextStep: suggestedNextStep ?? this.suggestedNextStep,
    audioUrl: audioUrl ?? this.audioUrl,
    voiceScript: voiceScript ?? this.voiceScript,
    language: language ?? this.language,
    voiceTone: voiceTone ?? this.voiceTone,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

enum RiskLevel {
  low,
  medium,
  high;

  String get displayName {
    switch (this) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
    }
  }
}

enum VoiceTone {
  calm,
  professional,
  friendly;

  String get displayName {
    switch (this) {
      case VoiceTone.calm:
        return 'Calm';
      case VoiceTone.professional:
        return 'Professional';
      case VoiceTone.friendly:
        return 'Friendly';
    }
  }

  String get description {
    switch (this) {
      case VoiceTone.calm:
        return 'Reassuring and gentle';
      case VoiceTone.professional:
        return 'Clear and authoritative';
      case VoiceTone.friendly:
        return 'Warm and approachable';
    }
  }
}
