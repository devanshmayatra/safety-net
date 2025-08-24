// --- RECEIVER APP (lib/main.dart) ---
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String serverUrl = 'http://YOUR_SERVER_IP:3000';
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> setupNotifications() async {
  // Setup for flutter_local_notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Get FCM token and register it
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  final String? token = await messaging.getToken();
  print("My Device FCM Token: $token");
  if (token != null) {
    try {
      await http.post(
        Uri.parse('$serverUrl/register-device'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );
      print("Receiver device registered successfully!");
    } catch (e) {
      print("Error registering device: $e");
    }
  }

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    String sound = 'default';

    // Check for custom data payload
    if (message.data['type'] == 'panic') {
      sound = 'alarm.mp3'; // The filename for the panic sound
    }

    if (notification != null && android != null) {
      var flutterLocalNotificationsPlugin;
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // A custom channel ID
            'High Importance Notifications', // A custom channel name
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(sound.split('.').first),
          ),
        ),
      );
    }
  });
}

class ReceiverApp extends StatelessWidget {
  const ReceiverApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Notification Receiver')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              'This app is ready to receive notifications. You can keep it in the background.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}
