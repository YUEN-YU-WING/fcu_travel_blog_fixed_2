import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestPhotoPage extends StatelessWidget {
  const TestPhotoPage({super.key});

  Future<String?> _loadOneImageUrl() async {
    final query = await FirebaseFirestore.instance
        .collection('photos')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final data = query.docs.first.data();
    return data['url'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("圖片測試")),
      body: FutureBuilder<String?>(
        future: _loadOneImageUrl(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Firestore 沒有圖片 URL"));
          }

          final url = snapshot.data!;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("測試載入圖片：", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Image.network(
                  url,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text("載入失敗: $error"),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                SelectableText("URL: $url"), // 方便檢查
              ],
            ),
          );
        },
      ),
    );
  }
}
