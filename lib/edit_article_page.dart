import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:markdown_editor_plus/markdown_editor_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 引入圖片緩存
import 'map_picker_page.dart';
import 'album_folder_page.dart';

class EditArticlePage extends StatefulWidget {
  final String? articleId;
  final String? initialTitle;
  final String? initialContent;
  final LatLng? initialLocation;
  final String? initialAddress;
  final String? initialPlaceName;
  final String? initialThumbnailImageUrl;
  final String? initialThumbnailFileName;

  const EditArticlePage({
    super.key,
    this.articleId,
    this.initialTitle,
    this.initialContent,
    this.initialLocation,
    this.initialAddress,
    this.initialPlaceName,
    this.initialThumbnailImageUrl,
    this.initialThumbnailFileName,
  });

  static EditArticlePage fromRouteArguments(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    return EditArticlePage(
      articleId: args['articleId'] as String?,
      initialTitle: args['initialTitle'] as String?,
      initialContent: args['initialContent'] as String?,
      initialLocation: args['location'] as LatLng?,
      initialAddress: args['address'] as String?,
      initialPlaceName: args['placeName'] as String?,
      initialThumbnailImageUrl: args['thumbnailImageUrl'] as String?,
      initialThumbnailFileName: args['thumbnailFileName'] as String?,
    );
  }

  @override
  State<EditArticlePage> createState() => _EditArticlePageState();
}

class _EditArticlePageState extends State<EditArticlePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _placeNameController;

  LatLng? _selectedLocation;
  String? _selectedAddress;
  String? _thumbnailImageUrl;
  String? _thumbnailFileName;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    _placeNameController = TextEditingController(text: widget.initialPlaceName ?? '');
    _selectedLocation = widget.initialLocation;
    _selectedAddress = widget.initialAddress;
    _thumbnailImageUrl = widget.initialThumbnailImageUrl;
    _thumbnailFileName = widget.initialThumbnailFileName;

    if (widget.articleId != null &&
        (widget.initialTitle == null ||
            widget.initialContent == null ||
            widget.initialLocation == null ||
            widget.initialPlaceName == null ||
            widget.initialThumbnailImageUrl == null)) {
      _fetchArticle();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _placeNameController.dispose();
    super.dispose();
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
        _placeNameController.text = data?['placeName'] ?? '';
        if (data?['location'] != null) {
          final GeoPoint geoPoint = data!['location'];
          _selectedLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
        }
        _selectedAddress = data?['address'] ?? '';
        _thumbnailImageUrl = data?['thumbnailImageUrl'] ?? '';
        _thumbnailFileName = data?['thumbnailFileName'] ?? '';
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
    final placeName = _placeNameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (title.isEmpty || content.isEmpty || placeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('標題、內容和地標名稱都不能為空')),
      );
      return;
    }
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇一個地點')),
      );
      return;
    }
    if (_thumbnailImageUrl == null || _thumbnailImageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇一張圖片作為遊記縮圖')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dataToSave = {
        'title': title,
        'content': content,
        'placeName': placeName,
        'location': GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        'address': _selectedAddress,
        'thumbnailImageUrl': _thumbnailImageUrl,
        'thumbnailFileName': _thumbnailFileName,
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
        // 如果地標名稱未設定，可以嘗試從地址中提取一個部分作為預設值
        if (_placeNameController.text.isEmpty && result['address'] != null) {
          _placeNameController.text = (result['address'] as String).split(',').first.trim();
        }
        _placeNameController.text = result['placeName'] as String? ?? _placeNameController.text; // 優先使用返回的地標名稱
      });
    }
  }

  Future<void> _pickThumbnail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能選擇圖片')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AlbumFolderPage(isPickingImage: true),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _thumbnailImageUrl = result['imageUrl'] as String?;
        _thumbnailFileName = result['fileName'] as String?;
      });
    }
  }

  // ... (接續上一個回應的 _EditArticlePageState class) ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.articleId == null ? '新增文章' : '編輯文章'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _pickLocation,
            tooltip: '重新選擇地點',
          ),
          IconButton(
            icon: const Icon(Icons.photo),
            onPressed: _pickThumbnail,
            tooltip: '選擇遊記縮圖',
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
          : SingleChildScrollView( // <-- 將 Column 包裹在 SingleChildScrollView 中
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
            TextField(
              controller: _placeNameController,
              decoration: const InputDecoration(
                labelText: '地標名稱',
                hintText: '例如：台北101',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedAddress != null && _selectedAddress!.isNotEmpty)
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
            if (_thumbnailImageUrl != null && _thumbnailImageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('選定縮圖:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: CachedNetworkImage( // 使用 CachedNetworkImage
                        imageUrl: _thumbnailImageUrl!,
                        width: 100, // 顯示一個小預覽圖
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, size: 100),
                      ),
                    ),
                  ],
                ),
              ),
            // MarkdownAutoPreview 是一個 Expanded Widget，
            // 當它在 SingleChildScrollView 內部時，通常會導致錯誤，
            // 因為 SingleChildScrollView 的子 Widget 不能直接擴展。
            // 這裡我們需要給它一個固定的高度，或者使用 Flexible/Expanded 包裹在一個具有高度的父級中。
            // 為了方便滾動，我們直接給它一個較大的固定高度。
            SizedBox(
              height: 800, // 設定一個固定高度，讓內容可滾動
              child: MarkdownAutoPreview(
                controller: _contentController,
                enableToolBar: true,
                minLines: 10, // 保持最小行數以控制編輯器大小
                emojiConvert: true,
                autoCloseAfterSelectEmoji: true,
                decoration: const InputDecoration(
                  labelText: '內容',
                  border: OutlineInputBorder(),
                  hintText: '請輸入Markdown內容...',
                ),
              ),
            ),
            const SizedBox(height: 16), // 在內容下方添加一些間距
          ],
        ),
      ),
    );
  }
}