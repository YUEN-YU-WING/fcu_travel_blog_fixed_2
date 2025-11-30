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
  final String? initialContent; // HTML 內容
  final LatLng? initialLocation;
  final String? initialAddress;
  final String? initialPlaceName;
  final String? initialThumbnailImageUrl;
  final String? initialThumbnailFileName;
  // final bool? initialIsPublic; // <--- 移除此行

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
    // this.initialIsPublic, // <--- 移除此行
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
      // initialIsPublic: args['isPublic'] as bool? ?? false, // <--- 移除此行
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
  // bool _isPublic = false; // <--- 移除此行

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

    // 原本的邏輯是「如果資料缺漏才去抓」，導致如果有舊資料(如舊縮圖)就會略過更新。
    // 改為：「只要是編輯舊文章 (articleId != null)，就強制去 Firestore 抓最新資料」。
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
    // 只有在完全沒有標題（代表可能是第一次載入且沒傳參）時才顯示全螢幕 Loading
    // 這樣如果有舊資料，使用者會先看到舊的，然後瞬間跳轉成新的，體驗較流暢
    if (_titleController.text.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('articles')
          .doc(widget.articleId)
          .get();
      if (doc.exists) {
        final data = doc.data();

        // 這裡加上 mounted 檢查，並使用 setState 更新畫面
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
          // 這裡會把舊的縮圖 URL 覆蓋成最新的
          _thumbnailImageUrl = data?['thumbnailImageUrl'] ?? ''; // 注意：這裡要確認你的 Firestore 欄位是 thumbnailUrl 還是 thumbnailImageUrl
          _thumbnailFileName = data?['thumbnailFileName'] ?? '';
        });

        // 如果編輯器已經準備好了，更新編輯器內容
        if (_isEditorReady && _initialEditorContent != null) {
          _htmlEditorController.setText(_initialEditorContent!);
        }
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

      // ✅ 新增：準備作者資訊 (Snapshot)
      // 這樣可以確保文章顯示時不用再去查使用者資料表
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
        // ✅ 寫入作者資訊
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
      };

      if (widget.articleId == null) {
        // 新增文章
        await FirebaseFirestore.instance.collection('articles').add({
          ...dataToSave,
          'ownerUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'isPublic': false, // 新文章預設為不公開
        });
      } else {
        // 更新文章
        // 注意：這裡也會更新 authorName 和 authorPhotoUrl
        // 如果您希望舊文章保留舊的頭像/名字，可以把這兩個欄位移到上面的 if (widget.articleId == null) 裡面
        // 但通常更新文章時順便更新作者資訊是合理的
        await FirebaseFirestore.instance.collection('articles').doc(widget.articleId).update(dataToSave);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('儲存成功！')));

      if (!widget.embedded) {
        Navigator.pop(context, true);
      }
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 100),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
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
            // <--- 原來的「公開發表」Switch 已移除
            const SizedBox(height: 16),

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
                    final toSet = widget.initialContent ?? _initialEditorContent ?? '';
                    if (toSet.isNotEmpty) {
                      await (_htmlEditorController.setText(toSet) as Future<dynamic>);
                    }
                  },
                  onChangeContent: (String? changed) {},
                  onImageUpload: (FileUpload file) async {},
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