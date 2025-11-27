import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/my_app_bar.dart';
import 'notifications_page.dart';
import 'backend_home.dart';
import 'article_detail_page.dart';
import 'friends_list_page.dart';
import 'friend_profile_page.dart';
import 'bookmarked_articles_page.dart';
import 'album_folder_page.dart';
import 'pages/browse_collections_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ✅ 用於控制 Drawer 開啟
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _searchKeyword = '';
  String? _currentUserId;
  Stream<DocumentSnapshot>? _currentUserDataStream;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != null) {
      _currentUserDataStream = FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots();
    }
    FirebaseAuth.instance.userChanges().listen((User? user) {
      if (user != null && user.uid != _currentUserId) {
        setState(() {
          _currentUserId = user.uid;
          _currentUserDataStream = FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots();
        });
      } else if (user == null && _currentUserId != null) {
        setState(() {
          _currentUserId = null;
          _currentUserDataStream = null;
        });
      }
    });
  }

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
                leading: const Icon(Icons.person),
                title: const Text('我的個人檔案'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.microtask(() {
                    Navigator.of(rootContext).push(
                      MaterialPageRoute(
                        builder: (_) => FriendProfilePage(friendId: user.uid),
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

  Stream<QuerySnapshot> _buildArticleStream() {
    final collection = FirebaseFirestore.instance.collection('articles');

    if (_searchKeyword.isEmpty) {
      return collection
          .where('isPublic', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .snapshots();
    } else {
      return collection
          .where('isPublic', isEqualTo: true)
          .where('keywords', arrayContains: _searchKeyword.toLowerCase())
          .snapshots();
    }
  }

  Future<void> _toggleLike(String articleId, List<dynamic> likedArticles) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能點讚。')));
      return;
    }
    final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId);
    final articleRef = FirebaseFirestore.instance.collection('articles').doc(articleId);
    final bool hasLiked = likedArticles.contains(articleId);

    try {
      if (hasLiked) {
        await userRef.update({'likedArticles': FieldValue.arrayRemove([articleId])});
        await articleRef.update({'likesCount': FieldValue.increment(-1)});
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消點讚。')));
      } else {
        await userRef.update({'likedArticles': FieldValue.arrayUnion([articleId])});
        await articleRef.update({'likesCount': FieldValue.increment(1)});
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已點讚！')));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
    }
  }

  Future<void> _toggleBookmark(String articleId, List<dynamic> bookmarkedArticles) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能收藏。')));
      return;
    }
    final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId);
    final bool hasBookmarked = bookmarkedArticles.contains(articleId);

    try {
      if (hasBookmarked) {
        await userRef.update({'bookmarkedArticles': FieldValue.arrayRemove([articleId])});
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消收藏。')));
      } else {
        await userRef.update({'bookmarkedArticles': FieldValue.arrayUnion([articleId])});
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功收藏！')));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
    }
  }

  // ✅ 抽取共用側邊欄 Widget (可同時用於 Drawer 與 桌面左側欄)
  Widget _buildSidebarContent(User? user, String? userPhotoUrl, String userName, BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // 若在 Drawer 中可以加個 Header，這裡保持一致
          ListTile(
            leading: CircleAvatar(
              backgroundImage: userPhotoUrl != null ? NetworkImage(userPhotoUrl) : null,
              child: userPhotoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              if (user != null) {
                // 如果是在 Drawer 中點擊，可能需要 pop
                // Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FriendProfilePage(friendId: user.uid)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入')));
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('追隨'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsListPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('我的收藏'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BookmarkedArticlesPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('相簿管理'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AlbumFolderPage(embedded: false)));
            },
          ),
          // 若為手機版 Drawer，可以在這裡補上登出按鈕
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text('登出', style: TextStyle(color: Colors.grey)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? '訪客';
    final userPhotoUrl = user?.photoURL;

    // ✅ 使用 LayoutBuilder 偵測螢幕寬度
    return LayoutBuilder(
      builder: (context, constraints) {
        // 設定斷點，小於 800px 視為手機/平板直向
        final bool isMobile = constraints.maxWidth < 800;

        return Scaffold(
          key: _scaffoldKey, // 綁定 key 以控制 Drawer
          appBar: MyAppBar(
            title: '首頁',
            centerTitle: true,
            isHomePage: true,
            avatarUrl: userPhotoUrl,
            // ✅ 傳遞手機版狀態與漢堡選單回調
            isMobile: isMobile,
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),

            onAvatarTap: () => _onAvatarTap(context),
            onNotificationsTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
            onSearch: (keyword) {
              setState(() => _searchKeyword = keyword);
            },
            onNavIconTap: (index) {
              switch (index) {
                case 0: break;
                case 1:
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BrowseCollectionsPage()));
                  break;
              }
            },
          ),

          // ✅ 手機版專屬側邊選單 (Drawer)
          drawer: isMobile
              ? Drawer(
            width: 250,
            child: _buildSidebarContent(user, userPhotoUrl, userName, context),
          )
              : null,

          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ 電腦版：顯示左側固定側邊欄 (手機版隱藏)
              if (!isMobile)
                Expanded(
                  flex: 2,
                  child: _buildSidebarContent(user, userPhotoUrl, userName, context),
                ),

              // 中間內容區
              Expanded(
                flex: 5,
                child: Container(
                  color: Colors.grey[200],
                  padding: const EdgeInsets.all(16.0),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: _currentUserDataStream,
                    builder: (context, currentUserSnapshot) {
                      List<dynamic> likedArticles = [];
                      List<dynamic> bookmarkedArticles = [];

                      if (currentUserSnapshot.hasData && currentUserSnapshot.data!.exists) {
                        Map<String, dynamic> userData = currentUserSnapshot.data!.data()! as Map<String, dynamic>;
                        likedArticles = userData['likedArticles'] ?? [];
                        bookmarkedArticles = userData['bookmarkedArticles'] ?? [];
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: _buildArticleStream(),
                        builder: (context, articleSnapshot) {
                          if (articleSnapshot.hasError) {
                            return Center(child: Text('出錯了: ${articleSnapshot.error}'));
                          }
                          if (articleSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!articleSnapshot.hasData || articleSnapshot.data!.docs.isEmpty) {
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
                                          setState(() => _searchKeyword = '');
                                        },
                                        child: const Text('顯示所有文章')
                                    )
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: articleSnapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              DocumentSnapshot document = articleSnapshot.data!.docs[index];
                              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                              final String articleId = document.id;

                              final String authorUid = data['authorUid'] ?? '';
                              final String authorName = data['authorName'] ?? '匿名作者';
                              final String authorPhotoUrl = data['authorPhotoUrl'] ?? '';
                              final String title = data['title'] ?? '無標題';
                              final Timestamp updatedAt = data['updatedAt'] ?? Timestamp.now();
                              final String thumbnailImageUrl = data['thumbnailImageUrl'] ?? '';
                              final int likesCount = data['likesCount'] ?? 0;

                              final bool hasLiked = likedArticles.contains(articleId);
                              final bool hasBookmarked = bookmarkedArticles.contains(articleId);

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
                                        // Author Info Row
                                        InkWell(
                                          onTap: authorUid.isNotEmpty ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => FriendProfilePage(friendId: authorUid),
                                              ),
                                            );
                                          } : null,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundImage: authorPhotoUrl.isNotEmpty ? NetworkImage(authorPhotoUrl) : null,
                                                  child: authorPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                                                ),
                                                const SizedBox(width: 8.0),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                    Text(_formatTimestamp(updatedAt), style: TextStyle(color: Colors.grey[600], fontSize: 12.0)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12.0),
                                        // Thumbnail
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
                                        // Title
                                        Text(title, style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12.0),
                                        // Action Buttons
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            TextButton.icon(
                                              onPressed: _currentUserId == null
                                                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能點讚。')))
                                                  : () => _toggleLike(articleId, likedArticles),
                                              icon: Icon(hasLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined, color: hasLiked ? Colors.blue : Colors.grey),
                                              label: Text('讚 ${likesCount > 0 ? likesCount : ''}', style: TextStyle(color: hasLiked ? Colors.blue : Colors.grey)),
                                            ),
                                            TextButton.icon(
                                              onPressed: _currentUserId == null
                                                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能收藏。')))
                                                  : () => _toggleBookmark(articleId, bookmarkedArticles),
                                              icon: Icon(hasBookmarked ? Icons.bookmark : Icons.bookmark_border, color: hasBookmarked ? Colors.blue : Colors.grey),
                                              label: Text('收藏', style: TextStyle(color: hasBookmarked ? Colors.blue : Colors.grey)),
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
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}