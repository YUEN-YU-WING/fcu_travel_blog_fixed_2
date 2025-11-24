// lib/friends_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 引入 FirebaseAuth
import 'friend_profile_page.dart';

class FriendsListPage extends StatefulWidget { // 名稱可以考慮改為 FollowingListPage
  const FriendsListPage({super.key});

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  String? _currentUserId; // 當前登入用戶的 ID

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('我追隨的人'),
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.black54),
          titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
        ),
        body: const Center(
          child: Text('請先登入才能查看追隨列表。', style: TextStyle(fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我追隨的人'), // 更改標題
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('出錯了: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('您的資料不存在。'));
          }

          final Map<String, dynamic> userData = snapshot.data!.data()! as Map<String, dynamic>;
          final List<String> followingIds = List<String>.from(userData['following'] ?? []);

          if (followingIds.isEmpty) {
            return const Center(child: Text('您還沒有追隨任何人。'));
          }

          // 現在我們有了所有追隨用戶的 ID，我們可以查詢這些用戶的詳細信息
          return StreamBuilder<QuerySnapshot>(
            // 注意：'whereIn' 條件最多只能有 10 個元素。
            // 如果用戶追隨了超過 10 個人，你需要分批查詢。
            // 為了演示，我們假設不會超過 10 個。
            stream: FirebaseFirestore.instance.collection('users')
                .where(FieldPath.documentId, whereIn: followingIds)
                .snapshots(),
            builder: (context, followingSnapshot) {
              if (followingSnapshot.hasError) {
                return Center(child: Text('載入追隨者資料出錯了: ${followingSnapshot.error}'));
              }

              if (followingSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!followingSnapshot.hasData || followingSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('沒有找到追隨用戶的資料。'));
              }

              final List<DocumentSnapshot> followingUsers = followingSnapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: followingUsers.length,
                itemBuilder: (context, index) {
                  DocumentSnapshot userDoc = followingUsers[index];
                  Map<String, dynamic> userData = userDoc.data()! as Map<String, dynamic>;

                  final String userId = userDoc.id;
                  final String userName = userData['displayName'] ?? '未知用戶';
                  final String userPhotoUrl = userData['photoURL'] ?? '';
                  final String userBio = userData['bio'] ?? '這個用戶還沒有填寫簡介。';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    child: InkWell(
                      onTap: () {
                        // 點擊追隨用戶進入其個人介紹頁面
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FriendProfilePage(
                              friendId: userId,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: userPhotoUrl.isNotEmpty ? NetworkImage(userPhotoUrl) : null,
                              child: userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    userBio.length > 50 ? '${userBio.substring(0, 50)}...' : userBio,
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13.0),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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