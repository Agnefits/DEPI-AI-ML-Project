import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_subscriptions_usecase.dart';
import '../../domain/usecases/get_subscription_details_usecase.dart';
import '../../domain/usecases/cancel_subscription_usecase.dart';
import 'subscriptions_event.dart';
import 'subscriptions_state.dart';

class SubscriptionsBloc extends Bloc<SubscriptionsEvent, SubscriptionsState> {
  final GetSubscriptionsUseCase getSubscriptionsUseCase;
  final GetSubscriptionDetailsUseCase getSubscriptionDetailsUseCase;
  final CancelSubscriptionUseCase cancelSubscriptionUseCase;

  SubscriptionsBloc({
    required this.getSubscriptionsUseCase,
    required this.getSubscriptionDetailsUseCase,
    required this.cancelSubscriptionUseCase,
  }) : super(SubscriptionsInitial()) {
    on<LoadSubscriptionsEvent>(_onLoadSubscriptions);
    on<LoadSubscriptionDetailsEvent>(_onLoadSubscriptionDetails);
    on<CancelSubscriptionEvent>(_onCancelSubscription);
  }

  Future<void> _onLoadSubscriptions(
    LoadSubscriptionsEvent event,
    Emitter<SubscriptionsState> emit,
  ) async {
    emit(SubscriptionsLoading());
    try {
      final subscriptions = await getSubscriptionsUseCase();
      emit(SubscriptionsLoaded(subscriptions));
    } catch (e) {
      emit(SubscriptionsError(e.toString()));
    }
  }

  Future<void> _onLoadSubscriptionDetails(
    LoadSubscriptionDetailsEvent event,
    Emitter<SubscriptionsState> emit,
  ) async {
    emit(SubscriptionsLoading());
    try {
      final subscription = await getSubscriptionDetailsUseCase(event.id);
      emit(SubscriptionDetailsLoaded(subscription));
    } catch (e) {
      emit(SubscriptionsError(e.toString()));
    }
  }

  Future<void> _onCancelSubscription(
    CancelSubscriptionEvent event,
    Emitter<SubscriptionsState> emit,
  ) async {
    emit(SubscriptionsLoading());
    try {
      final success = await cancelSubscriptionUseCase(event.id);
      if (success) {
        emit(SubscriptionCancelledSuccess());
        add(LoadSubscriptionsEvent());
      } else {
        emit(const SubscriptionsError('Failed to cancel subscription'));
      }
    } catch (e) {
      emit(SubscriptionsError(e.toString()));
    }
  }
}
