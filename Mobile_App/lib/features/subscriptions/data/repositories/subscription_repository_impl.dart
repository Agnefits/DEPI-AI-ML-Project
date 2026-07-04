import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../models/subscription_model.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final List<SubscriptionModel> _mockSubscriptions = [
    SubscriptionModel(
      id: 'sub_1',
      planName: 'Premium Health',
      price: 29.99,
      status: 'active',
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now().add(const Duration(days: 335)),
      features: const [
        '24/7 Doctor Consultations',
        'Free Medicine Delivery',
        'Annual Health Checkup',
        'Priority Appointment Booking'
      ],
    ),
    SubscriptionModel(
      id: 'sub_2',
      planName: 'Basic Care',
      price: 9.99,
      status: 'expired',
      startDate: DateTime.now().subtract(const Duration(days: 400)),
      endDate: DateTime.now().subtract(const Duration(days: 35)),
      features: const [
        '5 Free Consultations/month',
        'Discounted Medicines',
      ],
    ),
  ];

  @override
  Future<List<SubscriptionEntity>> getSubscriptions() async {
    await Future.delayed(const Duration(seconds: 1)); 
    return _mockSubscriptions;
  }

  @override
  Future<SubscriptionEntity> getSubscriptionDetails(String id) async {
    await Future.delayed(const Duration(seconds: 1));
    return _mockSubscriptions.firstWhere(
      (sub) => sub.id == id,
      orElse: () => throw Exception('Subscription not found'),
    );
  }

  @override
  Future<bool> cancelSubscription(String id) async {
    await Future.delayed(const Duration(seconds: 1));
    return true; 
  }
}
