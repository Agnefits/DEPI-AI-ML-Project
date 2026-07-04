import '../models/notification_model.dart';
import '../../../../core/network/dio_client.dart';

abstract class NotificationRemoteDataSource {
  Future<List<NotificationModel>> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> deleteNotification(String id);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final DioClient client;

  NotificationRemoteDataSourceImpl({
    required this.client,
  });

  @override
  Future<List<NotificationModel>> getNotifications() async {
    final response = await client.dio.get('/NotificationsApi');

    final data = response.data;
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['data'] is List) {
      list = data['data'] as List<dynamic>;
    } else {
      return [];
    }

    return list
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markAsRead(String id) async {
    await client.dio.post(
      '/NotificationsApi/$id/read',
      data: {},
    );
  }

  @override
  Future<void> deleteNotification(String id) async {
    await client.dio.delete('/NotificationsApi/$id');
  }
}
