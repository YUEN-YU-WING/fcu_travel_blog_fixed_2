import 'package:flutter/material.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'image_recognition.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _goToRegister(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  void _goToLogin(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void _goToImageRecognition(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LandmarkDetectorPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首頁'),
        actions: [
          TextButton(
            onPressed: () => _goToRegister(context),
            child: const Text('註冊'),
          ),
          TextButton(
            onPressed: () => _goToLogin(context),
            child: const Text('登入'),
          ),
        ],
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _goToImageRecognition(context),
          child: const Text('前往影像辨識'),
        ),
      ),
    );
  }
}