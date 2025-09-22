import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'vision_service.dart';
import 'package:flutter/services.dart';

// 資料結構
class ArticleImage {
  final String id;
  final String fileName;
  final String storagePath; // 注意：你的欄位名稱
  final String albumId;
  final String ownerUid;
  final DateTime uploadedAt;

  ArticleImage({
    required this.id,
    required this.fileName,
    required this.storagePath,
    required this.albumId,
    required this.ownerUid,
    required this.uploadedAt,
  });

  factory ArticleImage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ArticleImage(
      id: doc.id,
      fileName: data['fileName'] ?? '',
      storagePath: data['storagePath'] ?? '', // 和你原本一致
      albumId: data['albumId'] ?? '',
      ownerUid: data['ownerUid'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
    );
  }
}

Future<List<ArticleImage>> loadImagesFromDatabase() async {
  final query = await FirebaseFirestore.instance.collection('photos').get();
  return query.docs.map((doc) => ArticleImage.fromDoc(doc)).toList();
}

Future<String> getDownloadUrl(String path) async {
  return FirebaseStorage.instance.ref().child(path).getDownloadURL();
}

Future<void> deleteImage(ArticleImage img) async {
  try {
    await FirebaseStorage.instance.ref().child(img.storagePath).delete();
  } catch (_) {}
  await FirebaseFirestore.instance.collection('photos').doc(img.id).delete();
}

const List<Map<String, String>> interactiveQuestions = [
  {
    "key": "order",
    "question": "此圖片的瀏覽順序？（例：第1張、第2張...）",
    "hint": "請輸入瀏覽順序",
  },
  {
    "key": "note",
    "question": "你想補充的說明或感受？",
    "hint": "請輸入說明",
  },
];

class ArticleInteractiveEditor extends StatefulWidget {
  const ArticleInteractiveEditor({super.key});

  @override
  State<ArticleInteractiveEditor> createState() => _ArticleInteractiveEditorState();
}

class _ArticleInteractiveEditorState extends State<ArticleInteractiveEditor> {
  List<ArticleImage> _images = [];
  bool _loading = false;
  final Map<String, Map<String, String>> _answers = {}; // imageId => {key: answer}
  final Set<String> _selectedImageIds = {};
  final Map<String, String> _landmarkResults = {}; // imageId => 地標名稱
  String _articlePreview = '';

  //final _visionService = VisionService(serverUrl: 'http://10.0.2.2:8080'); // Android 模擬器用
  final _visionService = VisionService(serverUrl: 'http://localhost:8080'); // Web or iOS 用

  void _generateArticlePreview() async {
    List<String> sections = [];
    for (final img in _images.where((img) => _selectedImageIds.contains(img.id))) {
      final ans = _answers[img.id] ?? {};
      final order = ans['order'] ?? '';
      final note = ans['note'] ?? '';
      final landmark = _landmarkResults[img.id] ?? '';
      final imgUrl = await getDownloadUrl(img.storagePath);

      String section = '';
      if (order.isNotEmpty) section += '第$order張';
      if (landmark.isNotEmpty) section += '：$landmark';
      section += '\n';
      if (note.isNotEmpty) section += '說明：$note\n';
      if (landmark.isNotEmpty) section += '地標：$landmark\n';
      section += '圖片：$imgUrl\n';
      sections.add(section);
    }
    setState(() {
      _articlePreview = sections.join('\n');
    });
  }


  // 串接 AI 地標分析
  Future<void> _analyzeLandmarksForSelected() async {
    setState(() => _loading = true);
    for (final img in _images.where((img) => _selectedImageIds.contains(img.id))) {
      final url = await getDownloadUrl(img.storagePath);
      final result = await _visionService.detectLandmarkByUrl(url);
      if (result.isNotEmpty) {
        _landmarkResults[img.id] = result;
      }
    }
    setState(() => _loading = false);
    _generateArticlePreview();
  }


