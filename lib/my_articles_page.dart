import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyArticlesPage extends StatelessWidget {
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
              final articleId = doc.id; // 獲取文章 ID
              final title = data['title'] ?? '';
              final content = data['content'] ?? '';

              return ListTile(
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  content.length > 50 ? '${content.substring(0, 50)}...' : content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // 新增刪除按鈕
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    // 顯示確認對話框
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('確認刪除'),
                        content: Text('你確定要刪除文章「$title」嗎？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context), // 取消
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); // 關閉對話框
                              _deleteArticle(context, articleId); // 執行刪除
                            },
                            child: const Text('刪除', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    '/edit_article',
                    arguments: {
                      'articleId': articleId,
                      'initialTitle': title,
                      'content': content,
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/edit_article');
        },
        tooltip: '新增文章',
        child: const Icon(Icons.add),
      ),
    );
  }

  // 刪除文章的邏輯
  Future<void> _deleteArticle(BuildContext context, String articleId) async {
    try {
      await FirebaseFirestore.instance.collection('articles').doc(articleId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文章已刪除')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗: $e')),
      );
    }
  }
}