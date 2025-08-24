// --- RECEIVER APP (lib/main.dart) ---
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart'; // <-- 1. IMPORT FIREBASE CORE
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart'; // <-- 2. IMPORT FIREBASE OPTIONS

// --- CONFIGURATION ---
const String serverUrl =
    'https://safety-net-la20.onrender.com'; // Removed trailing slash
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// --- MAIN FUNCTION (The entry point of your app) ---
void main() async {
  // 3. ENSURE FLUTTER IS READY
  WidgetsFlutterBinding.ensureInitialized();

  // 4. INITIALIZE FIREBASE (ESSENTIAL)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 5. CALL YOUR SETUP FUNCTION
  await setupNotifications();

  // 6. RUN THE APP
  runApp(const ReceiverApp());
}

// --- SETUP FUNCTION (Your original code, with fixes) ---
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
  log("My Device FCM Token: $token");

  if (token != null) {
    try {
      final response = await http.post(
        // <-- Capture the response
        Uri.parse('$serverUrl/register-device'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );

      // --- 7. ADD THIS CHECK FOR SERVER ERRORS ---
      if (response.statusCode == 200) {
        log("✅ Receiver device registered successfully! Server responded OK.");
      } else {
        log(
          "❌ Server Error: Failed to register device. Status code: ${response.statusCode}",
        );
        log("   Response body: ${response.body}");
      }
    } catch (e) {
      log("❌ Network Error: Could not connect to server. Details: $e");
    }
  }

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    log('Got a message whilst in the foreground!');
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    String sound = 'default';

    if (message.data['type'] == 'panic') {
      sound = 'alarm.mp3';
    }

    if (notification != null && android != null) {
      // var flutterLocalNotificationsPlugin; // <-- 8. BUG FIX: REMOVED THIS LINE
      // Use the global instance defined at the top of the file
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
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

// --- APP WIDGET (Unchanged) ---
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
