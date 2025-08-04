import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const MyMainApp());
}

class MyMainApp extends StatelessWidget {
  const MyMainApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCU Travel Blog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}