import 'package:equatable/equatable.dart';
import '../../domain/entities/subscription_entity.dart';

abstract class SubscriptionsState extends Equatable {
  const SubscriptionsState();

  @override
  List<Object?> get props => [];
}

class SubscriptionsInitial extends SubscriptionsState {}

class SubscriptionsLoading extends SubscriptionsState {}

class SubscriptionsLoaded extends SubscriptionsState {
  final List<SubscriptionEntity> subscriptions;

  const SubscriptionsLoaded(this.subscriptions);

  @override
  List<Object?> get props => [subscriptions];
}

class SubscriptionDetailsLoaded extends SubscriptionsState {
  final SubscriptionEntity subscription;

  const SubscriptionDetailsLoaded(this.subscription);

  @override
  List<Object?> get props => [subscription];
}

class SubscriptionCancelledSuccess extends SubscriptionsState {}

class SubscriptionsError extends SubscriptionsState {
  final String message;

  const SubscriptionsError(this.message);

  @override
  List<Object?> get props => [message];
}
