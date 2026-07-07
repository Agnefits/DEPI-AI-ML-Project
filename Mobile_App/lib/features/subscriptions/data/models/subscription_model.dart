import '../../domain/entities/subscription_entity.dart';

class SubscriptionModel extends SubscriptionEntity {
  const SubscriptionModel({
    required String id,
    required String planName,
    required double price,
    required String status,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> features,
  }) : super(
          id: id,
          planName: planName,
          price: price,
          status: status,
          startDate: startDate,
          endDate: endDate,
          features: features,
        );

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] ?? '',
      planName: json['planName'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'unknown',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      features: List<String>.from(json['features'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planName': planName,
      'price': price,
      'status': status,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'features': features,
    };
  }
}
