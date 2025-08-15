import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),  // 監聽使用者資料變化
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

        return Padding(
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
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                    backgroundColor: Colors.blueGrey[300],
                    child: user.photoURL == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('名稱：${user.displayName ?? "未設定"}', style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 8),
                      Text('信箱：${user.email ?? "未設定"}', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('UID：${user.uid}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}