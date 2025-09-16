import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'vision_service.dart';

class LandmarkTestPage extends StatefulWidget {
  const LandmarkTestPage({super.key});

  @override
  State<LandmarkTestPage> createState() => _LandmarkTestPageState();
}

class _LandmarkTestPageState extends State<LandmarkTestPage> {
  //final _visionService = VisionService(serverUrl: 'http://10.0.2.2:8080'); // Android 模擬器用
   final _visionService = VisionService(serverUrl: 'http://localhost:8080'); // Web or iOS 用

  String? _result;
  final _controller = TextEditingController();
  File? _selectedImage;

  Future<void> _detectByUrl() async {
    setState(() => _result = "分析中...");
    try {
      final landmark = await _visionService.detectLandmarkByUrl(_controller.text.trim());
      setState(() => _result = landmark);
    } catch (e) {
      setState(() => _result = "錯誤: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("地標辨識測試")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- URL 辨識 ---
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "圖片網址（Storage downloadUrl）",
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text("用網址分析地標"),
              onPressed: _detectByUrl,
            ),

            const Divider(height: 40),

            const SizedBox(height: 32),
            Text(_result ?? "請輸入圖片網址"),
          ],
        ),
      ),
    );
  }
}
