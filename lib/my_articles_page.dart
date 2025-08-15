import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_article_page.dart';

class MyArticlesPage extends StatelessWidget {
  const MyArticlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('請先登入'));
    }

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
          if (snapshot.hasError) {
            return Center(child: Text('載入文章失敗: ${snapshot.error}'));
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
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final title = data['title'] ?? '';
              final content = data['content'] ?? '';
              return ListTile(
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  content.length > 50 ? '${content.substring(0, 50)}...' : content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // 跳轉到編輯頁，帶入文章內容
                  final result = await Navigator.pushNamed(
                    context,
                    '/edit_article',
                    arguments: {
                      'articleId': doc.id,
                      'initialTitle': title,
                      'initialContent': content,
                    },
                  );
                  // 若返回 true，可做刷新，但 StreamBuilder 會自動處理
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 跳轉到新增頁（無初始資料）
          final result = await Navigator.pushNamed(context, '/edit_article');
          // 若返回 true，可做刷新，但 StreamBuilder 會自動處理
        },
        child: const Icon(Icons.add),
        tooltip: '新增文章',
      ),
    );
  }
}