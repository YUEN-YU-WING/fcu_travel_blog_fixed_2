// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatelessWidget {
  /// 後台右側嵌入時請設為 true：const ProfilePage(embedded: true)
  /// 獨立開頁保持預設 false，會顯示系統返回鍵
  final bool embedded;

  const ProfilePage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資料'),
        // ✅ 核心：在後台嵌入時不顯示返回鍵；獨立開頁才顯示
        automaticallyImplyLeading: !embedded,
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(), // 監聽使用者資料變化
        builder: (context, snapshot) {
          final user = snapshot.data;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (user == null) {
            return const Center(
              child: Text('尚未登入', style: TextStyle(fontSize: 20, color: Colors.red)),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '個人資料',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
                          ? NetworkImage(user.photoURL!)
                          : null,
                      backgroundColor: Colors.blueGrey[300],
                      child: (user.photoURL == null || user.photoURL!.isEmpty)
                          ? const Icon(Icons.person, size: 50, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('名稱：${user.displayName ?? "未設定"}',
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 8),
                          Text('信箱：${user.email ?? "未設定"}',
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('UID：${user.uid}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
