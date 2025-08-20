import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_page.dart';
import 'login_page.dart';
import 'image_recognition.dart';
import 'widgets/my_app_bar.dart';

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

  void _goToProfile(BuildContext context) {
    // TODO: replace with your profile page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("前往個人資料頁")),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("已登出")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: const MyAppBar(title: "首頁"),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _goToImageRecognition(context),
          child: const Text('前往影像辨識'),
        ),
      ),
    );
  }
}