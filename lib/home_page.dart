import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/my_app_bar.dart';
import 'notifications_page.dart';
import 'backend_home.dart';
import 'article_detail_page.dart'; // 引入文章詳情頁面

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已登出')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登出失敗：$e')),
      );
    }
  }

  void _onAvatarTap(BuildContext rootContext) {
    final user = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: rootContext,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        if (user == null) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1),
                  title: const Text('註冊'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Future.microtask(() {
                      Navigator.of(rootContext).pushNamed('/register');
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('登入'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Future.microtask(() {
                      Navigator.of(rootContext).pushNamed('/login');
                    });
                  },
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('個人後台'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.microtask(() {
                    Navigator.of(rootContext).push(
                      MaterialPageRoute(builder: (_) => const BackendHomePage()),
                    );
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('登出'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _logout(rootContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? '訪客';
    final userPhotoUrl = user?.photoURL;

    return Scaffold(
      appBar: MyAppBar(
        title: '首頁',
        centerTitle: true,
        isHomePage: true,
        avatarUrl: userPhotoUrl,
        onAvatarTap: () => _onAvatarTap(context),
        onNotificationsTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          );
        },
        // 新增搜尋框點擊事件
        onSearchTap: () {
          print('點擊了搜尋框');
          // TODO: 導航到搜尋頁面
        },
        // 新增中間導覽圖示點擊事件
        onNavIconTap: (index) {
          print('點擊了中間導覽圖示：$index');
          // TODO: 根據 index 處理不同的導航或操作
          // 0: 影片
          // 1: 市集
          // 2: 主要首頁 (已經在 onPressed 處理了導航邏輯，這裡主要是額外回調)
        },
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左側邊欄
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.blueGrey[50],
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: userPhotoUrl != null ? NetworkImage(userPhotoUrl) : null,
                      child: userPhotoUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(userName),
                    onTap: () {
                      print('點擊了個人檔案');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('朋友'),
                    onTap: () {
                      print('點擊了朋友');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.storefront),
                    title: const Text('Marketplace'),
                    onTap: () {
                      print('點擊了 Marketplace');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('社團'),
                    onTap: () {
                      print('點擊了社團');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark_border),
                    title: const Text('我的收藏'),
                    onTap: () {
                      print('點擊了我的收藏');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text('活動'),
                    onTap: () {
                      print('點擊了活動');
                    },
                  ),
                ],
              ),
            ),
          ),
          // 中間內容區
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('articles')
                    .where('isPublic', isEqualTo: true)
                    .orderBy('updatedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('出錯了: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('目前沒有公開文章。'));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot document = snapshot.data!.docs[index];
                      Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                      final String articleId = document.id;

                      final String authorName = data['authorName'] ?? '匿名作者';
                      final String authorPhotoUrl = data['authorPhotoUrl'] ?? '';
                      final String title = data['title'] ?? '無標題';
                      final String content = data['content'] ?? '沒有內容';
                      final Timestamp updatedAt = data['updatedAt'] ?? Timestamp.now();
                      final String thumbnailImageUrl = data['thumbnailImageUrl'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        elevation: 1.0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ArticleDetailPage(articleId: articleId),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: authorPhotoUrl.isNotEmpty ? NetworkImage(authorPhotoUrl) : null,
                                      child: authorPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                                    ),
                                    const SizedBox(width: 8.0),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          authorName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          _formatTimestamp(updatedAt),
                                          style: TextStyle(color: Colors.grey[600], fontSize: 12.0),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12.0),
                                if (thumbnailImageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      thumbnailImageUrl,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          alignment: Alignment.center,
                                          height: 200,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                        );
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          alignment: Alignment.center,
                                          height: 200,
                                          color: Colors.grey[300],
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                if (thumbnailImageUrl.isNotEmpty) const SizedBox(height: 12.0),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  content,
                                  style: const TextStyle(fontSize: 14.0),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12.0),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        print('點讚');
                                      },
                                      icon: const Icon(Icons.thumb_up_alt_outlined),
                                      label: const Text('讚'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        print('評論');
                                      },
                                      icon: const Icon(Icons.comment_outlined),
                                      label: const Text('留言'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        print('分享');
                                      },
                                      icon: const Icon(Icons.share_outlined),
                                      label: const Text('分享'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          // 右側邊欄
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.blueGrey[100], // 保持背景色
              padding: const EdgeInsets.all(16.0), // 添加內邊距
              child: ListView( // 使用 ListView 讓內容可滾動
                children: [
                  // 推薦文章 / 熱門話題
                  const Text(
                    '推薦文章',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Card(
                    elevation: 0.5,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.star_border),
                      ),
                      title: const Text('探索 Flutter 最新功能'),
                      subtitle: const Text('由 Admin'),
                      onTap: () {
                        print('點擊了推薦文章 1');
                        // TODO: 導航到特定推薦文章
                      },
                    ),
                  ),
                  Card(
                    elevation: 0.5,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.local_fire_department),
                      ),
                      title: const Text('2023 年最佳程式設計語言'),
                      subtitle: const Text('編輯精選'),
                      onTap: () {
                        print('點擊了推薦文章 2');
                        // TODO: 導航到特定推薦文章
                      },
                    ),
                  ),
                  const Divider(height: 30), // 分隔線
                  // 聯絡方式 / 相關連結
                  const Text(
                    '相關連結',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('官方網站'),
                    onTap: () {
                      print('點擊了官方網站');
                      // TODO: 開啟外部連結
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.facebook),
                    title: const Text('我們的 Facebook 頁面'),
                    onTap: () {
                      print('點擊了 Facebook 頁面');
                      // TODO: 開啟外部連結
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('聯絡我們'),
                    onTap: () {
                      print('點擊了聯絡我們');
                      // TODO: 開啟郵件或聯絡表單
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}