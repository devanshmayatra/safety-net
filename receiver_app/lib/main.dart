import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:receiver_app/receiver_app.dart';
import 'firebase_options.dart';

// ... (the rest of your imports and code)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ReceiverApp());
}
