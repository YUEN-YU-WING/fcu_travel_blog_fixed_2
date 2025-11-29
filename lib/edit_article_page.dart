// lib/edit_article_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'map_picker_page.dart';
import 'album_folder_page.dart';

class EditArticlePage extends StatefulWidget {
  // ✅ 新增：在後台嵌入時不顯示系統返回鍵
  final bool embedded;

  final String? articleId;
  final String? initialTitle;
  final String? initialContent; // HTML 內容
  final LatLng? initialLocation;
  final String? initialAddress;
  final String? initialPlaceName;
  final String? initialThumbnailImageUrl;
  final String? initialThumbnailFileName;
  final bool? initialIsPublic;

  const EditArticlePage({
    super.key,
    this.embedded = false, // ✅ 預設為 false，獨立開頁時仍會有返回鍵
    this.articleId,
    this.initialTitle,
    this.initialContent,
    this.initialLocation,
    this.initialAddress,
    this.initialPlaceName,
    this.initialThumbnailImageUrl,
    this.initialThumbnailFileName,
    this.initialIsPublic,
  });

  static EditArticlePage fromRouteArguments(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    return EditArticlePage(
      articleId: args['articleId'] as String?,
      initialTitle: args['initialTitle'] as String?,
      initialContent: args['content'] as String?, // 這裡是 content
      initialLocation: args['location'] as LatLng?,
      initialAddress: args['address'] as String?,
      initialPlaceName: args['placeName'] as String?,
      initialThumbnailImageUrl: args['thumbnailUrl'] as String?,
      initialThumbnailFileName: args['thumbnailFileName'] as String?,
      initialIsPublic: args['isPublic'] as bool?,
      embedded: args['embedded'] as bool? ?? false,
    );
  }

  @override
  State<EditArticlePage> createState() => _EditArticlePageState();
}

