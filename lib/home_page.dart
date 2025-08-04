import 'package:flutter/material.dart';
import 'image_recognition.dart'; // 或 'image_recognition.dart' 路徑根據專案情況調整

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  void _goToImageRecognition(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LandmarkDetectorPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('首頁')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _goToImageRecognition(context),
          child: const Text('前往影像辨識'),
        ),
      ),
    );
  }
}