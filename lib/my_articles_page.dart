// lib/my_articles_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyArticlesPage extends StatelessWidget {
  /// 在後台右側嵌入時請設為 true，如：const MyArticlesPage(embedded: true)
  /// 獨立開頁（一般 push）保持預設 false 會顯示系統返回鍵
  final bool embedded;

  const MyArticlesPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('我的文章'),
          automaticallyImplyLeading: !embedded,
        ),
        body: const Center(child: Text('請先登入')),
      );
    }

    final articlesStream = FirebaseFirestore.instance
        .collection('articles')
        .where('authorUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的文章'),
        // ✅ 核心：在後台嵌入時不顯示返回鍵；獨立開頁才顯示
        automaticallyImplyLeading: !embedded,
      ),
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
                  await Navigator.pushNamed(
                    context,
                    '/edit_article',
                    arguments: {
                      'articleId': doc.id,
                      'initialTitle': title,
                      // ✅ 這裡用 `content` 才能對上 EditArticlePage.fromRouteArguments
                      'content': content,
                    },
                  );
                  // StreamBuilder 會自動反映資料更新，不需手動刷新
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 跳轉到新增頁（無初始資料）
          await Navigator.pushNamed(context, '/edit_article');
        },
        tooltip: '新增文章',
        child: const Icon(Icons.add),
      ),
    );
  }
}
