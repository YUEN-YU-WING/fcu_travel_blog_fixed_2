// lib/ai_upload_page.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'vision_service.dart';
import 'storage_upload_service.dart';

/// 互動問題（可擴充）
const List<Map<String, String>> interactiveQuestions = [
  {
    "key": "order",
    "question": "此地標的瀏覽順序？（例：第1站、第2站...）",
    "hint": "請輸入瀏覽順序",
  },
];

class AIUploadPage extends StatefulWidget {
  /// 後台嵌入時請設為 true：const AIUploadPage(embedded: true)
  /// 獨立開頁則保持預設 false（會顯示系統返回鍵）
  final bool embedded;

  const AIUploadPage({super.key, this.embedded = false});

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

    // 1) 選擇圖片
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    _image = File(picked.path);

    try {
      // 2) 上傳到 Firebase Storage
      final filename = "${DateTime.now().millisecondsSinceEpoch}_${picked.name}";
      final ref = FirebaseStorage.instance.ref().child("uploads/$filename");
      await ref.putFile(_image!);
      final url = await ref.getDownloadURL();
      _imageUrl = url;

      // 3) 呼叫 VisionService
      final landmark = await visionService.detectLandmarkByUrl(url);
      _landmark = landmark;

      // 4) 問答互動（有地標才問）
      if ((landmark ?? '').isNotEmpty && landmark != "未知地標") {
        await _showInteractiveQuestions(landmark!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上傳或辨識失敗：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 範例：帶 metadata 上傳（非主要流程）
  Future<void> doUploadWithMetadata() async {
    final metadata = {
      "author": "YUEN-YU-WING",
      "description": "這是範例圖片",
      "createdAt": DateTime.now().toIso8601String(),
    };
    final url = await StorageUploadService.pickAndUploadFile(metadata: metadata);
    if (!mounted) return;

    if (url != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("檔案已上傳，公開網址: $url")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("未選擇檔案或上傳失敗")));
    }
  }

  // 彈出互動問答
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
      if (mounted) setState(() {}); // 更新 UI
    }
  }

  // 單題 Dialog
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
      appBar: AppBar(
        title: const Text("AI 地標辨識與互動問答"),
        // ✅ 核心：在後台嵌入時不顯示返回鍵；獨立開頁保留返回鍵
        automaticallyImplyLeading: !widget.embedded,
      ),
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
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SelectableText(
                    "圖片網址：$_imageUrl",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

              const SizedBox(height: 20),

              if (_loading) const CircularProgressIndicator(),

              if ((_landmark ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text("地標辨識結果：$_landmark",
                      style: const TextStyle(fontSize: 18)),
                ),

              const SizedBox(height: 30),
              _buildAnswerList(),
            ],
          ),
        ),
      ),
    );
  }
}
