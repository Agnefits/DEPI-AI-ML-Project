import '../repositories/subscription_repository.dart';

class CancelSubscriptionUseCase {
  final SubscriptionRepository repository;

  CancelSubscriptionUseCase(this.repository);

  Future<bool> call(String id) async {
    return await repository.cancelSubscription(id);
  }
}
