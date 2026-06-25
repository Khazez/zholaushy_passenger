import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';

const String _apiBase = 'http://localhost:8000/api/v1';
const String _vapidKey =
    'BPm0kWEEazAULngzb2ysuswI0QVl_H2Y3DTJ-dOSRL0tzp_EV1y87vn5UReefU5ideVvYd6IiMQ9BT3GDkjX0Wk-';

Future<void> registerFcmToken(String authToken) async {
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final fcmToken = await messaging.getToken(vapidKey: _vapidKey);
    if (fcmToken != null) {
      await Dio().post(
        '$_apiBase/auth/fcm-token',
        queryParameters: {'token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
    }
  } catch (_) {}
}
