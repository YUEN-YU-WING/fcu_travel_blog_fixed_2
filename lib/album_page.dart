import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AlbumPage extends StatefulWidget {
  final String albumId;
  final String albumName;
  const AlbumPage({super.key, required this.albumId, required this.albumName});
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
      await FirebaseFirestore.instance.collection('photos').add({
        'url': downloadUrl,
        'ownerUid': user.uid,
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileName': fileName,
        'albumId': widget.albumId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片上傳成功！')),
      );

      final albumRef = FirebaseFirestore.instance.collection('albums').doc(widget.albumId);

      await albumRef.update({
        'coverUrl': downloadUrl, // 最新一張當封面
        'photoCount': FieldValue.increment(1),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }


  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('請先登入'));

    final photosStream = FirebaseFirestore.instance
        .collection('photos')
        .where('ownerUid', isEqualTo: user.uid)
        .where('albumId', isEqualTo: widget.albumId)
        .orderBy('uploadedAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: Text(widget.albumName)),
      body: StreamBuilder<QuerySnapshot>(
        stream: photosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
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
              if (imageUrl == null) return const SizedBox();
              return Hero(
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