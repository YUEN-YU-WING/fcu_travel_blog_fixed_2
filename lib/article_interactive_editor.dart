import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// 真正的資料庫圖片資料結構
class ArticleImage {
  final String id;
  final String fileName;
  final String storagePath; // Storage 路徑
  final String albumId;
  final String ownerUid;
  final DateTime uploadedAt; // DateTime

  ArticleImage({
    required this.id,
    required this.fileName,
    required this.storagePath,
    required this.albumId,
    required this.ownerUid,
    required this.uploadedAt,
  });

  // Firestore 轉換
  factory ArticleImage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ArticleImage(
      id: doc.id,
      fileName: data['fileName'] ?? '',
      storagePath: data['storagePath'] ?? '', // Firestore 請存 Storage 的檔案路徑
      albumId: data['albumId'] ?? '',
      ownerUid: data['ownerUid'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
    );
  }
}

// 從 Firestore photos 集合載入
Future<List<ArticleImage>> loadImagesFromDatabase() async {
  final query = await FirebaseFirestore.instance.collection('photos').get();
  return query.docs.map((doc) => ArticleImage.fromDoc(doc)).toList();
}

// 根據 Storage 路徑取得 downloadUrl
Future<String> getDownloadUrl(String storagePath) async {
  return FirebaseStorage.instance.ref().child(storagePath).getDownloadURL();
}

// 刪除圖片：包含 Storage 與 Firestore
Future<void> deleteImage(ArticleImage img) async {
  try {
    await FirebaseStorage.instance.ref().child(img.storagePath).delete();
  } catch (_) {}
  await FirebaseFirestore.instance.collection('photos').doc(img.id).delete();
}

// 問題設定，可擴充
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

  // 彈出互動問答（多題）
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

  // 單題 Dialog
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

  // 彈出刪除確認 Dialog
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
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _images.length,
        separatorBuilder: (_, _) => const SizedBox(height: 24),
        itemBuilder: (context, idx) {
          final img = _images[idx];
          return Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
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
            ),
          );
        },
      ),
    );
  }
}