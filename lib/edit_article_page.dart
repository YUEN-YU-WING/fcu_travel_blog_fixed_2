import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_picker_page.dart'; // 引入地圖選擇頁面

class EditArticlePage extends StatefulWidget {
  final String? articleId;
  final String? initialTitle;
  final String? initialContent;
  final LatLng? initialLocation; // 讓地點可以是可選的
  final String? initialAddress; // 新增地址欄位

  const EditArticlePage({
    super.key,
    this.articleId,
    this.initialTitle,
    this.initialContent,
    this.initialLocation,
    this.initialAddress,
  });

  static EditArticlePage fromRouteArguments(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    return EditArticlePage(
      articleId: args['articleId'] as String?,
      initialTitle: args['initialTitle'] as String?,
      initialContent: args['initialContent'] as String?,
      initialLocation: args['location'] as LatLng?, // 從args讀取
      initialAddress: args['address'] as String?, // 從args讀取
    );
  }

  @override
  State<EditArticlePage> createState() => _EditArticlePageState();
}

class _EditArticlePageState extends State<EditArticlePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  LatLng? _selectedLocation; // 用於儲存選取的地點
  String? _selectedAddress; // 用於儲存選取的地址
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    _selectedLocation = widget.initialLocation;
    _selectedAddress = widget.initialAddress;

    if (widget.articleId != null && (widget.initialTitle == null || widget.initialContent == null || widget.initialLocation == null)) {
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
        if (data?['location'] != null) {
          final GeoPoint geoPoint = data!['location'];
          _selectedLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
        }
        _selectedAddress = data?['address'] ?? '';
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
    if (_selectedLocation == null) { // 要求用戶選擇地點
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇一個地點')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dataToSave = {
        'title': title,
        'content': content,
        'location': GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude), // 保存為 GeoPoint
        'address': _selectedAddress,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.articleId == null) {
        await FirebaseFirestore.instance.collection('articles').add({
          ...dataToSave,
          'authorUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('articles').doc(widget.articleId).update(dataToSave);
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

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapPickerPage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedLocation = result['location'] as LatLng;
        _selectedAddress = result['address'] as String;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.articleId == null ? '新增文章' : '編輯文章'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _pickLocation,
            tooltip: '選擇地點',
          ),
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
            if (_selectedAddress != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_pin, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedAddress!,
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: MarkdownAutoPreview(
                controller: _contentController,
                enableToolBar: true,
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