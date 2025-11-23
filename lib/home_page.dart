import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/my_app_bar.dart';
import 'notifications_page.dart';
import 'backend_home.dart';
import 'article_detail_page.dart';
import 'friends_list_page.dart';
import 'friend_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ 新增：搜尋關鍵字狀態
  String _searchKeyword = '';

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
    // ... (保持原有的 BottomSheet 邏輯)
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
                leading: const Icon(Icons.person),
                title: const Text('我的個人檔案'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.microtask(() {
                    Navigator.of(rootContext).push(
                      MaterialPageRoute(
                        builder: (_) => FriendProfilePage(friendId: user.uid), // 導航到自己的個人檔案頁面
                      ),
                    );
                  });
                },
              ),
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

  // ✅ 構建查詢 Stream
  Stream<QuerySnapshot> _buildArticleStream() {
    final collection = FirebaseFirestore.instance.collection('articles');

    // 1. 如果沒有搜尋關鍵字，顯示預設列表 (按時間排序)
    if (_searchKeyword.isEmpty) {
      return collection
          .where('isPublic', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .snapshots();
    }

    // 2. 如果有搜尋關鍵字
    // 注意：Firestore 的 array-contains 無法直接與 orderBy('updatedAt') 混用，除非建立複合索引。
    // 為了避免報錯，這裡我們先不加 orderBy，或者你需要去 Firebase Console 建立索引：
    // Collection: articles -> Fields: isPublic (Asc/Desc), keywords (Array), updatedAt (Desc)
    else {
      return collection
          .where('isPublic', isEqualTo: true)
          .where('keywords', arrayContains: _searchKeyword.toLowerCase()) // 確保關鍵字轉小寫
      // .orderBy('updatedAt', descending: true) // ⚠️ 需要複合索引才能打開
          .snapshots();
    }
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
        // ✅ 處理搜尋事件
        onSearch: (keyword) {
          setState(() {
            _searchKeyword = keyword;
          });
          print('搜尋關鍵字: $_searchKeyword');
        },
        onNavIconTap: (index) {
          print('點擊了中間導覽圖示：$index');
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
                      // **修改這裡：導航到 FriendsListPage**
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FriendsListPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark_border),
                    title: const Text('我的收藏'),
                    onTap: () {
                      print('點擊了我的收藏');
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
                // ✅ 使用動態構建的 Stream
                stream: _buildArticleStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('出錯了: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchKeyword.isNotEmpty
                                ? '找不到包含 "$_searchKeyword" 的文章'
                                : '目前沒有公開文章。',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          if (_searchKeyword.isNotEmpty)
                            TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchKeyword = ''; // 清除搜尋
                                  });
                                },
                                child: const Text('顯示所有文章')
                            )
                        ],
                      ),
                    );
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
                      // final String content = data['content'] ?? '沒有內容';
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
                                // ... 底部按鈕區塊 (保持原樣)
                                const SizedBox(height: 12.0),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.thumb_up_alt_outlined),
                                      label: const Text('讚'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.comment_outlined),
                                      label: const Text('留言'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {},
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
        ],
      ),
    );
  }
}