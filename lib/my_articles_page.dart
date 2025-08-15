import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyArticlesPage extends StatelessWidget {
  const MyArticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('請先登入'));
    }

    // Firestore 資料結構假設：articles(collection) -> { title, content, authorUid, createdAt }
    final articlesStream = FirebaseFirestore.instance
        .collection('articles')
        .where('authorUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('我的文章')),
      body: StreamBuilder<QuerySnapshot>(
        stream: articlesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('你還沒有文章'));
          }

          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['title'] ?? ''),
                subtitle: Text(
                  data['content'] != null && data['content'].length > 50
                      ? '${data['content'].substring(0, 50)}...'
                      : (data['content'] ?? ''),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // 點擊可前往詳細或編輯頁
                  // Navigator.push(...);
                },
              );
            },
          );
        },
      ),
    );
  }
}