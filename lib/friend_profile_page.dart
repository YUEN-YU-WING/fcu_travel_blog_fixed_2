// lib/friend_profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ 引入圖片套件

import 'article_detail_page.dart'; // ✅ 引入文章詳情頁面

class FriendProfilePage extends StatefulWidget {
  final String friendId;

  const FriendProfilePage({
    super.key,
    required this.friendId,
  });

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  Stream<DocumentSnapshot>? _friendDataStream;
  Stream<DocumentSnapshot>? _currentUserDataStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (_currentUserId != null) {
      _currentUserDataStream = FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots();
    }
    _friendDataStream = FirebaseFirestore.instance.collection('users').doc(widget.friendId).snapshots();
  }

  // 追隨功能 (保持不變)
  Future<void> _toggleFollow(bool isFollowing) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能追隨用戶。')));
      return;
    }

    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId);
    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(widget.friendId);

    try {
      if (isFollowing) {
        await currentUserRef.update({'following': FieldValue.arrayRemove([widget.friendId])});
        await targetUserRef.update({'followers': FieldValue.arrayRemove([_currentUserId])});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消追隨。')));
      } else {
        await currentUserRef.update({'following': FieldValue.arrayUnion([widget.friendId])});
        await targetUserRef.update({'followers': FieldValue.arrayUnion([_currentUserId])});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功追隨！')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
    }
  }

  // 格式化時間小工具
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.year}/${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _friendDataStream,
        builder: (context, friendSnapshot) {
          if (friendSnapshot.hasError) return Center(child: Text('載入錯誤: ${friendSnapshot.error}'));
          if (friendSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!friendSnapshot.hasData || !friendSnapshot.data!.exists) return const Center(child: Text('找不到該用戶。'));

          Map<String, dynamic> friendData = friendSnapshot.data!.data()! as Map<String, dynamic>;
          final String friendName = friendData['displayName'] ?? '未知用戶';
          final String friendPhotoUrl = friendData['photoURL'] ?? '';
          final String friendBio = friendData['bio'] ?? '這個用戶還沒有填寫簡介。';
          // ✅ 讀取背景圖
          final String? backgroundImageUrl = friendData['backgroundImageUrl'];
          final List<dynamic> friendFollowers = friendData['followers'] ?? [];

          return StreamBuilder<DocumentSnapshot>(
            stream: _currentUserDataStream,
            builder: (context, currentUserSnapshot) {
              List<dynamic> currentUserFollowing = [];
              if (currentUserSnapshot.hasData && currentUserSnapshot.data!.exists) {
                Map<String, dynamic> currentData = currentUserSnapshot.data!.data()! as Map<String, dynamic>;
                currentUserFollowing = currentData['following'] ?? [];
              }

              final bool isFollowing = currentUserFollowing.contains(widget.friendId);
              final bool isMyProfile = (_currentUserId == widget.friendId);

              return CustomScrollView(
                slivers: [
                  // 1. App Bar 與 背景圖
                  SliverAppBar(
                    expandedHeight: 200.0,
                    pinned: true,
                    stretch: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                          friendName,
                          style: const TextStyle(
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 4)]
                          )
                      ),
                      centerTitle: true,
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ✅ 優先顯示設定的背景圖片
                          if (backgroundImageUrl != null && backgroundImageUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: backgroundImageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(color: Colors.blueGrey[200]),
                            )
                          // ❌ 如果沒有背景圖，但有大頭貼，可以使用模糊大頭貼當背景 (可選)
                          else if (friendPhotoUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: friendPhotoUrl,
                              fit: BoxFit.cover,
                              // 這裡可以加上 ImageFilter.blur 讓它變模糊，或者直接顯示
                            )
                          // ❌ 如果都沒有，顯示預設色塊
                          else
                            Container(color: Colors.blueGrey[200]),

                          // 漸層遮罩 (保持不變)
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. 個人資料區塊 (使用 SliverToBoxAdapter)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: friendPhotoUrl.isNotEmpty ? NetworkImage(friendPhotoUrl) : null,
                            child: friendPhotoUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            friendBio,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${friendFollowers.length} 位追隨者',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (!isMyProfile && _currentUserId != null)
                            ElevatedButton(
                              onPressed: () => _toggleFollow(isFollowing),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? Colors.grey[300] : Theme.of(context).primaryColor,
                                foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                                minimumSize: const Size(120, 40),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                              child: Text(isFollowing ? '已追隨' : '追隨'),
                            ),
                          const SizedBox(height: 24),
                          const Divider(),
                          // 標題
                          Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Text(
                              "發表的遊記",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. 🔥 文章列表區塊 (SliverList + StreamBuilder)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('articles')
                        .where('ownerUid', isEqualTo: widget.friendId)
                        .where('isPublic', isEqualTo: true) // 只顯示公開文章
                        .orderBy('updatedAt', descending: true)
                        .snapshots(),
                    builder: (context, articleSnapshot) {
                      if (articleSnapshot.connectionState == ConnectionState.waiting) {
                        return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                      }
                      if (!articleSnapshot.hasData || articleSnapshot.data!.docs.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: Text("該用戶尚未發表公開遊記", style: TextStyle(color: Colors.grey))),
                          ),
                        );
                      }

                      final articles = articleSnapshot.data!.docs;

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final doc = articles[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final articleId = doc.id;
                            final String title = data['title'] ?? '無標題';
                            final String thumbnailUrl = data['thumbnailImageUrl'] ?? '';
                            final Timestamp? updatedAt = data['updatedAt'];
                            final int likesCount = data['likesCount'] ?? 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ArticleDetailPage(articleId: articleId),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (thumbnailUrl.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: CachedNetworkImage(
                                          imageUrl: thumbnailUrl,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(height: 180, color: Colors.grey[200]),
                                          errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _formatTimestamp(updatedAt),
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                              Row(
                                                children: [
                                                  Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.grey[600]),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$likesCount',
                                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                  ),
                                                ],
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
                          childCount: articles.length,
                        ),
                      );
                    },
                  ),

                  // 底部留白
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}