import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:html_editor_enhanced/html_editor.dart'; // 正確的引入
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'map_picker_page.dart';
import 'album_folder_page.dart';

class EditArticlePage extends StatefulWidget {
  final String? articleId;
  final String? initialTitle;
  final String? initialContent; // 現在會是 HTML 內容
  final LatLng? initialLocation;
  final String? initialAddress;
  final String? initialPlaceName;
  final String? initialThumbnailImageUrl;
  final String? initialThumbnailFileName;
  final bool? initialIsPublic; // 新增公開狀態

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
    this.initialIsPublic, // 接收公開狀態
  });

  static EditArticlePage fromRouteArguments(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    return EditArticlePage(
      articleId: args['articleId'] as String?,
      initialTitle: args['initialTitle'] as String?,
      initialContent: args['content'] as String?, // 這裡也要改為 'content'
      initialLocation: args['location'] as LatLng?,
      initialAddress: args['address'] as String?,
      initialPlaceName: args['placeName'] as String?,
      initialThumbnailImageUrl: args['thumbnailImageUrl'] as String?,
      initialThumbnailFileName: args['thumbnailFileName'] as String?,
      initialIsPublic: args['isPublic'] as bool?, // 從路由參數獲取公開狀態
    );
  }

  @override
  State<EditArticlePage> createState() => _EditArticlePageState();
}

class _EditArticlePageState extends State<EditArticlePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _placeNameController;
  late HtmlEditorController _htmlEditorController; // HTML 編輯器控制器

  LatLng? _selectedLocation;
  String? _selectedAddress;
  String? _thumbnailImageUrl;
  String? _thumbnailFileName;
  bool _isPublic = false; // 預設為不公開

  bool _isLoading = false;
  String? _initialEditorContent; // 新增：用於儲存編輯器的初始內容

  // 標記編輯器是否已經準備好，避免過早 setText
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

    // 這裡的邏輯需要調整，確保在 HTML 編輯器完全初始化後再設定內容
    // 我們將這個初始內容設置移動到 onInit 回調中
    if (widget.articleId != null &&
        (_titleController.text.isEmpty ||
            _initialEditorContent == null || // 檢查編輯器內容是否已從路由傳入
            _selectedLocation == null ||
            _placeNameController.text.isEmpty ||
            _thumbnailImageUrl == null ||
            widget.initialIsPublic == null)) {
      print('initState: ArticleId exists, fetching full article data from Firestore...');
      _fetchArticle();
    } else {
      print('initState: No need to fetch. ArticleId: ${widget.articleId}, initialContent is: ${_initialEditorContent != null ? 'present' : 'absent'}');
    }

  }

  @override
  void dispose() {
    _titleController.dispose();
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
        _placeNameController.text = data?['placeName'] ?? '';
        // --- 核心修改：將獲取的內容保存到 _initialEditorContent ---
        _initialEditorContent = data?['content'];
        print('fetchArticle: Fetched content from Firestore: ${_initialEditorContent?.length.clamp(0, 100)} chars.');

        if (data?['location'] != null) {
          final GeoPoint geoPoint = data!['location'];
          _selectedLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
        }
        _selectedAddress = data?['address'] ?? '';
        _thumbnailImageUrl = data?['thumbnailImageUrl'] ?? '';
        _thumbnailFileName = data?['thumbnailFileName'] ?? '';
        _isPublic = data?['isPublic'] ?? false; // 載入公開狀態
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入文章失敗: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }

  }

  Future<void> _saveArticle() async {
    final title = _titleController.text.trim();
    final placeName = _placeNameController.text.trim();
    final content = await _htmlEditorController.getText(); // 從 HTML 編輯器獲取內容
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
        'content': content, // 儲存 HTML 內容
        'placeName': placeName,
        'location': GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        'address': _selectedAddress,
        'thumbnailImageUrl': _thumbnailImageUrl,
        'thumbnailFileName': _thumbnailFileName,
        'isPublic': _isPublic, // 儲存公開狀態
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
                        errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, size: 100),
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
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: HtmlEditor(
                controller: _htmlEditorController,
                htmlEditorOptions: HtmlEditorOptions(
                  // initialText: widget.initialContent, // 這裡已經移除了
                  hint: "請輸入遊記內容...",
                  shouldEnsureVisible: true,
                  // autoAdjustHeight: true, // 嘗試將這個設定為 false 或不設定
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
                  height: 300, // 我們在這裡已經設定了高度
                  decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide.none)),
                ),
                callbacks: Callbacks(
                  onInit: () async {
                    print("Callbacks: onInit triggered. Editor is now ready.");
                    _isEditorReady = true;

                    if (_initialEditorContent != null && _initialEditorContent!.isNotEmpty) {
                      // 將 await 的調用結果轉換為一個 Future<dynamic>
                      // 這是一種避免 Dart 分析器對 Future<void> 過於嚴格的變通方法
                      await (_htmlEditorController.setText(_initialEditorContent!) as Future<dynamic>);
                      print('onInit: Initial content set via setText.');
                    } else {
                      print('onInit: No initial content to set yet.');
                    }
                  },
                  onChangeContent: (String? changed) {
                    // print("Content changed to: $changed");
                  },
                  onImageUpload: (FileUpload file) async {
                    print("Image upload requested: ${file.name}");
                    // ...
                  },
                  onImageUploadError: (FileUpload? file, String? base64, UploadError error) {
                    String errorMessage = '未知圖片上傳錯誤';
                    if (error != null) {
                      errorMessage = error.toString();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('圖片上傳失敗: $errorMessage')),
                    );
                    print('圖片上傳失敗: $errorMessage');
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