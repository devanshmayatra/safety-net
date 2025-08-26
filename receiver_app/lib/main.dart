import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

// --- CONFIGURATION ---
const String serverUrl = 'https://safety-net-la20.onrender.com';
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// For custom sounds
const String alarmSound = "panic_alarm"; // Your filename without extension
const String panicChannelId = 'panic_alerts_channel';
const String panicChannelName = 'Panic Alerts';
const String panicChannelDescription =
    'Channel for urgent, high-priority alerts.';

// --- STATE MANAGEMENT ---
// Using a ValueNotifier is a simple way to update the UI from outside the widget tree.
enum ConnectionStatus { connecting, success, error }

final ValueNotifier<ConnectionStatus> connectionStatusNotifier = ValueNotifier(
  ConnectionStatus.connecting,
);

// --- MAIN FUNCTION ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await setupNotifications();
  runApp(const ReceiverApp());
}

// --- SETUP NOTIFICATIONS FUNCTION ---
Future<void> setupNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create the custom notification channel for panic alerts
  final AndroidNotificationChannel panicChannel = AndroidNotificationChannel(
    panicChannelId,
    panicChannelName,
    description: panicChannelDescription,
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(alarmSound),
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(panicChannel);

  // Register the device with your server
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  final String? token = await messaging.getToken();
  log("My Device FCM Token: $token");

  if (token != null) {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/register-device'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );
      if (response.statusCode == 200) {
        log("✅ Device registered successfully!");
        connectionStatusNotifier.value = ConnectionStatus.success;
      } else {
        log(
          "❌ Server Error: Failed to register. Status: ${response.statusCode}",
        );
        connectionStatusNotifier.value = ConnectionStatus.error;
      }
    } catch (e) {
      log("❌ Network Error: Could not connect to server. Details: $e");
      connectionStatusNotifier.value = ConnectionStatus.error;
    }
  } else {
    connectionStatusNotifier.value = ConnectionStatus.error;
  }

  // Handle incoming foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    log('Got a message whilst in the foreground!');
    RemoteNotification? notification = message.notification;
    String channelIdToUse = 'high_importance_channel'; // Default channel
    log(message.data.toString());

    if (message.data['type'] == 'panic') {
      channelIdToUse = panicChannelId; // Use our special panic channel
    }

    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelIdToUse,
            channelIdToUse, // Name and description are set when the channel is created
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            // The sound is handled by the channel, no need to specify it here
          ),
        ),
      );
    }
  });
}

// --- APP ROOT WIDGET ---
class ReceiverApp extends StatelessWidget {
  const ReceiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define a clean, professional theme
    const primaryColor = Color(0xFF1A1A2E);
    const secondaryColor = Color(0xFF16213E);
    const accentColor = Color(0xFF0F3460);
    const textColor = Color(0xFFE94560);

    return MaterialApp(
      title: 'SafetyNet Receiver',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: primaryColor,
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white70, displayColor: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: secondaryColor,
          elevation: 4.0,
        ),
        iconTheme: const IconThemeData(color: textColor, size: 48),
      ),
      home: const ReceiverHomePage(),
    );
  }
}

// --- HOME PAGE WIDGET ---
class ReceiverHomePage extends StatelessWidget {
  const ReceiverHomePage({super.key});

  // A helper function to send a test notification to this device
  void _sendTestNotification(String type) {
    flutterLocalNotificationsPlugin.show(
      0,
      type == 'panic' ? '🚨 Test Panic Alert 🚨' : 'Test Ping 👋',
      'This is a test notification from within the app.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          type == 'panic' ? panicChannelId : 'high_importance_channel',
          'Test Channel',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receiver Status'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            // Use a ValueListenableBuilder to automatically update the UI
            // when the connection status changes.
            ValueListenableBuilder<ConnectionStatus>(
              valueListenable: connectionStatusNotifier,
              builder: (context, status, child) {
                IconData icon;
                String text;
                Color color;

                switch (status) {
                  case ConnectionStatus.success:
                    icon = Icons.check_circle_outline_rounded;
                    text = 'Connected & Ready';
                    color = Colors.greenAccent.shade400;
                    break;
                  case ConnectionStatus.error:
                    icon = Icons.error_outline_rounded;
                    text = 'Connection Failed';
                    color = Colors.redAccent;
                    break;
                  case ConnectionStatus.connecting:
                  default:
                    return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    Icon(icon, color: color, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: color),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This app is ready to receive notifications. You can close it or keep it in the background.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            Text(
              'Test Notifications',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => _sendTestNotification('normal'),
                  child: const Text('Test Ping'),
                ),
                OutlinedButton(
                  onPressed: () => _sendTestNotification('panic'),
                  child: const Text('Test Alarm'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
