import 'dart:convert';

class EntityModel {
  final String entity;
  final String type;
  final int start;
  final int end;

  EntityModel({
    required this.entity,
    required this.type,
    required this.start,
    required this.end,
  });

  factory EntityModel.fromJson(Map<String, dynamic> json) {
    return EntityModel(
      entity: json['entity'] as String? ?? '',
      type: json['type'] as String? ?? '',
      start: json['start'] as int? ?? 0,
      end: json['end'] as int? ?? 0,
    );
  }
}

class Icd10DiagnosticModel {
  final String code;
  final double probability;

  Icd10DiagnosticModel({
    required this.code,
    required this.probability,
  });

  factory Icd10DiagnosticModel.fromJson(Map<String, dynamic> json) {
    return Icd10DiagnosticModel(
      code: json['code'] as String? ?? '',
      probability: (json['probability'] is num) ? (json['probability'] as num).toDouble() : 0.0,
    );
  }
}

class AnalyzeResultModel {
  final int analysisId;
  final String? filePath;
  final String text;
  final List<EntityModel> entities;
  final List<Icd10DiagnosticModel> icd10Diagnostics;
  final String status;
  final String client;
  final String rawResponse;

  AnalyzeResultModel({
    required this.analysisId,
    this.filePath,
    required this.text,
    required this.entities,
    required this.icd10Diagnostics,
    required this.status,
    required this.client,
    required this.rawResponse,
  });

  factory AnalyzeResultModel.fromJson(Map<String, dynamic> json) {
    final analysisId = json['analysisId'] as int? ?? 0;
    final filePath = json['filePath'] as String?;
    final rawResponse = json['response'] as String? ?? '';

    String text = '';
    List<EntityModel> entities = [];
    List<Icd10DiagnosticModel> icd10Diagnostics = [];
    String status = '';
    String client = '';

    if (rawResponse.isNotEmpty) {
      try {
        final Map<String, dynamic> parsedResponse = Map<String, dynamic>.from(jsonDecode(rawResponse));
        text = parsedResponse['text'] as String? ?? '';
        status = parsedResponse['status'] as String? ?? '';
        client = parsedResponse['client'] as String? ?? '';

        final rawEntities = parsedResponse['entities'];
        if (rawEntities is List) {
          entities = rawEntities.map((e) => EntityModel.fromJson(Map<String, dynamic>.from(e))).toList();
        }

        final rawDiagnostics = parsedResponse['icd10_diagnostics'] ?? parsedResponse['icd10Diagnostics'];
        if (rawDiagnostics is List) {
          icd10Diagnostics = rawDiagnostics.map((e) => Icd10DiagnosticModel.fromJson(Map<String, dynamic>.from(e))).toList();
        }
      } catch (_) {
        // Fallback for non-JSON content
        text = rawResponse;
      }
    }

    return AnalyzeResultModel(
      analysisId: analysisId,
      filePath: filePath,
      text: text,
      entities: entities,
      icd10Diagnostics: icd10Diagnostics,
      status: status,
      client: client,
      rawResponse: rawResponse,
    );
  }
}
