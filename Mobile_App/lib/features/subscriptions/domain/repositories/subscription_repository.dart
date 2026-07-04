import '../entities/subscription_entity.dart';

abstract class SubscriptionRepository {
  Future<List<SubscriptionEntity>> getSubscriptions();
  Future<SubscriptionEntity> getSubscriptionDetails(String id);
  Future<bool> cancelSubscription(String id);
}
