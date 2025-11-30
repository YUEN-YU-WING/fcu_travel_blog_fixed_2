// lib/profile_page.dart
import 'package:flutter/foundation.dart'; // 用於 kIsWeb (雖然這裡用 readAsBytes 通用，但引入它是好習慣)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ⚠️ 注意：移除了 import 'dart:io'; 因為 Web 不支援

class ProfilePage extends StatefulWidget {
  final bool embedded;

  const ProfilePage({super.key, this.embedded = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _bioController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  // ✅ 修改：兼容 Web 與 Mobile 的圖片上傳邏輯
  Future<void> _pickAndUploadImage(User user) async {
    final ImagePicker picker = ImagePicker();

    // 1. 選擇圖片
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // 稍微壓縮圖片
      maxWidth: 512,    // 限制寬度，避免上傳過大頭像
      maxHeight: 512,
    );

    if (image == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // 2. 建立 Storage 參考路徑
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_avatars')
          .child('${user.uid}.jpg');

      // 3. 讀取圖片數據 (Web 和 Mobile 通用)
      // 在 Web 上，image.path 是一個 blob URL，不能給 File 使用
      // 所以我們直接讀取 bytes
      final Uint8List imageBytes = await image.readAsBytes();

      // 4. 設定 Metadata (讓瀏覽器知道這是圖片)
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      // 5. 使用 putData 上傳 (代替 putFile)
      await storageRef.putData(imageBytes, metadata);

      // 6. 取得下載連結
      final String downloadUrl = await storageRef.getDownloadURL();

      // 7. 更新 Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'photoURL': downloadUrl,
      });

      // 8. 更新 Auth current user (讓 APP 顯示即時更新)
      await user.updatePhotoURL(downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('頭像更新成功！')),
        );
      }
    } catch (e) {
      print("Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上傳失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _updateUserProfileInFirestore(User? firebaseUser) async {
    if (firebaseUser == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
    await docRef.set(
      {
        'displayName': firebaseUser.displayName,
        'photoURL': firebaseUser.photoURL,
        'email': firebaseUser.email,
        'bio': _bioController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
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

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).snapshots(),
          builder: (context, firestoreSnapshot) {
            Map<String, dynamic> firestoreData = firestoreSnapshot.data?.data() as Map<String, dynamic>? ?? {};
            final String bio = firestoreData['bio'] ?? '';
            final String? currentPhotoUrl = firestoreData['photoURL'] ?? firebaseUser.photoURL;

            if (_bioController.text.isEmpty && bio.isNotEmpty) {
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
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundImage: currentPhotoUrl != null && currentPhotoUrl.isNotEmpty
                                  ? NetworkImage(currentPhotoUrl)
                                  : null,
                              backgroundColor: Colors.blueGrey[100],
                              child: _isUploading
                                  ? const CircularProgressIndicator()
                                  : (currentPhotoUrl == null || currentPhotoUrl.isEmpty)
                                  ? const Icon(Icons.person, size: 70, color: Colors.white)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _isUploading ? null : () => _pickAndUploadImage(firebaseUser),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('名稱：${firebaseUser.displayName ?? "未設定"}',
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 8),
                    Text('信箱：${firebaseUser.email ?? "未設定"}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('UID：${firebaseUser.uid}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
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