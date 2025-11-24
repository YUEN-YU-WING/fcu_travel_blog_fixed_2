// lib/friend_profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // 用於從 Firestore 獲取好友數據的 Stream
  Stream<DocumentSnapshot>? _friendDataStream;
  // 用於從 Firestore 獲取當前用戶追隨列表的 Stream
  Stream<DocumentSnapshot>? _currentUserDataStream;

  String? _currentUserId; // 當前登入用戶的 ID

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (_currentUserId != null) {
      _currentUserDataStream = FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots();
    }
    _friendDataStream = FirebaseFirestore.instance.collection('users').doc(widget.friendId).snapshots();
  }

  // 追隨/取消追隨的邏輯
  Future<void> _toggleFollow(bool isFollowing) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能追隨用戶。')),
      );
      return;
    }

    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId);
    final targetUserRef = FirebaseFirestore.instance.collection('users').doc(widget.friendId);

    if (isFollowing) {
      // 取消追隨
      await currentUserRef.update({
        'following': FieldValue.arrayRemove([widget.friendId]),
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayRemove([_currentUserId]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消追隨。')),
      );
    } else {
      // 追隨
      await currentUserRef.update({
        'following': FieldValue.arrayUnion([widget.friendId]),
      });
      await targetUserRef.update({
        'followers': FieldValue.arrayUnion([_currentUserId]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已成功追隨！')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _friendDataStream, // 監聽目標用戶的資料
        builder: (context, friendSnapshot) {
          if (friendSnapshot.hasError) {
            return Center(child: Text('載入用戶資料出錯了: ${friendSnapshot.error}'));
          }
          if (friendSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!friendSnapshot.hasData || !friendSnapshot.data!.exists) {
            return const Center(child: Text('找不到該用戶的資料。'));
          }

          Map<String, dynamic> friendData = friendSnapshot.data!.data()! as Map<String, dynamic>;
          final String friendName = friendData['displayName'] ?? '未知用戶';
          final String friendPhotoUrl = friendData['photoURL'] ?? '';
          final String friendBio = friendData['bio'] ?? '這個用戶還沒有填寫簡介。';
          final List<dynamic> friendFollowers = friendData['followers'] ?? []; // 目標用戶的追隨者列表

          // 獲取當前登入用戶的數據以判斷追隨狀態
          return StreamBuilder<DocumentSnapshot>(
            stream: _currentUserDataStream,
            builder: (context, currentUserSnapshot) {
              if (currentUserSnapshot.hasError) {
                return Center(child: Text('載入您的資料出錯了: ${currentUserSnapshot.error}'));
              }
              if (currentUserSnapshot.connectionState == ConnectionState.waiting) {
                // 不阻塞，直接顯示內容，等待追隨狀態載入
              }

              List<dynamic> currentUserFollowing = [];
              if (currentUserSnapshot.hasData && currentUserSnapshot.data!.exists) {
                Map<String, dynamic> currentData = currentUserSnapshot.data!.data()! as Map<String, dynamic>;
                currentUserFollowing = currentData['following'] ?? [];
              }

              // 判斷當前登入用戶是否追隨了正在查看的這位用戶
              final bool isFollowing = currentUserFollowing.contains(widget.friendId);
              // 判斷是否為自己的頁面
              final bool isMyProfile = (_currentUserId == widget.friendId);


              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200.0,
                    floating: false,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        friendName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      centerTitle: true,
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          (friendPhotoUrl.isNotEmpty)
                              ? Image.network(
                            friendPhotoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: Colors.blueGrey[200]),
                          )
                              : Container(color: Colors.blueGrey[200]),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(0.0, 0.5),
                                end: Alignment(0.0, 0.0),
                                colors: <Color>[
                                  Color(0x60000000),
                                  Color(0x00000000),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              backgroundImage: friendPhotoUrl.isNotEmpty ? NetworkImage(friendPhotoUrl) : null,
                              child: friendPhotoUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friendName,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                friendBio,
                                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 16),
                              // 顯示追隨者數量
                              Text(
                                '${friendFollowers.length} 位追隨者',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),

                              // 追隨/取消追隨按鈕 (只有在非自己的頁面且已登入時才顯示)
                              if (!isMyProfile && _currentUserId != null)
                                ElevatedButton(
                                  onPressed: currentUserSnapshot.connectionState == ConnectionState.waiting
                                      ? null // 等待載入時禁用按鈕
                                      : () => _toggleFollow(isFollowing),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing ? Colors.grey : Colors.blue,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 40), // 寬度填滿
                                  ),
                                  child: Text(isFollowing ? '已追隨' : '追隨'),
                                ),
                              const Divider(height: 32),
                              const Text(
                                '更多資訊將會在這裡顯示...',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              const SizedBox(height: 200), // 為了演示滾動效果
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}