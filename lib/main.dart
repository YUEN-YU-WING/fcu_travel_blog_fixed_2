import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // 新增這行
import 'home_page.dart';
import 'edit_article_page.dart';
import 'my_articles_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
      },
    );
  }
}