  // 沒有用到，呼叫 API，回傳地標名稱
  Future<String?> _analyzeLandmark(String imageUrl) async {
    final resp = await http.post(
      Uri.parse('https://your-ai-api.com/landmark'), // 換成你的API
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'imageUrl': imageUrl}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['landmark'] as String?;
    }
    return null;
  }

  // UI顯示地標
  Widget _buildLandmarkResult(ArticleImage img) {
    final landmark = _landmarkResults[img.id];
    if (landmark == null || landmark.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.green),
        const SizedBox(width: 4),
        Text("地標: $landmark", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);
    _images = await loadImagesFromDatabase();
    setState(() => _loading = false);
  }

  // 問答
  Future<void> _showInteractiveQuestions(ArticleImage img) async {
    final downloadUrl = await getDownloadUrl(img.storagePath);
    Map<String, String> answers = {};
    for (var q in interactiveQuestions) {
      final ans = await _showSingleQuestionDialog(q['question']!, q['hint']!, downloadUrl);
      if (ans != null && ans.isNotEmpty) {
        answers[q['key']!] = ans;
      }
    }
    if (answers.isNotEmpty) {
      _answers[img.id] = answers;
      setState(() {}); // 更新 UI
    }
  }

  // 在問答或地標分析完後呼叫
  Future<void> _showInteractiveQuestionsForSelected() async {
    for (final img in _images.where((img) => _selectedImageIds.contains(img.id))) {
      await _showInteractiveQuestions(img);
    }
    _generateArticlePreview();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已完成所有選取圖片的問答')));
  }

  Future<String?> _showSingleQuestionDialog(String question, String hint, String imageUrl) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("互動問題"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(imageUrl, height: 120),
            const SizedBox(height: 8),
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

  Widget _buildAnswerList(ArticleImage img) {
    final answers = _answers[img.id];
    if (answers == null || answers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...answers.entries.map((e) => Text("${e.key}: ${e.value}", style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildImageWidget(ArticleImage img) {
    return FutureBuilder<String>(
      future: getDownloadUrl(img.storagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return Column(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 40),
              const Text("圖片載入失敗"),
              Text(snapshot.error?.toString() ?? '', style: const TextStyle(fontSize: 10)),
            ],
          );
        }
        return Image.network(snapshot.data!, height: 180, fit: BoxFit.cover);
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, ArticleImage img) async {
    final downloadUrl = await getDownloadUrl(img.storagePath);
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("刪除圖片"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(downloadUrl, height: 100),
            const SizedBox(height: 10),
            const Text("確定要刪除此圖片嗎？"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("刪除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("文章編輯：互動圖片問答")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.separated(
              // ... 圖片多選列表 ...
              padding: const EdgeInsets.all(16),
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, idx) {
                final img = _images[idx];
                return Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildImageWidget(img),
                            const SizedBox(height: 12),
                            Text("圖片ID: ${img.id}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text("檔名: ${img.fileName}"),
                            Text("Storage路徑: ${img.storagePath}"),
                            Text("所屬相簿: ${img.albumId}"),
                            Text("上傳者UID: ${img.ownerUid}"),
                            Text("上傳時間: ${img.uploadedAt}"),
                            const SizedBox(height: 8),
                            _buildAnswerList(img),
                            _buildLandmarkResult(img),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.question_answer),
                                  label: Text(_answers.containsKey(img.id) ? "修改回答" : "開始問答"),
                                  onPressed: () => _showInteractiveQuestions(img),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  icon: const Icon(Icons.delete),
                                  label: const Text("刪除"),
                                  onPressed: () async {
                                    final ok = await _confirmDelete(context, img);
                                    if (ok) {
                                      setState(() => _loading = true);
                                      await deleteImage(img);
                                      await _loadImages();
                                      setState(() => _loading = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('已刪除圖片')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        // 多選勾選框 (右上角)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Checkbox(
                            value: _selectedImageIds.contains(img.id),
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedImageIds.add(img.id);
                                } else {
                                  _selectedImageIds.remove(img.id);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // 按鈕區
          if (_selectedImageIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text("開始問答（${_selectedImageIds.length}張）"),
                      onPressed: _showInteractiveQuestionsForSelected,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.location_on),
                      label: Text("分析地標（${_selectedImageIds.length}張）"),
                      onPressed: _analyzeLandmarksForSelected,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 自動排版區
          if (_articlePreview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('文章排版範例', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: SelectableText(_articlePreview),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('複製到剪貼簿'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _articlePreview));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製')));
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}