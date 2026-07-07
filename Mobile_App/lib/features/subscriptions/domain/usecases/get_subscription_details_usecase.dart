import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

class GetSubscriptionDetailsUseCase {
  final SubscriptionRepository repository;

  GetSubscriptionDetailsUseCase(this.repository);

  Future<SubscriptionEntity> call(String id) async {
    return await repository.getSubscriptionDetails(id);
  }
}
