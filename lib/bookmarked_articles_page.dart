// lib/bookmarked_articles_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'article_detail_page.dart';
import 'friend_profile_page.dart'; // 需要導航到作者個人檔案
import 'widgets/my_app_bar.dart'; // 為了有一致的 AppBar

class BookmarkedArticlesPage extends StatefulWidget {
  const BookmarkedArticlesPage({super.key});

  @override
  State<BookmarkedArticlesPage> createState() => _BookmarkedArticlesPageState();
}

class _BookmarkedArticlesPageState extends State<BookmarkedArticlesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Stream<DocumentSnapshot>? _currentUserDataStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _currentUserDataStream = _firestore.collection('users').doc(_currentUser!.uid).snapshots();
    }
    // 監聽用戶登入/登出狀態，以便更新界面
    _auth.userChanges().listen((User? user) {
      if (mounted) { // 確保組件仍在樹中
        setState(() {
          _currentUser = user;
          _currentUserDataStream = user != null
              ? _firestore.collection('users').doc(user.uid).snapshots()
              : null;
        });
      }
    });
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('我的收藏'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('請先登入才能查看收藏文章。', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/login'); // 導航到登入頁面
                },
                child: const Text('前往登入'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _currentUserDataStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('出錯了: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('用戶資料載入失敗。'));
          }

          Map<String, dynamic> userData = snapshot.data!.data()! as Map<String, dynamic>;
          List<String> bookmarkedArticleIds = List<String>.from(userData['bookmarkedArticles'] ?? []);

          if (bookmarkedArticleIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('目前沒有收藏文章。', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('去首頁看看有沒有喜歡的文章吧！', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            );
          }

          // 根據收藏的文章 ID 查詢實際的文章數據
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('articles')
                .where(FieldPath.documentId, whereIn: bookmarkedArticleIds)
                .snapshots(),
            builder: (context, articleSnapshot) {
              if (articleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (articleSnapshot.hasError) {
                return Center(child: Text('收藏文章載入失敗: ${articleSnapshot.error}'));
              }
              if (!articleSnapshot.hasData || articleSnapshot.data!.docs.isEmpty) {
                // 這可能是由於某些收藏的文章已被刪除
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('找不到任何收藏的文章。', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('部分收藏的文章可能已被刪除。', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                );
              }

              // 將文章按照更新時間排序 (可選，Firestore .where(FieldPath.documentId, whereIn: ...) 不支持 .orderBy)
              // 如果需要排序，需要在客戶端手動排序
              List<DocumentSnapshot> articles = articleSnapshot.data!.docs;
              articles.sort((a, b) {
                final Timestamp? timeA = (a.data() as Map<String, dynamic>)['updatedAt'];
                final Timestamp? timeB = (b.data() as Map<String, dynamic>)['updatedAt'];
                if (timeA == null || timeB == null) return 0;
                return timeB.compareTo(timeA); // 最新文章在前
              });


              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  DocumentSnapshot document = articles[index];
                  Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
                  final String articleId = document.id;

                  final String authorUid = data['authorUid'] ?? '';
                  final String authorName = data['authorName'] ?? '匿名作者';
                  final String authorPhotoUrl = data['authorPhotoUrl'] ?? '';
                  final String title = data['title'] ?? '無標題';
                  final Timestamp updatedAt = data['updatedAt'] ?? Timestamp.now();
                  final String thumbnailImageUrl = data['thumbnailImageUrl'] ?? '';
                  final int likesCount = data['likesCount'] ?? 0;

                  // 這裡我們需要知道當前用戶是否也點讚了這篇文章
                  // 因為這個頁面只關注 "收藏"，所以我們不會再嵌套 StreamBuilder 去獲取用戶的 likedArticles。
                  // 如果需要在收藏列表頁面也顯示點讚狀態，需要額外處理，例如將 likedArticles 從 HomePage 傳入，或在這個頁面重新獲取。
                  // 為了簡潔，這裡暫時不顯示點讚的實心狀態，只顯示計數。

                  // 你需要一個方法來處理收藏/取消收藏，與 HomePage 中的 _toggleBookmark 類似
                  // 為了保持收藏列表的實時性，我們只處理取消收藏
                  void _toggleBookmarkInList(String currentArticleId) async {
                    if (_currentUser == null) return;
                    try {
                      await _firestore.collection('users').doc(_currentUser!.uid).update({
                        'bookmarkedArticles': FieldValue.arrayRemove([currentArticleId]),
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已取消收藏。')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('取消收藏失敗: $e')),
                      );
                    }
                  }


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
                                // 點讚按鈕 (在收藏列表只顯示計數，不判斷當前用戶是否點讚，因為 StreamBuilder 的結構)
                                TextButton.icon(
                                  onPressed: () { /* 收藏列表不提供點讚功能，或者需要重新獲取 likedArticles */ },
                                  icon: Icon(
                                    Icons.thumb_up_alt_outlined,
                                    color: Colors.grey,
                                  ),
                                  label: Text(
                                    '讚 ${likesCount > 0 ? likesCount : ''}',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                // 收藏按鈕 (在收藏列表頁面，點擊就是取消收藏)
                                TextButton.icon(
                                  onPressed: () => _toggleBookmarkInList(articleId), // 點擊取消收藏
                                  icon: const Icon(
                                    Icons.bookmark, // 這裡一定是實心，因為在收藏列表
                                    color: Colors.blue,
                                  ),
                                  label: const Text(
                                    '已收藏',
                                    style: TextStyle(color: Colors.blue),
                                  ),
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
    );
  }
}