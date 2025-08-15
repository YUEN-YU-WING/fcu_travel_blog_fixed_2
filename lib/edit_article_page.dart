import 'package:flutter/material.dart';

class EditArticlePage extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final Function(String title, String content)? onSave;

  const EditArticlePage({
    super.key,
    this.initialTitle,
    this.initialContent,
    this.onSave,
  });

  @override
  State<EditArticlePage> createState() => _EditArticlePageState();
}

class _EditArticlePageState extends State<EditArticlePage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveArticle() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('標題和內容都不能為空')),
      );
      return;
    }
    if (widget.onSave != null) {
      widget.onSave!(title, content);
    }
    Navigator.pop(context); // 可根據需求決定是否自動返回
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯文章'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveArticle,
            tooltip: '儲存',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '標題',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '內容',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
                expands: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}