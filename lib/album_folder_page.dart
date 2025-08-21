import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'album_page.dart'; // 單一相簿內容頁

class AlbumFolderPage extends StatefulWidget {
  const AlbumFolderPage({super.key});
  @override
  State<AlbumFolderPage> createState() => _AlbumFolderPageState();
}

class _AlbumFolderPageState extends State<AlbumFolderPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('請先登入'));

    final albumsStream = FirebaseFirestore.instance
        .collection('albums')
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('相簿管理/上傳')),
      body: StreamBuilder<QuerySnapshot>(
        stream: albumsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              childAspectRatio: 0.8,
            ),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // 新增相簿卡片
                return GestureDetector(
                  onTap: () async {
                    final nameController = TextEditingController();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('新增相簿'),
                        content: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: '相簿名稱'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('新增')),
                        ],
                      ),
                    );
                    if (ok == true && nameController.text.trim().isNotEmpty) {
                      await FirebaseFirestore.instance.collection('albums').add({
                        'name': nameController.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                        'ownerUid': user.uid,
                        'coverUrl': null,
                        'photoCount': 0,
                      });
                    }
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add, size: 60, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('新增相簿、資料夾', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final doc = docs[index - 1];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final albumId = doc.id;
              final name = data['name'] as String? ?? '';
              final coverUrl = data['coverUrl'] as String?;
              final photoCount = data['photoCount'] as int? ?? 0;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AlbumPage(albumId: albumId, albumName: name)),
                  );
                },
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            image: coverUrl != null
                                ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover)
                                : null,
                            color: coverUrl == null ? Colors.grey.shade100 : null,
                          ),
                          child: coverUrl == null
                              ? const Center(
                            child: Icon(Icons.photo_album, size: 50, color: Colors.grey),
                          )
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('$photoCount 張相片', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}