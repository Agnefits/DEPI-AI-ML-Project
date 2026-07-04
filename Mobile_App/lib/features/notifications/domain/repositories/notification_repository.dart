import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  Future<List<NotificationEntity>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> deleteNotification(String id);
}
