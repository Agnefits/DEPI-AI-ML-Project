import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/delete_notification.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/mark_as_read.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetNotificationsUseCase getNotificationsUseCase;
  final MarkAsReadUseCase markAsReadUseCase;
  final DeleteNotificationUseCase deleteNotificationUseCase;

  NotificationBloc({
    required this.getNotificationsUseCase,
    required this.markAsReadUseCase,
    required this.deleteNotificationUseCase,
  }) : super(NotificationInitial()) {
    on<LoadNotificationsEvent>(_onLoadNotifications);
    on<MarkNotificationAsReadEvent>(_onMarkNotificationAsRead);
    on<DeleteNotificationEvent>(_onDeleteNotification);
  }

  Future<void> _onLoadNotifications(
      LoadNotificationsEvent event, Emitter<NotificationState> emit) async {
    emit(NotificationLoading());
    try {
      final notifications = await getNotificationsUseCase();
      emit(NotificationLoaded(notifications));
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onMarkNotificationAsRead(
      MarkNotificationAsReadEvent event, Emitter<NotificationState> emit) async {
    final currentState = state;
    if (currentState is NotificationLoaded) {
      try {
        await markAsReadUseCase(event.id);
        final notifications = await getNotificationsUseCase();
        emit(NotificationLoaded(notifications));
      } catch (e) {
        emit(NotificationError(e.toString()));
      }
    }
  }

  Future<void> _onDeleteNotification(
      DeleteNotificationEvent event, Emitter<NotificationState> emit) async {
    final currentState = state;
    if (currentState is NotificationLoaded) {
      try {
        await deleteNotificationUseCase(event.id);
        final notifications = await getNotificationsUseCase();
        emit(NotificationLoaded(notifications));
      } catch (e) {
        emit(NotificationError(e.toString()));
      }
    }
  }
}
