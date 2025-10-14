// lib/image_recognition.dart
import 'package:flutter/material.dart';
import 'vision_service.dart';

class LandmarkTestPage extends StatefulWidget {
  const LandmarkTestPage({super.key});

  @override
  State<LandmarkTestPage> createState() => _LandmarkTestPageState();
}

class _LandmarkTestPageState extends State<LandmarkTestPage> {
  // 依你的後端/Google Key 二擇一設定：
  // 1) 自架後端（Android 模擬器請用 10.0.2.2，iOS/Web 用 localhost）
  final _visionService = VisionService(serverUrl: 'http://10.0.2.2:8080');
  // 2) 若改直連 Google，請用：
  // final _visionService = VisionService(googleApiKey: 'YOUR_API_KEY');

  final _urlController = TextEditingController();
  String? _result;
  bool _loading = false;

  Future<void> _detectByUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _result = "請先輸入圖片網址");
      return;
    }
    setState(() {
      _loading = true;
      _result = "分析中...";
    });
    try {
      final landmark = await _visionService.detectLandmarkByUrl(url);
      setState(() => _result = landmark.isNotEmpty ? landmark : "（無地標）");
    } catch (e) {
      setState(() => _result = "錯誤: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("地標辨識測試")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: "圖片網址（Storage downloadUrl）",
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text("用網址分析地標"),
              onPressed: _loading ? null : _detectByUrl,
            ),
            const SizedBox(height: 24),
            if (_loading) const CircularProgressIndicator(),
            if (_result != null) ...[
              const SizedBox(height: 16),
              Text(_result!, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}