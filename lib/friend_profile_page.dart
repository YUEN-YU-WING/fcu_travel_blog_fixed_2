// lib/friend_profile_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendProfilePage extends StatefulWidget {
  final String friendId; // 我們只需要傳遞好友的 ID

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

  @override
  void initState() {
    super.initState();
    // 在 State 初始化時，設置 Stream 以監聽指定 friendId 的用戶數據
    _friendDataStream = FirebaseFirestore.instance.collection('users').doc(widget.friendId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 標題將在 StreamBuilder 中動態顯示好友名稱
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black54),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _friendDataStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('載入好友資料出錯了: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('找不到該用戶的資料。'));
          }

          // 成功獲取好友數據
          Map<String, dynamic> friendData = snapshot.data!.data()! as Map<String, dynamic>;
          final String friendName = friendData['displayName'] ?? '未知用戶';
          final String friendPhotoUrl = friendData['photoURL'] ?? '';
          final String friendBio = friendData['bio'] ?? '這個用戶還沒有填寫簡介。';

          // 動態設置 AppBar 的 title
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) { // 確保 Widget 仍然存在
              // 這是一種 workaround，因為 AppBar 的 title 通常在 build 時就固定了
              // 如果要動態改變 AppBar 的 title，通常會在一個 StatefulWidget 中管理
              // 為了簡潔，我們在此處直接使用 StreamBuilder 內的 Text
            }
          });


          return CustomScrollView( // 使用 CustomScrollView 讓內容可滾動
            slivers: [
              SliverAppBar( // 可折疊的 AppBar，Facebook 個人頁面常見
                expandedHeight: 200.0, // 展開時的高度
                floating: false, // 不會隨著滾動而浮動
                pinned: true, // 會在頂部固定
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    friendName,
                    style: const TextStyle(color: Colors.white), // 標題顏色為白色
                  ),
                  centerTitle: true,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 背景圖片 (可以替換成用戶的封面照片)
                      (friendPhotoUrl != null && friendPhotoUrl!.isNotEmpty)
                          ? Image.network(
                        friendPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.blueGrey[200]),
                      )
                          : Container(color: Colors.blueGrey[200]),
                      // 疊加一個半透明層，讓文字更清晰
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
                      // 頭像
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          backgroundImage: friendPhotoUrl != null && friendPhotoUrl!.isNotEmpty
                              ? NetworkImage(friendPhotoUrl!)
                              : null,
                          child: (friendPhotoUrl == null || friendPhotoUrl!.isEmpty) ? const Icon(Icons.person, size: 40) : null,
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
                          const Divider(height: 32),
                          // TODO: 未來可以在這裡添加更多內容，例如：
                          // - 共同好友
                          // - 公開貼文列表 (可以重用 HomePage 的文章卡片)
                          // - 照片牆
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
      ),
    );
  }
}