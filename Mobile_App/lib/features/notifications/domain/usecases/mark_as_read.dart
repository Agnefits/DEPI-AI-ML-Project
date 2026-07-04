import '../repositories/notification_repository.dart';

class MarkAsReadUseCase {
  final NotificationRepository repository;

  MarkAsReadUseCase(this.repository);

  Future<void> call(String id) async {
    return await repository.markAsRead(id);
  }
}
