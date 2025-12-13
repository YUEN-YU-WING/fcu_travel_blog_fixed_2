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
  final bool embedded;

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
    this.embedded = false,
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
      initialContent: args['content'] as String?,
      initialLocation: args['location'] as LatLng?,
      initialAddress: args['address'] as String?,
      initialPlaceName: args['placeName'] as String?,
      initialThumbnailImageUrl: args['thumbnailUrl'] as String?,
      initialThumbnailFileName: args['thumbnailFileName'] as String?,
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

    if (widget.articleId != null) {
      _fetchArticle();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _placeNameController.dispose();
    super.dispose();
  }

  // --- 關鍵字索引生成 (省略內容，保持不變) ---
  List<String> _generateKeywords(String title, String htmlContent, String placeName) {
    String plainTextContent = htmlContent.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
    String text = '$title $placeName $plainTextContent'.toLowerCase();
    Set<String> keywords = {};
    text.split(RegExp(r'\s+')).forEach((word) {
      if (word.isNotEmpty) keywords.add(word);
    });
    String cleanText = text.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]'), '');
    for (int i = 0; i < cleanText.length; i++) {
      keywords.add(cleanText[i]);
      if (i + 1 < cleanText.length) keywords.add(cleanText.substring(i, i + 2));
      if (i + 2 < cleanText.length) keywords.add(cleanText.substring(i, i + 3));
    }
    return keywords.where((k) => k.isNotEmpty && !RegExp(r'^[.,\/#!$%\^&\*;:{}=\-_`~()。，、？！]+$').hasMatch(k)).toList();
  }

  Future<void> _fetchArticle() async {
    // (省略內容，保持不變)
    if (_titleController.text.isEmpty) setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('articles').doc(widget.articleId).get();
      if (doc.exists) {
        final data = doc.data();
        if (!mounted) return;
        setState(() {
          _titleController.text = data?['title'] ?? '';
          _placeNameController.text = data?['placeName'] ?? '';
          _initialEditorContent = data?['content'];
          if (data?['location'] != null) {
            final GeoPoint geoPoint = data!['location'];
            _selectedLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
          }
          _selectedAddress = data?['address'] ?? '';
          _thumbnailImageUrl = data?['thumbnailImageUrl'] ?? '';
          _thumbnailFileName = data?['thumbnailFileName'] ?? '';
        });
        if (_isEditorReady && _initialEditorContent != null) {
          _htmlEditorController.setText(_initialEditorContent!);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('載入文章失敗: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveArticle() async {
    // (省略內容，保持不變)
    final title = _titleController.text.trim();
    final placeName = _placeNameController.text.trim();
    final content = await _htmlEditorController.getText();
    final user = FirebaseAuth.instance.currentUser;

    if (title.isEmpty || content.isEmpty || placeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('標題、內容和地標名稱都不能為空')));
      return;
    }
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入')));
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請選擇一個地點')));
      return;
    }
    if (_thumbnailImageUrl == null || _thumbnailImageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請選擇一張圖片作為遊記縮圖')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final keywords = _generateKeywords(title, content, placeName);
      final String authorName = user.displayName ?? '未命名用戶';
      final String? authorPhotoUrl = user.photoURL;

      final dataToSave = {
        'title': title,
        'content': content,
        'placeName': placeName,
        'location': GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        'address': _selectedAddress,
        'thumbnailImageUrl': _thumbnailImageUrl,
        'thumbnailFileName': _thumbnailFileName,
        'keywords': keywords,
        'updatedAt': FieldValue.serverTimestamp(),
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
      };

      if (widget.articleId == null) {
        await FirebaseFirestore.instance.collection('articles').add({
          ...dataToSave,
          'ownerUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'isPublic': false,
        });
      } else {
        await FirebaseFirestore.instance.collection('articles').doc(widget.articleId).update(dataToSave);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('儲存成功！')));
      if (!widget.embedded) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLocation() async {
    // (省略內容，保持不變)
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const MapPickerPage()));
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedLocation = result['location'] as LatLng;
        _selectedAddress = result['address'] as String;
        _placeNameController.text = result['placeName'] as String? ?? _placeNameController.text;
      });
    }
  }

  // 設定遊記縮圖 (保持不變)
  Future<void> _pickThumbnail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        // 這是原本選取縮圖的邏輯
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

  // 🔥 [新增] 編輯器內插入圖片的方法
  Future<void> _insertImageFromAlbum() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能選擇圖片')),
      );
      return;
    }

    // 開啟相簿頁面 (選擇模式)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AlbumFolderPage(
          isPickingImage: true,
          // allowMultiple: false, // 如果您之後想支援多選，這裡可以調整
        ),
      ),
    );

    // 處理回傳結果
    if (result != null && result is Map<String, dynamic>) {
      final imageUrl = result['imageUrl'] as String?;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        // 將圖片網址插入編輯器
        // 這裡會生成 <img src="imageUrl"> 標籤
        _htmlEditorController.insertNetworkImage(imageUrl);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 為了避免鍵盤跳出時畫面被擠壓導致錯誤，可以設為 false (視需求而定)
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.articleId == null ? '新增文章' : '編輯文章'),
        automaticallyImplyLeading: !widget.embedded,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _pickLocation,
            tooltip: '重新選擇地點',
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
          : Column( // 1. 改用 Column，移除 SingleChildScrollView
        children: [
          // 上半部：表單區域 (標題、地名、圖片)
          // 如果上半部內容很多，可以只在這裡包 SingleChildScrollView
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '標題',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _placeNameController,
                  decoration: const InputDecoration(
                    labelText: '地標名稱',
                    hintText: '例如：台北101',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('遊記縮圖:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _pickThumbnail,
                      icon: const Icon(Icons.photo_library),
                      label: Text(_thumbnailImageUrl != null && _thumbnailImageUrl!.isNotEmpty ? '更改縮圖' : '選擇縮圖'),
                    ),
                  ],
                ),
                if (_thumbnailImageUrl != null && _thumbnailImageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: CachedNetworkImage(
                        imageUrl: _thumbnailImageUrl!,
                        width: double.infinity, // 讓圖片寬度自適應
                        height: 120,            // 限制預覽高度，避免佔太多空間
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                  ),
                if (_selectedAddress != null && _selectedAddress!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_pin, color: Colors.blueGrey, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _selectedAddress!,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1), // 分隔線

          // 下半部：編輯器 (使用 Expanded 填滿剩餘空間)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
              ),
              // 使用 LayoutBuilder 獲取當前剩餘的確切高度
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return HtmlEditor(
                    controller: _htmlEditorController,
                    htmlEditorOptions: HtmlEditorOptions(
                      hint: "請輸入遊記內容...",
                      shouldEnsureVisible: true,
                      adjustHeightForKeyboard: false, // 關閉自動調整，交給 Flutter 佈局
                    ),
                    htmlToolbarOptions: HtmlToolbarOptions(
                      toolbarPosition: ToolbarPosition.aboveEditor,
                      toolbarType: ToolbarType.nativeGrid,
                      // 修正之前的錯誤：這裡使用的是 ButtonType.picture
                      onButtonPressed: (ButtonType type, bool? status, Function? updateStatus) {
                        if (type == ButtonType.picture) {
                          _insertImageFromAlbum();
                          return false;
                        }
                        return true;
                      },
                    ),
                    otherOptions: OtherOptions(
                      // 關鍵點：將高度設為 constraints.maxHeight，強制填滿 Expanded 區域
                      height: constraints.maxHeight,
                      decoration: const BoxDecoration(border: Border.fromBorderSide(BorderSide.none)),
                    ),
                    callbacks: Callbacks(
                      onInit: () async {
                        _isEditorReady = true;
                        final toSet = widget.initialContent ?? _initialEditorContent ?? '';
                        if (toSet.isNotEmpty) {
                          await (_htmlEditorController.setText(toSet) as Future<dynamic>);
                        }
                      },
                      // 處理點擊編輯器時的焦點問題
                      onFocus: () {
                        // 如果有需要，可以在這裡處理滾動
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}