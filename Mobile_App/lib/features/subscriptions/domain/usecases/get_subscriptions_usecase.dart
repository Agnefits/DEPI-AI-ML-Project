import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

class GetSubscriptionsUseCase {
  final SubscriptionRepository repository;

  GetSubscriptionsUseCase(this.repository);

  Future<List<SubscriptionEntity>> call() async {
    return await repository.getSubscriptions();
  }
}
