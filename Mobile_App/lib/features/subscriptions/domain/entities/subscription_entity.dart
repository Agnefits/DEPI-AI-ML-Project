import 'package:equatable/equatable.dart';

class SubscriptionEntity extends Equatable {
  final String id;
  final String planName;
  final double price;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> features;

  const SubscriptionEntity({
    required this.id,
    required this.planName,
    required this.price,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.features,
  });

  @override
  List<Object?> get props => [
        id,
        planName,
        price,
        status,
        startDate,
        endDate,
        features,
      ];
}
