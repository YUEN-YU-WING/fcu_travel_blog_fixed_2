import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'vision_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '地標分析 App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LandmarkDetectorPage(),
    );
  }
}

class LandmarkDetectorPage extends StatefulWidget {
  const LandmarkDetectorPage({super.key});

  @override
  State<LandmarkDetectorPage> createState() => _LandmarkDetectorPageState();
}

class _LandmarkDetectorPageState extends State<LandmarkDetectorPage> {
  File? _image;
  String? _result;
  bool _loading = false;

  final _vision = VisionService(apiKey: 'AIzaSyAZMzjy4FSHfhtwfWNbpKRmd13dS4xVE44'); // << 換成你自己的 API Key

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _result = null;
      _loading = true;
    });

    final landmark = await _vision.detectLandmark(_image!);
    setState(() {
      _result = landmark ?? '找不到地標';
      _loading = false;
    });
  }

  Widget _buildImagePreview() {
    if (_image == null) return const Text("尚未選擇圖片");
    if (kIsWeb) return const Text("網頁平台不支援本地圖片預覽");
    return Image.file(_image!, height: 200);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("地標辨識")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text("選擇照片"),
            ),
            const SizedBox(height: 16),
            _buildImagePreview(),
            const SizedBox(height: 16),
            if (_loading)
              const CircularProgressIndicator()
            else if (_result != null)
              Text("辨識結果：$_result"),
          ],
        ),
      ),
    );
  }
}
