import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import 'config.dart';
const String _vapidKey =
    'BPm0kWEEazAULngzb2ysuswI0QVl_H2Y3DTJ-dOSRL0tzp_EV1y87vn5UReefU5ideVvYd6IiMQ9BT3GDkjX0Wk';

Future<void> registerFcmToken(String authToken) async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    print('[FCM] permission: ${settings.authorizationStatus}');
    final fcmToken = await messaging.getToken(vapidKey: _vapidKey);
    print('[FCM] token: $fcmToken');
    if (fcmToken != null) {
      final resp = await Dio().post(
        '$kApiBase/auth/fcm-token',
        queryParameters: {'token': fcmToken},
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );
      print('[FCM] backend response: ${resp.statusCode}');
    }
  } catch (e, st) {
    print('[FCM] ERROR: $e\n$st');
  }
}
