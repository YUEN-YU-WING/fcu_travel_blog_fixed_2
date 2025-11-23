// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 引入 Firestore

class ProfilePage extends StatefulWidget {
  final bool embedded;

  const ProfilePage({super.key, this.embedded = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _bioController = TextEditingController(); // 用於編輯簡介

  // 在 initState 或 build 之前，設置 Firestore 的 Stream
  // 由於我們需要在這裡同時顯示 Auth 和 Firestore 的數據，
  // 並且可能需要編輯，所以會稍微複雜一點。

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  // 更新 Firestore 中的用戶資料
  Future<void> _updateUserProfileInFirestore(User? firebaseUser) async {
    if (firebaseUser == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
    await docRef.set(
      {
        'displayName': firebaseUser.displayName,
        'photoURL': firebaseUser.photoURL,
        'email': firebaseUser.email,
        'bio': _bioController.text, // 更新簡介
        'updatedAt': FieldValue.serverTimestamp(), // 記錄更新時間
      },
      SetOptions(merge: true), // 使用 merge，只更新指定字段，不覆蓋整個文檔
    ).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('個人資料已更新！')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 同時監聽 FirebaseAuth 的用戶變化和 Firestore 的用戶文檔變化
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, authSnapshot) {
        final firebaseUser = authSnapshot.data;

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (firebaseUser == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('個人資料'),
              automaticallyImplyLeading: !widget.embedded,
            ),
            body: const Center(
              child: Text('尚未登入', style: TextStyle(fontSize: 20, color: Colors.red)),
            ),
          );
        }

        // 當 Firebase Auth 用戶存在時，監聽其在 Firestore 中的文檔
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).snapshots(),
          builder: (context, firestoreSnapshot) {
            if (firestoreSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('個人資料'),
                  automaticallyImplyLeading: !widget.embedded,
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            // 從 Firestore 獲取自定義資料，如果沒有，則使用預設值
            Map<String, dynamic> firestoreData = firestoreSnapshot.data?.data() as Map<String, dynamic>? ?? {};
            final String bio = firestoreData['bio'] ?? '這個用戶還沒有填寫簡介。';

            // 初始化簡介編輯器
            if (_bioController.text.isEmpty) { // 避免每次 rebuild 都重設，導致編輯中文字被覆蓋
              _bioController.text = bio;
            }


            return Scaffold(
              appBar: AppBar(
                title: const Text('個人資料'),
                automaticallyImplyLeading: !widget.embedded,
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '我的個人資料',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: firebaseUser.photoURL != null && firebaseUser.photoURL!.isNotEmpty
                              ? NetworkImage(firebaseUser.photoURL!)
                              : null,
                          backgroundColor: Colors.blueGrey[300],
                          child: (firebaseUser.photoURL == null || firebaseUser.photoURL!.isEmpty)
                              ? const Icon(Icons.person, size: 50, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('名稱：${firebaseUser.displayName ?? "未設定"}',
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(height: 8),
                              Text('信箱：${firebaseUser.email ?? "未設定"}',
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('UID：${firebaseUser.uid}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      '個人簡介：',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bioController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '輸入你的個人簡介...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => _updateUserProfileInFirestore(firebaseUser),
                        child: const Text('更新簡介'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}