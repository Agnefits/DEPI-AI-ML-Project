class ClassificationResultModel {
  final int analysisId;
  final String label;
  final double confidence;
  final List<String> detectedLabels;
  final Map<String, double> probabilities;
  final Map<String, int> predictions;
  final String? gridcam;
  final String details;
  final double processingTime;

  ClassificationResultModel({
    required this.analysisId,
    required this.label,
    required this.confidence,
    required this.detectedLabels,
    required this.probabilities,
    required this.predictions,
    this.gridcam,
    required this.details,
    required this.processingTime,
  });

  factory ClassificationResultModel.fromJson(Map<String, dynamic> json) {
    // Probabilities map
    final rawProbabilities = json['probabilities'];
    final Map<String, double> probs = {};
    if (rawProbabilities is Map) {
      rawProbabilities.forEach((key, value) {
        probs[key.toString()] = (value is num) ? value.toDouble() : 0.0;
      });
    }

    // Predictions map
    final rawPredictions = json['predictions'];
    final Map<String, int> preds = {};
    if (rawPredictions is Map) {
      rawPredictions.forEach((key, value) {
        preds[key.toString()] = (value is num) ? value.toInt() : 0;
      });
    }

    // DetectedLabels list
    final rawDetected = json['detectedLabels'] ?? json['detected_labels'];
    final List<String> detected = [];
    if (rawDetected is List) {
      for (var element in rawDetected) {
        detected.add(element.toString());
      }
    }

    return ClassificationResultModel(
      analysisId: json['analysisId'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      confidence: (json['confidence'] is num) ? (json['confidence'] as num).toDouble() : 0.0,
      detectedLabels: detected,
      probabilities: probs,
      predictions: preds,
      gridcam: json['gridcam'] as String?,
      details: json['details'] as String? ?? '',
      processingTime: (json['processingTime'] is num) ? (json['processingTime'] as num).toDouble() : 0.0,
    );
  }
}
