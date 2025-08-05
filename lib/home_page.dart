import 'package:flutter/material.dart';
import 'image_recognition.dart';
import 'register_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  void _goToImageRecognition(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LandmarkDetectorPage()),
    );
  }

  void _goToRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('首頁')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _goToImageRecognition(context),
              child: const Text('前往影像辨識'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _goToRegister(context),
              child: const Text('註冊新帳號'),
            ),
          ],
        ),
      ),
    );
  }
}