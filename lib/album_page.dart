import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入')),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    final bytes = await pickedFile.readAsBytes(); // 支援 Web
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';
    final storageRef = FirebaseStorage.instance.ref().child('user_albums/${user.uid}/$fileName');

    try {
      final uploadTask = await storageRef.putData(bytes); // 取代 putFile
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 寫入 Firestore
      await FirebaseFirestore.instance.collection('albums').add({
        'url': downloadUrl,
        'ownerUid': user.uid,
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileName': fileName,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片上傳成功！')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePhoto(String docId, String fileName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 刪除 Storage 檔案
      final storageRef = FirebaseStorage.instance.ref().child('user_albums/${user.uid}/$fileName');
      await storageRef.delete();
    } catch (_) {
      // 允許 Storage 沒有檔案
    }
    // 刪除 Firestore 資料
    await FirebaseFirestore.instance.collection('albums').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已刪除照片')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('請先登入'));
    }
    final photosStream = FirebaseFirestore.instance
        .collection('albums')
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('uploadedAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的相簿'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: photosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('載入失敗: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('尚未上傳任何照片'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final imageUrl = data['url'] as String?;
              final fileName = data['fileName'] as String?;
              if (imageUrl == null) return const SizedBox();
              return GestureDetector(
                onLongPress: () async {
                  // 刪除確認
                  final isConfirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('刪除照片'),
                      content: const Text('確定要刪除此照片嗎？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除')),
                      ],
                    ),
                  );
                  if (isConfirm == true && fileName != null) {
                    _deletePhoto(doc.id, fileName);
                  }
                },
                onTap: () {
                  // 放大檢視
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: InteractiveViewer(
                          child: Image.network(imageUrl, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: imageUrl,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) =>
                      progress == null ? child : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _pickAndUploadImage,
        tooltip: '新增照片',
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add_a_photo),
      ),
    );
  }
}