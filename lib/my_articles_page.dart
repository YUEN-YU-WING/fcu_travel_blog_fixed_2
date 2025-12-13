import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyArticlesPage extends StatefulWidget {
  final bool embedded;

  const MyArticlesPage({super.key, this.embedded = false});

  @override
  State<MyArticlesPage> createState() => _MyArticlesPageState();
}

class _MyArticlesPageState extends State<MyArticlesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 切換公開狀態
  Future<void> _togglePublicStatus(BuildContext context, String articleId, bool currentStatus) async {
    try {
      await _firestore.collection('articles').doc(articleId).update({
        'isPublic': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentStatus ? '已設為私人文章' : '已設為公開文章'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失敗: $e')));
    }
  }

  // 刪除文章
  Future<void> _deleteArticle(BuildContext context, String articleId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除文章'),
        content: Text('確定要刪除「$title」嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('articles').doc(articleId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('文章已刪除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刪除失敗: $e')));
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
        .orderBy('updatedAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('文章管理'),
        automaticallyImplyLeading: !widget.embedded,
        elevation: 0,
        // 🔥 修改處：將新增按鈕移至右上角 Actions
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新增文章',
            onPressed: () {
              Navigator.pushNamed(context, '/edit_article');
            },
          ),
        ],
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('你還沒有撰寫任何遊記', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('開始寫作'),
                    onPressed: () => Navigator.pushNamed(context, '/edit_article'),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final articleId = doc.id;

              final title = data['title'] ?? '無標題';
              final placeName = data['placeName'] ?? '未指定地點';
              final content = data['content'] ?? '';
              final thumbnailUrl = data['thumbnailImageUrl'];
              final isPublic = data['isPublic'] ?? false;
              final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
              final dateStr = updatedAt != null
                  ? "${updatedAt.year}/${updatedAt.month}/${updatedAt.day} ${updatedAt.hour}:${updatedAt.minute.toString().padLeft(2, '0')}"
                  : "未知時間";

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isPublic ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/edit_article',
                      arguments: {
                        'articleId': articleId,
                        'initialTitle': title,
                        'content': content,
                      },
                    );
                  },
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                imageUrl: thumbnailUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 80, height: 80,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              )
                                  : Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Icon(Icons.photo, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPublic ? Colors.green[50] : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: isPublic ? Colors.green : Colors.grey),
                                        ),
                                        child: Text(
                                          isPublic ? '公開' : '私密',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isPublic ? Colors.green[700] : Colors.grey[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: Colors.blueGrey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          placeName,
                                          style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '最後修訂: $dateStr',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, indent: 12, endIndent: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Switch(
                                  value: isPublic,
                                  onChanged: (val) => _togglePublicStatus(context, articleId, isPublic),
                                  activeColor: Colors.green,
                                ),
                                Text(
                                  isPublic ? "已發布" : "草稿/私密",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isPublic ? Colors.green[700] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/edit_article',
                                      arguments: {
                                        'articleId': articleId,
                                        'initialTitle': title,
                                        'content': content,
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                  label: const Text('編輯', style: TextStyle(color: Colors.blue)),
                                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: '刪除文章',
                                  onPressed: () => _deleteArticle(context, articleId, title),
                                ),
                              ],
                            ),
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
      // 🔥 修改處：已移除 floatingActionButton
    );
  }
}