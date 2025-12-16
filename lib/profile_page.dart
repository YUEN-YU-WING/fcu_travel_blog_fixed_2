// lib/profile_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 建議引入這個優化體驗

class ProfilePage extends StatefulWidget {
  final bool embedded;

  const ProfilePage({super.key, this.embedded = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _bioController = TextEditingController();
  bool _isUploadingAvatar = false;     // 分開控制讀取狀態
  bool _isUploadingBackground = false; // 分開控制讀取狀態

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  // ✅ 修改：增加 isBackground 參數來區分上傳類型
  Future<void> _pickAndUploadImage(User user, {bool isBackground = false}) async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: isBackground ? 80 : 70, // 背景圖品質稍微好一點
      maxWidth: isBackground ? 1024 : 512,  // 背景圖寬度允許大一點
      maxHeight: isBackground ? 1024 : 512,
    );

    if (image == null) return;

    setState(() {
      if (isBackground) {
        _isUploadingBackground = true;
      } else {
        _isUploadingAvatar = true;
      }
    });

    try {
      // 1. 決定路徑與檔名
      final String folder = isBackground ? 'user_backgrounds' : 'user_avatars';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(folder)
          .child('${user.uid}.jpg');

      // 2. 讀取與上傳
      final Uint8List imageBytes = await image.readAsBytes();
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      await storageRef.putData(imageBytes, metadata);

      // 3. 取得連結
      final String downloadUrl = await storageRef.getDownloadURL();

      // 4. 更新 Firestore
      final Map<String, dynamic> updateData = isBackground
          ? {'backgroundImageUrl': downloadUrl} // 新增欄位
          : {'photoURL': downloadUrl};

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updateData);

      // 5. 如果是頭像，也要更新 Auth 裡的 photoURL
      if (!isBackground) {
        await user.updatePhotoURL(downloadUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isBackground ? '背景圖片更新成功！' : '頭像更新成功！')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上傳失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isBackground) {
            _isUploadingBackground = false;
          } else {
            _isUploadingAvatar = false;
          }
        });
      }
    }
  }

  Future<void> _updateUserProfileInFirestore(User? firebaseUser) async {
    if (firebaseUser == null) return;
    // ... (保持原有的更新邏輯)
    final docRef = FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid);
    await docRef.set(
      {
        'bio': _bioController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('個人資料已更新！')));
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
          return const Scaffold(body: Center(child: Text('尚未登入')));
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).snapshots(),
          builder: (context, firestoreSnapshot) {
            Map<String, dynamic> firestoreData = firestoreSnapshot.data?.data() as Map<String, dynamic>? ?? {};

            final String bio = firestoreData['bio'] ?? '';
            // 優先使用 Firestore 的資料，如果沒有則使用 Auth 的
            final String? currentPhotoUrl = firestoreData['photoURL'] ?? firebaseUser.photoURL;
            // ✅ 讀取背景圖片欄位
            final String? backgroundImageUrl = firestoreData['backgroundImageUrl'];

            if (_bioController.text.isEmpty && bio.isNotEmpty) {
              _bioController.text = bio;
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('個人資料'),
                automaticallyImplyLeading: !widget.embedded,
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // ================= 頂部區域 (背景 + 頭像) =================
                    // 🔥 修改處：使用 SizedBox 指定總高度，確保點擊範圍包含頭像
                    SizedBox(
                      height: 280, // 200(背景) + 60(頭像凸出的高度)
                      child: Stack(
                        alignment: Alignment.topCenter, // 全部靠上對齊
                        children: [
                          // 1. 背景圖片區域 (固定高度 200)
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              image: (backgroundImageUrl != null && backgroundImageUrl.isNotEmpty)
                                  ? DecorationImage(
                                image: CachedNetworkImageProvider(backgroundImageUrl),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                            child: _isUploadingBackground
                                ? const Center(child: CircularProgressIndicator())
                                : (backgroundImageUrl == null || backgroundImageUrl.isEmpty)
                                ? const Center(child: Icon(Icons.image, size: 50, color: Colors.white))
                                : null,
                          ),

                          // 2. 編輯背景按鈕 (右上角)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Material( // 🔥 加個 Material 確保水波紋效果正常
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20), // 圓形點擊區域
                                onTap: _isUploadingBackground ? null : () => _pickAndUploadImage(firebaseUser, isBackground: true),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ),

                          // 3. 大頭貼 (定位在 Top: 140，這樣就會剛好一半在背景內，一半在背景外)
                          // 背景高 200，頭像半徑 60(直徑120)。
                          // 若要置中於邊界：200 - 60 = 140
                          Positioned(
                            top: 140,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                  ),
                                  child: CircleAvatar(
                                    radius: 60, // 半徑 60
                                    backgroundImage: currentPhotoUrl != null && currentPhotoUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(currentPhotoUrl)
                                        : null,
                                    backgroundColor: Colors.blueGrey[100],
                                    child: _isUploadingAvatar
                                        ? const CircularProgressIndicator()
                                        : (currentPhotoUrl == null || currentPhotoUrl.isEmpty)
                                        ? const Icon(Icons.person, size: 60, color: Colors.white)
                                        : null,
                                  ),
                                ),

                                // 相機按鈕
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Material( // 🔥 加個 Material 避免樣式問題
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: _isUploadingAvatar ? null : () => _pickAndUploadImage(firebaseUser, isBackground: false),
                                      child: Container(
                                        padding: const EdgeInsets.all(8), // 稍微加大一點觸控區
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ================= 資訊輸入區域 =================
                    const SizedBox(height: 16), // 留空間給突出的頭像
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            firebaseUser.displayName ?? "未設定名稱",
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            firebaseUser.email ?? "",
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 24),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: const Text('個人簡介', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _bioController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: '介紹一下你自己...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _updateUserProfileInFirestore(firebaseUser),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('儲存變更'),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
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