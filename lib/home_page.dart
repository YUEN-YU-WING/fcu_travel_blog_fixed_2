// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 引入圖片快取

import 'widgets/my_app_bar.dart';
import 'notifications_page.dart';
import 'backend_home.dart';
import 'article_detail_page.dart';
import 'friends_list_page.dart';
import 'friend_profile_page.dart';
import 'bookmarked_articles_page.dart';
import 'album_folder_page.dart';
import 'models/travel_route_collection.dart'; // 確保引入模型
import 'pages/travel_route_map_page.dart'; // 引入地圖頁面

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _searchKeyword = '';
  String? _currentUserId;
  Stream<DocumentSnapshot>? _currentUserDataStream;

  // ✅ 新增：控制目前的分頁索引 (0: 文章, 1: 行程)
  int _currentNavIndex = 0;

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
    // ... (保持原有的 _onAvatarTap 邏輯，省略以節省篇幅)
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
                    Future.microtask(() => Navigator.of(rootContext).pushNamed('/register'));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('登入'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Future.microtask(() => Navigator.of(rootContext).pushNamed('/login'));
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
                  Future.microtask(() => Navigator.of(rootContext).push(MaterialPageRoute(builder: (_) => FriendProfilePage(friendId: user.uid))));
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('個人後台'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Future.microtask(() => Navigator.of(rootContext).push(MaterialPageRoute(builder: (_) => const BackendHomePage())));
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

  Future<void> _toggleLike(String articleId, List<dynamic> likedArticles) async {
    // ... (保持原有的 _toggleLike 邏輯)
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
    // ... (保持原有的 _toggleBookmark 邏輯)
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

  Widget _buildSidebarContent(User? user, String? userPhotoUrl, String userName, BuildContext context) {
    // ... (保持原有的側邊欄邏輯)
    return Container(
      color: Colors.blueGrey[50],
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage: userPhotoUrl != null ? NetworkImage(userPhotoUrl) : null,
              child: userPhotoUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              if (user != null) {
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

  // =================================================================
  // ✅ 新增：文章列表視圖 (原本放在 build 裡的邏輯移到這裡)
  // =================================================================
  Widget _buildArticleList(List<dynamic> likedArticles, List<dynamic> bookmarkedArticles) {
    Query query = FirebaseFirestore.instance.collection('articles').where('isPublic', isEqualTo: true);

    if (_searchKeyword.isNotEmpty) {
      query = query.where('keywords', arrayContains: _searchKeyword.toLowerCase());
    } else {
      query = query.orderBy('updatedAt', descending: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, articleSnapshot) {
        if (articleSnapshot.hasError) {
          return Center(child: Text('出錯了: ${articleSnapshot.error}'));
        }
        if (articleSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!articleSnapshot.hasData || articleSnapshot.data!.docs.isEmpty) {
          return const Center(child: Text('目前沒有公開文章。'));
        }

        return ListView.builder(
          itemCount: articleSnapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot document = articleSnapshot.data!.docs[index];
            Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
            final String articleId = document.id;

            final String ownerUid = data['ownerUid'] ?? '';
            // ✅ 確保這裡有讀取 authorName
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
                      // --- 作者資訊區塊 (Author Info Row) ---
                      InkWell(
                        onTap: ownerUid.isNotEmpty ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FriendProfilePage(friendId: ownerUid),
                            ),
                          );
                        } : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              // 1. 作者頭像
                              CircleAvatar(
                                backgroundImage: authorPhotoUrl.isNotEmpty ? NetworkImage(authorPhotoUrl) : null,
                                child: authorPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                              ),
                              const SizedBox(width: 8.0),

                              // 2. 作者名字與時間
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ 加回這裡：顯示作者名字 (粗體)
                                  Text(
                                      authorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold)
                                  ),
                                  // 發布時間 (灰色小字)
                                  Text(
                                      _formatTimestamp(updatedAt),
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12.0)
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ------------------------------------

                      const SizedBox(height: 12.0),

                      // 文章縮圖
                      if (thumbnailImageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: CachedNetworkImage(
                            imageUrl: thumbnailImageUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(height: 200, color: Colors.grey[200]),
                            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                          ),
                        ),
                      if (thumbnailImageUrl.isNotEmpty) const SizedBox(height: 12.0),

                      // 文章標題
                      Text(title, style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),

                      const SizedBox(height: 12.0),

                      // 按鈕區 (讚、收藏)
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
  }

  // =================================================================
  // ✅ 新增：公開行程集合列表視圖 (仿照您的行程樣式)
  // =================================================================
  Widget _buildCollectionList() {
    // 查詢公開的行程集合
    Query query = FirebaseFirestore.instance.collection('travelRouteCollections')
        .where('isPublic', isEqualTo: true);

    if (_searchKeyword.isNotEmpty) {
      // 注意：Firestore 不支援對不同欄位同時進行 arrayContains 和 where
      // 這裡假設我們只對 'name' 進行前端過濾，或後端有支援
      // 簡單起見，這裡不對名稱進行後端過濾，而是拉下來後端過濾，或僅支援排序
      // 若要支援搜尋，可依據需求調整。這裡暫時只排序。
      // query = query.orderBy('name').startAt([_searchKeyword]).endAt(['$_searchKeyword\uf8ff']);
    }

    query = query.orderBy('updatedAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('載入失敗: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        List<DocumentSnapshot> docs = snapshot.data!.docs;

        // 前端簡單過濾關鍵字
        if (_searchKeyword.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] as String? ?? '';
            return name.toLowerCase().contains(_searchKeyword.toLowerCase());
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('目前沒有公開的行程。', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            return _PublicCollectionCard(collectionDoc: docs[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? '訪客';
    final userPhotoUrl = user?.photoURL;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 800;

        return Scaffold(
          key: _scaffoldKey,
          appBar: MyAppBar(
            title: '首頁',
            centerTitle: true,
            isHomePage: true,
            currentIndex: _currentNavIndex, // ✅ 傳入當前索引
            avatarUrl: userPhotoUrl,
            isMobile: isMobile,
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            onAvatarTap: () => _onAvatarTap(context),
            onNotificationsTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
            },
            onSearch: (keyword) {
              setState(() => _searchKeyword = keyword);
            },
            // ✅ 修改導覽點擊事件：切換分頁
            onNavIconTap: (index) {
              setState(() {
                _currentNavIndex = index;
                _searchKeyword = ''; // 切換分頁時清空搜尋
              });
            },
          ),
          drawer: isMobile
              ? Drawer(
            width: 250,
            child: _buildSidebarContent(user, userPhotoUrl, userName, context),
          )
              : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile)
                Expanded(
                  flex: 2,
                  child: _buildSidebarContent(user, userPhotoUrl, userName, context),
                ),
              Expanded(
                flex: 5,
                child: Container(
                  color: Colors.grey[200],
                  padding: const EdgeInsets.all(16.0),
                  // ✅ 根據索引切換主要內容
                  child: _currentNavIndex == 0
                      ? StreamBuilder<DocumentSnapshot>(
                    stream: _currentUserDataStream,
                    builder: (context, currentUserSnapshot) {
                      List<dynamic> likedArticles = [];
                      List<dynamic> bookmarkedArticles = [];
                      if (currentUserSnapshot.hasData && currentUserSnapshot.data!.exists) {
                        Map<String, dynamic> userData = currentUserSnapshot.data!.data()! as Map<String, dynamic>;
                        likedArticles = userData['likedArticles'] ?? [];
                        bookmarkedArticles = userData['bookmarkedArticles'] ?? [];
                      }
                      return _buildArticleList(likedArticles, bookmarkedArticles);
                    },
                  )
                      : _buildCollectionList(), // 顯示行程列表
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =================================================================
// ✅ 新增：公開行程卡片組件 (獨立出來以處理圖片異步加載)
// =================================================================
class _PublicCollectionCard extends StatelessWidget {
  final DocumentSnapshot collectionDoc;

  const _PublicCollectionCard({required this.collectionDoc});

  // 獲取第一篇文章的縮圖 URL
  Future<String?> _getFirstArticleThumbnail(List<dynamic> articleIds) async {
    if (articleIds.isEmpty) return null;
    try {
      String firstArticleId = articleIds.first;
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('articles').doc(firstArticleId).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['thumbnailImageUrl'] as String?;
      }
    } catch (e) {
      print("Error fetching thumbnail: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = collectionDoc.data() as Map<String, dynamic>;
    final String collectionId = collectionDoc.id;
    final String name = data['name'] ?? '未命名行程';
    final List<dynamic> articleIds = data['articleIds'] ?? [];
    final String ownerName = data['ownerName'] ?? '匿名';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // ✅ 點擊後導航至地圖頁面查看
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TravelRouteMapPage(initialCollectionId: collectionId),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 圖片區域
            SizedBox(
              height: 160,
              width: double.infinity,
              child: FutureBuilder<String?>(
                future: _getFirstArticleThumbnail(articleIds),
                builder: (context, snapshot) {
                  Widget imageContainer(Widget child) {
                    return Container(
                      color: Colors.grey[300],
                      width: double.infinity,
                      height: double.infinity,
                      child: child,
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return imageContainer(const Center(child: CircularProgressIndicator()));
                  }

                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: snapshot.data!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                        ),
                        // 漸層遮罩
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                        // 標題
                        Positioned(
                          left: 16,
                          bottom: 12,
                          right: 16,
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  } else {
                    // 預設樣式
                    return Container(
                      color: Colors.blueGrey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_outlined, size: 48, color: Colors.blueGrey[400]),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),

            // 底部資訊
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${articleIds.length} 個景點',
                    style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    ownerName,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}