class _EditArticlePageState extends State<EditArticlePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _placeNameController;
  late HtmlEditorController _htmlEditorController;

  LatLng? _selectedLocation;
  String? _selectedAddress;
  String? _thumbnailImageUrl;
  String? _thumbnailFileName;
  bool _isPublic = false;

  bool _isLoading = false;
  String? _initialEditorContent;

  bool _isEditorReady = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _placeNameController = TextEditingController(text: widget.initialPlaceName ?? '');
    _htmlEditorController = HtmlEditorController();

    _selectedLocation = widget.initialLocation;
    _selectedAddress = widget.initialAddress;
    _thumbnailImageUrl = widget.initialThumbnailImageUrl;
    _thumbnailFileName = widget.initialThumbnailFileName;
    _isPublic = widget.initialIsPublic ?? false;

    // 如果需要，從 Firestore 補齊完整文章資料
    if (widget.articleId != null &&
        (_titleController.text.isEmpty ||
            _initialEditorContent == null ||
            _selectedLocation == null ||
            _placeNameController.text.isEmpty ||
            _thumbnailImageUrl == null ||
            widget.initialIsPublic == null)) {
      _fetchArticle();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeNameController.dispose();
    super.dispose();
  }

  // --- 🔥 新增功能：生成關鍵字索引 (Search Keywords) ---
  List<String> _generateKeywords(String title, String htmlContent, String placeName) {
    // 1. 去除 HTML 標籤，只取純文字 (簡單正則，僅供索引使用)
    String plainTextContent = htmlContent.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');

    // 2. 合併所有要搜尋的欄位
    String text = '$title $placeName $plainTextContent'.toLowerCase();

    Set<String> keywords = {};

    // 3. 針對英文或空格分隔的單詞處理
    text.split(RegExp(r'\s+')).forEach((word) {
      if (word.isNotEmpty) keywords.add(word);
    });

    // 4. 針對中文進行 N-gram 切分 (單字、雙字、三字)
    // 先移除標點符號，只保留文字
    String cleanText = text.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]'), '');

    for (int i = 0; i < cleanText.length; i++) {
      // 單字 (Unigram) - 允許搜尋單個字
      keywords.add(cleanText[i]);

      // 雙字詞 (Bigram) - 例如 "台北"
      if (i + 1 < cleanText.length) {
        keywords.add(cleanText.substring(i, i + 2));
      }

      // 三字詞 (Trigram) - 例如 "台北市"
      if (i + 2 < cleanText.length) {
        keywords.add(cleanText.substring(i, i + 3));
      }
    }

    // 5. 過濾掉空字串或純標點符號
    return keywords.where((k) => k.isNotEmpty && !RegExp(r'^[.,\/#!$%\^&\*;:{}=\-_`~()。，、？！]+$').hasMatch(k)).toList();
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
        _placeNameController.text = data?['placeName'] ?? '';
        _initialEditorContent = data?['content'];

        if (data?['location'] != null) {
          final GeoPoint geoPoint = data!['location'];
          _selectedLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
        }
        _selectedAddress = data?['address'] ?? '';
        _thumbnailImageUrl = data?['thumbnailUrl'] ?? '';
        _thumbnailFileName = data?['thumbnailFileName'] ?? '';
        _isPublic = data?['isPublic'] ?? false;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入文章失敗: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveArticle() async {
    final title = _titleController.text.trim();
    final placeName = _placeNameController.text.trim();
    final content = await _htmlEditorController.getText(); // 這是 HTML
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
      // 🔥 生成關鍵字 (包含標題、地名、去除 HTML 的內容)
      final keywords = _generateKeywords(title, content, placeName);

      final dataToSave = {
        'title': title,
        'content': content,
        'placeName': placeName,
        'location': GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        'address': _selectedAddress,
        'thumbnailImageUrl': _thumbnailImageUrl,
        'thumbnailFileName': _thumbnailFileName,
        'isPublic': _isPublic,
        'keywords': keywords, // ✅ 儲存關鍵字陣列
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.articleId == null) {
        await FirebaseFirestore.instance.collection('articles').add({
          ...dataToSave,
          'ownerUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('articles').doc(widget.articleId).update(dataToSave);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('儲存成功！')));

      // 如果不是嵌入模式，則 pop 並返回 true
      if (!widget.embedded) {
        Navigator.pop(context, true); // 返回 true 表示保存成功
      }
      // 如果是嵌入模式，則不做任何導航操作，讓頁面保持在 BackendHomePage 內部
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        _placeNameController.text = result['placeName'] as String? ?? _placeNameController.text;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.articleId == null ? '新增文章' : '編輯文章'),
        // ✅ 核心：在後台嵌入時（embedded=true）不顯示返回鍵
        automaticallyImplyLeading: !widget.embedded,
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
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      child: CachedNetworkImage(
                        imageUrl: _thumbnailImageUrl!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 100),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                const Text('公開發表', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Switch(
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // HTML 編輯器
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: HtmlEditor(
                controller: _htmlEditorController,
                htmlEditorOptions: HtmlEditorOptions(
                  hint: "請輸入遊記內容...",
                  shouldEnsureVisible: true,
                ),
                htmlToolbarOptions: HtmlToolbarOptions(
                  toolbarPosition: ToolbarPosition.aboveEditor,
                  toolbarType: ToolbarType.nativeGrid,
                  onButtonPressed: (ButtonType type, bool? status, Function? updateStatus) {
                    return true;
                  },
                  onDropdownChanged: (DropdownType type, dynamic changed, Function? updateStatus) {
                    return true;
                  },
                ),
                otherOptions: const OtherOptions(
                  height: 300,
                  decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide.none)),
                ),
                callbacks: Callbacks(
                  onInit: () async {
                    _isEditorReady = true;
                    // 有初始內容 → 設到編輯器
                    final toSet = widget.initialContent ?? _initialEditorContent ?? '';
                    if (toSet.isNotEmpty) {
                      await (_htmlEditorController.setText(toSet) as Future<dynamic>);
                    }
                  },
                  onChangeContent: (String? changed) {},
                  onImageUpload: (FileUpload file) async {
                    // 若你要在這裡上傳圖片到 Storage，可補齊上傳邏輯
                    // 並用 controller.insertNetworkImage(url) 插入
                  },
                  onImageUploadError: (FileUpload? file, String? base64, UploadError error) {
                    String errorMessage = error.toString();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('圖片上傳失敗: $errorMessage')),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}