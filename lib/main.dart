export 'app.dart';


import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';


import 'firebase_options.dart';
import 'app.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await dotenv.load(fileName: ".env");


  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    webProvider: ReCaptchaV3Provider('6LekZqsrAAAAAFSDOt3tWDnK5Ehv7xZCaaSDRDzq'),
  );


  runApp(const MyApp());
}