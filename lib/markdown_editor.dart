import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';

class FirestoreMarkdownEditorPage extends StatefulWidget {
  const FirestoreMarkdownEditorPage({super.key});
  @override
  State<FirestoreMarkdownEditorPage> createState() => _FirestoreMarkdownEditorPageState();
}

class _FirestoreMarkdownEditorPageState extends State<FirestoreMarkdownEditorPage> {
  final TextEditingController _controller = TextEditingController();

  // 儲存到 Firestore
  Future<void> _saveToFirestore() async {
    final text = _controller.text;
    await FirebaseFirestore.instance.collection('markdown_articles').add({
      'content': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存到 Firestore')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Markdown 編輯器')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 工具列自帶在 markdown_editor_plus
            MarkdownAutoPreview(
              controller: _controller,
              enableToolBar: true, // 顯示工具列
              minLines: 10,
              emojiConvert: true,
              autoCloseAfterSelectEmoji: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: '請輸入Markdown內容...',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('儲存到Firebase'),
              onPressed: _saveToFirestore,
            ),
          ],
        ),
      ),
    );
  }
}