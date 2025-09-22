import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'vision_service.dart';
import 'storage_upload_service.dart';

// 互動問題配置（可擴充更多問題）
const List<Map<String, String>> interactiveQuestions = [
  {
    "key": "order",
    "question": "此地標的瀏覽順序？（例：第1站、第2站...）",
    "hint": "請輸入瀏覽順序",
  },
  // 可以再加其他問題
  // {
  //   "key": "feeling",
  //   "question": "你對此地標有何感受？",
  //   "hint": "請輸入感受",
  // },
];

class AIUploadPage extends StatefulWidget {
  const AIUploadPage({super.key});

  @override
  State<AIUploadPage> createState() => _AIUploadPageState();
}

class _AIUploadPageState extends State<AIUploadPage> {
  final visionService = VisionService(serverUrl: 'http://localhost:8080');
  bool _loading = false;
  File? _image;
  String? _imageUrl;
  String? _landmark;
  final Map<String, Map<String, String>> _answers = {}; // 地標 => {key: answer}

  Future<void> _uploadAndDetect() async {
    setState(() {
      _loading = true;
      _landmark = null;
      _imageUrl = null;
      _image = null;
    });

    // 選擇圖片
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    _image = File(picked.path);

    // 上傳到 Storage
    final filename = "${DateTime.now().millisecondsSinceEpoch}_${picked.name}";
    final ref = FirebaseStorage.instance.ref().child("uploads/$filename");
    await ref.putFile(_image!);
    final url = await ref.getDownloadURL();
    _imageUrl = url;

    // 呼叫 VisionService
    final landmark = await visionService.detectLandmarkByUrl(url);
    _landmark = landmark;

    setState(() {
      _loading = false;
    });

    if (landmark.isNotEmpty && landmark != "未知地標") {
      await _showInteractiveQuestions(landmark);
    }
  }

  Future<void> doUploadWithMetadata() async {
    final metadata = {
      "author": "YUEN-YU-WING",
      "description": "這是範例圖片",
      "createdAt": DateTime.now().toIso8601String(),
    };
    final url = await StorageUploadService.pickAndUploadFile(metadata: metadata);
    if (url != null) {
      Text("檔案已上傳，公開網址: $url");
      // 你可以在這裡把 url 顯示在 UI 或傳給 VisionService
      // 例如：
      // final result = await visionService.detectLandmarkByUrl(url);
      // setState(() => _result = result);
    } else {
      Text("未選擇檔案或上傳失敗");
    }
  }

  // 彈出互動問答（多題型可擴充）
  Future<void> _showInteractiveQuestions(String landmark) async {
    Map<String, String> answers = {};
    for (var q in interactiveQuestions) {
      final ans = await _showSingleQuestionDialog(q['question']!, q['hint']!);
      if (ans != null && ans.isNotEmpty) {
        answers[q['key']!] = ans;
      }
    }
    if (answers.isNotEmpty) {
      _answers[landmark] = answers;
      setState(() {}); // 更新 UI
    }
  }

  // 單題問答 Dialog
  Future<String?> _showSingleQuestionDialog(String question, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("互動問題"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(question),
            TextField(
              controller: controller,
              decoration: InputDecoration(hintText: hint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerList() {
    if (_answers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("使用者回答記錄：", style: TextStyle(fontWeight: FontWeight.bold)),
        ..._answers.entries.map((entry) {
          final landmark = entry.key;
          final answers = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("地標：$landmark", style: const TextStyle(fontSize: 16)),
                ...answers.entries.map((e) => Text("  ${e.key}: ${e.value}")),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI 地標辨識與互動問答")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text("上傳圖片並辨識"),
                onPressed: _loading ? null : _uploadAndDetect,
              ),
              const SizedBox(height: 20),
              if (_image != null)
                Image.file(_image!, width: 200, height: 200),
              if (_imageUrl != null)
                Text("圖片網址：$_imageUrl", style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 20),
              if (_loading) const CircularProgressIndicator(),
              if (_landmark != null)
                Text("地標辨識結果：$_landmark", style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 30),
              _buildAnswerList(),
            ],
          ),
        ),
      ),
    );
  }
}