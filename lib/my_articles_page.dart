import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 將 MyArticlesPage 轉換為 StatefulWidget
class MyArticlesPage extends StatefulWidget {
  final bool embedded;

  const MyArticlesPage({super.key, this.embedded = false});

  @override
  State<MyArticlesPage> createState() => _MyArticlesPageState();
}

class _MyArticlesPageState extends State<MyArticlesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 用於切換文章公開狀態的函數
  Future<void> _togglePublicStatus(BuildContext context, String articleId, bool currentStatus) async {
    try {
      await _firestore.collection('articles').doc(articleId).update({
        'isPublic': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(), // 更新修改時間
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('文章狀態已更新為 ${!currentStatus ? "公開" : "非公開"}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新狀態失敗: $e')),
      );
    }
  }

  // 刪除文章的邏輯
  Future<void> _deleteArticle(BuildContext context, String articleId) async {
    try {
      await _firestore.collection('articles').doc(articleId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文章已刪除')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('我的文章'),
          automaticallyImplyLeading: !widget.embedded,
        ),
        body: const Center(child: Text('請先登入')),
      );
    }

    final articlesStream = _firestore
        .collection('articles')
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的文章'),
        automaticallyImplyLeading: !widget.embedded,
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
              final articleId = doc.id;
              final title = data['title'] ?? '';
              final content = data['content'] ?? '';
              final isPublic = data['isPublic'] ?? false; // 獲取 isPublic 狀態

              return ListTile(
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  content.length > 50 ? '${content.substring(0, 50)}...' : content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min, // 確保 Row 只佔用所需的空間
                  children: [
                    Tooltip(
                      message: isPublic ? '公開文章' : '私人文章',
                      child: Switch(
                        value: isPublic,
                        onChanged: (newValue) {
                          _togglePublicStatus(context, articleId, isPublic);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('確認刪除'),
                            content: Text('你確定要刪除文章「$title」嗎？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteArticle(context, articleId);
                                },
                                child: const Text('刪除', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    '/edit_article',
                    arguments: {
                      'articleId': articleId,
                      'initialTitle': title,
                      'content': content,
                      // 不需要傳遞 isPublic 給編輯頁面了
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
}