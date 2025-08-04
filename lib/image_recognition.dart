import 'dart:io';
import 'dart:typed_data';
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
  dynamic _imageInput; // Can be File (mobile) or XFile (web)
  Uint8List? _webImageBytes; // For web image preview
  String? _result;
  bool _loading = false;

  final _vision = VisionService(apiKey: 'AIzaSyAZMzjy4FSHfhtwfWNbpKRmd13dS4xVE44'); // << 換成你自己的 API Key

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _imageInput = kIsWeb ? picked : File(picked.path);
      _result = null;
      _loading = true;
    });

    // For web, also load bytes for preview
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _webImageBytes = bytes;
      });
    }

    final landmark = await _vision.detectLandmark(_imageInput);
    setState(() {
      _result = landmark ?? '找不到地標';
      _loading = false;
    });
  }

  Widget _buildImagePreview() {
    if (_imageInput == null) return const Text("尚未選擇圖片");
    
    if (kIsWeb) {
      // Web platform - use bytes for preview
      if (_webImageBytes != null) {
        return Image.memory(
          _webImageBytes!,
          height: 200,
          fit: BoxFit.contain,
        );
      } else {
        return const Text("載入圖片中...");
      }
    } else {
      // Mobile platform - use File
      return Image.file(
        _imageInput as File,
        height: 200,
        fit: BoxFit.contain,
      );
    }
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
