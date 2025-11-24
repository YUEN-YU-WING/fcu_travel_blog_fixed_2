import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'widgets/my_app_bar.dart';
import 'notifications_page.dart';
import 'backend_home.dart';
import 'article_detail_page.dart';
import 'friends_list_page.dart';
import 'friend_profile_page.dart';
import 'bookmarked_articles_page.dart'; // 引入新的收藏頁面

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchKeyword = '';
  // 當前登入用戶的 UID
  String? _currentUserId;
  // 監聽當前用戶的文檔，用於獲取 likedArticles 和 bookmarkedArticles
  Stream<DocumentSnapshot>? _currentUserDataStream;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // 如果用戶已登入，監聽其 Firestore 文檔
    if (_currentUserId != null) {
      _currentUserDataStream = FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots();
    }
    // 監聽 Firebase Auth 的用戶狀態變化
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

  // 處理點讚邏輯
  Future<void> _toggleLike(String articleId, List<dynamic> likedArticles) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能點讚。')),
      );
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId);
    final articleRef = FirebaseFirestore.instance.collection('articles').doc(articleId);

    // 判斷是否已經點讚
    final bool hasLiked = likedArticles.contains(articleId);

    try {
      if (hasLiked) {
        // 取消點讚
        await userRef.update({
          'likedArticles': FieldValue.arrayRemove([articleId]),
        });
        await articleRef.update({
          'likesCount': FieldValue.increment(-1),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消點讚。')),
        );
      } else {
        // 點讚
        await userRef.update({
          'likedArticles': FieldValue.arrayUnion([articleId]),
        });
        await articleRef.update({
          'likesCount': FieldValue.increment(1),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已點讚！')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗: $e')),
      );
    }
  }

  // 處理收藏邏輯
  Future<void> _toggleBookmark(String articleId, List<dynamic> bookmarkedArticles) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能收藏。')),
      );
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId);

    // 判斷是否已經收藏
    final bool hasBookmarked = bookmarkedArticles.contains(articleId);

    try {
      if (hasBookmarked) {
        // 取消收藏
        await userRef.update({
          'bookmarkedArticles': FieldValue.arrayRemove([articleId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消收藏。')),
        );
      } else {
        // 收藏
        await userRef.update({
          'bookmarkedArticles': FieldValue.arrayUnion([articleId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已成功收藏！')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗: $e')),
      );
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
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FriendProfilePage(friendId: user.uid),
                          ),
                        );
                      } else {
                        print('請先登入');
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: const Text('追隨'),
                    onTap: () {
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BookmarkedArticlesPage()),
                      );
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
              // **包裹 StreamBuilder，監聽當前用戶的 likedArticles 和 bookmarkedArticles**
              child: StreamBuilder<DocumentSnapshot>(
                stream: _currentUserDataStream,
                builder: (context, currentUserSnapshot) {
                  // 預設值，如果用戶未登入或數據尚未載入
                  List<dynamic> likedArticles = [];
                  List<dynamic> bookmarkedArticles = [];

                  if (currentUserSnapshot.hasData && currentUserSnapshot.data!.exists) {
                    Map<String, dynamic> userData = currentUserSnapshot.data!.data()! as Map<String, dynamic>;
                    likedArticles = userData['likedArticles'] ?? [];
                    bookmarkedArticles = userData['bookmarkedArticles'] ?? [];
                  }

                  // 現在，內部的文章列表 StreamBuilder 可以訪問這些數據
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
                          // 從文章數據中獲取點讚數
                          final int likesCount = data['likesCount'] ?? 0;

                          // 判斷當前文章是否被當前用戶點讚或收藏
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
                                    if (authorUid.isNotEmpty)
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => FriendProfilePage(friendId: authorUid),
                                            ),
                                          );
                                        },
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
                                        ),
                                      )
                                    else
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
                                    const SizedBox(height: 12.0),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        // **點讚按鈕**
                                        TextButton.icon(
                                          onPressed: _currentUserId == null
                                              ? () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('請先登入才能點讚。')),
                                            );
                                          }
                                              : () => _toggleLike(articleId, likedArticles),
                                          icon: Icon(
                                            hasLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                                            color: hasLiked ? Colors.blue : Colors.grey,
                                          ),
                                          label: Text(
                                            '讚 ${likesCount > 0 ? likesCount : ''}', // 顯示點讚數
                                            style: TextStyle(color: hasLiked ? Colors.blue : Colors.grey),
                                          ),
                                        ),
                                        // **收藏按鈕**
                                        TextButton.icon(
                                          onPressed: _currentUserId == null
                                              ? () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('請先登入才能收藏。')),
                                            );
                                          }
                                              : () => _toggleBookmark(articleId, bookmarkedArticles),
                                          icon: Icon(
                                            hasBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                            color: hasBookmarked ? Colors.blue : Colors.grey,
                                          ),
                                          label: Text(
                                            '收藏',
                                            style: TextStyle(color: hasBookmarked ? Colors.blue : Colors.grey),
                                          ),
                                        ),
                                        // TODO: 留言和分享按鈕可以根據需要添加
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
          // // 右側邊欄
          // Expanded(
          //   flex: 3,
          //   child: Container(
          //     color: Colors.blueGrey[100],
          //     child: const Center(
          //       child: Text('右側邊欄'),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}