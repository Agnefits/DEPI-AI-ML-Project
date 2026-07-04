import 'package:equatable/equatable.dart';

abstract class SubscriptionsEvent extends Equatable {
  const SubscriptionsEvent();

  @override
  List<Object> get props => [];
}

class LoadSubscriptionsEvent extends SubscriptionsEvent {}

class LoadSubscriptionDetailsEvent extends SubscriptionsEvent {
  final String id;

  const LoadSubscriptionDetailsEvent(this.id);

  @override
  List<Object> get props => [id];
}

class CancelSubscriptionEvent extends SubscriptionsEvent {
  final String id;

  const CancelSubscriptionEvent(this.id);

  @override
  List<Object> get props => [id];
}
