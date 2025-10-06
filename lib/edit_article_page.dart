import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';

class EditArticlePage extends StatefulWidget {
  final String? articleId;
  final String? initialTitle;
  final String? initialContent;

  const EditArticlePage({
    super.key,
    this.articleId,
    this.initialTitle,
    this.initialContent,
  });

  static EditArticlePage fromRouteArguments(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    return EditArticlePage(
      articleId: args['articleId'] as String?,
      initialTitle: args['initialTitle'] as String?,
      initialContent: args['initialContent'] as String?,
    );
  }

  @override
  State<EditArticlePage> createState() => _EditArticlePageState();
}

class _EditArticlePageState extends State<EditArticlePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    if (widget.articleId != null && (widget.initialTitle == null || widget.initialContent == null)) {
      _fetchArticle();
    }
  }

  Future<void> _fetchArticle() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('articles')
          .doc(widget.articleId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        _titleController.text = data?['title'] ?? '';
        _contentController.text = data?['content'] ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入文章失敗: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveArticle() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('標題和內容都不能為空')),
      );
      return;
    }
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.articleId == null) {
        await FirebaseFirestore.instance.collection('articles').add({
          'title': title,
          'content': content,
          'authorUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('articles').doc(widget.articleId).update({
          'title': title,
          'content': content,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存成功！')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.articleId == null ? '新增文章' : '編輯文章'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveArticle,
            tooltip: '儲存',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
              child: MarkdownAutoPreview(
                controller: _contentController,
                enableToolBar: true, // 顯示工具列
                minLines: 15,
                emojiConvert: true,
                autoCloseAfterSelectEmoji: true,
                decoration: const InputDecoration(
                  labelText: '內容',
                  border: OutlineInputBorder(),
                  hintText: '請輸入Markdown內容...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}