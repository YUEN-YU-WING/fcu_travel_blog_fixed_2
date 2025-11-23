// lib/friends_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'friend_profile_page.dart'; // 引入好友簡介頁面

class FriendsListPage extends StatefulWidget {
  const FriendsListPage({super.key});

  @override
  State<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends State<FriendsListPage> {
  // 這裡假設我們有一個 'users' 集合，其中包含用戶資訊，並且有一個 'friends' 子集合或字段來表示好友關係。
  // 為了簡化演示，我們將直接查詢 'users' 集合，並假設每個用戶都是“潛在好友”
  // 在實際應用中，你需要一個明確的好友關係模型（例如，當前用戶的好友 ID 列表）。

  // 為了演示，我們將模擬當前用戶的好友 ID 列表
  // 實際應用中，這會從當前登入用戶的文檔中讀取
  final List<String> _myFriendIds = [
    '8xrvP3tWmzREzeyu46EsB61kdqq2', // 替換為你 Firestore 中真實的用戶 ID
    'Hzy50fHi6Jb4C3pxmVkwOkV0XNy2', // 替換為你 Firestore 中真實的用戶 ID
    // ... 更多好友 ID
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的好友'),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 為了演示，我們查詢所有用戶 (排除當前用戶自己)
        // 實際應用中，你會查詢 _myFriendIds 列表中的用戶
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('出錯了: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('目前沒有好友。'));
          }

          // 過濾出實際的好友（這裡僅作演示，假設所有用戶都是好友）
          final List<DocumentSnapshot> friends = snapshot.data!.docs
              .where((doc) => _myFriendIds.contains(doc.id)) // 假設是這個用戶的好友
              .toList();

          if (friends.isEmpty) {
            return const Center(child: Text('目前沒有好友。'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              DocumentSnapshot friendDoc = friends[index];
              Map<String, dynamic> friendData = friendDoc.data()! as Map<String, dynamic>;

              final String friendId = friendDoc.id;
              final String friendName = friendData['displayName'] ?? '未知用戶';
              final String friendPhotoUrl = friendData['photoURL'] ?? '';


              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                elevation: 0.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                child: InkWell(
                  onTap: () {
                    // 點擊好友進入好友簡介頁面
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FriendProfilePage(
                          friendId: friendId, // **只傳遞 friendId**
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
                          backgroundImage: friendPhotoUrl.isNotEmpty ? NetworkImage(friendPhotoUrl) : null,
                          child: friendPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friendName,
                                style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4.0),
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
      ),
    );
  }
}