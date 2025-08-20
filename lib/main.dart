import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'my_articles_page.dart';
import 'edit_article_page.dart';
import 'album_page.dart';
import 'package:firebase_app_check/firebase_app_check.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    webProvider: ReCaptchaV3Provider('6LekZqsrAAAAAFSDOt3tWDnK5Ehv7xZCaaSDRDzq'),
  );
  runApp(const MyMainApp());
}

class MyMainApp extends StatelessWidget {
  const MyMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCU Travel Blog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
      routes: {
        '/my_articles': (context) => const MyArticlesPage(),
        '/edit_article': (context) => EditArticlePage.fromRouteArguments(context),
        '/album': (context) => const AlbumPage(),
      },
    );
  }
}