import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 雖然這裡沒有直接用，但留著以防萬一
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AlbumPage extends StatefulWidget {
  final String albumId;
  final String albumName;
  final bool isPickingImage; // 是否處於圖片選擇模式 (決定是否顯示選擇 UI 和確認按鈕)
  final bool allowMultiple; // 新增：是否允許選擇多張圖片

  const AlbumPage({
    super.key,
    required this.albumId,
    required this.albumName,
    this.isPickingImage = false,
    this.allowMultiple = false, // 預設為 false (單選)
  });

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final _picker = ImagePicker(); // 即使是 Firebase 相簿選擇，也可以保留用於上傳新圖片
  bool _isUploading = false;
  Set<String> _selectedPhotoIds = {}; // 用於追蹤已選中的圖片 ID
  List<Map<String, dynamic>> _selectedPhotoData = []; // 用於儲存已選中圖片的 URL 和 fileName


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

    final bytes = await pickedFile.readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg';
    final storagePath = 'user_albums/${user.uid}/$fileName';
    final storageRef = FirebaseStorage.instance.ref().child(storagePath);

    try {
      final uploadTask = await storageRef.putData(bytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 寫入 Firestore
      await FirebaseFirestore.instance.collection('photos').add({
        'storagePath': storagePath,
        'url': downloadUrl,
        'ownerUid': user.uid,
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileName': fileName,
        'albumId': widget.albumId,
        'imageUrl': downloadUrl, // 為了統一，建議也將 url 存儲為 imageUrl
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

  Future<void> _deleteSelectedPhotos(List<QueryDocumentSnapshot> docs) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final photosToDelete = docs.where((doc) => _selectedPhotoIds.contains(doc.id)).toList();

    for (final doc in photosToDelete) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final storagePath = data['storagePath'] as String?;
      try {
        if (storagePath != null) {
          final storageRef = FirebaseStorage.instance.ref().child(storagePath);
          await storageRef.delete();
        }
      } catch (_) {
        // 允許 Storage 沒有檔案
      }
      await FirebaseFirestore.instance.collection('photos').doc(doc.id).delete();
    }

    // 更新相簿照片數
    final albumRef = FirebaseFirestore.instance.collection('albums').doc(widget.albumId);
    await albumRef.update({
      'photoCount': FieldValue.increment(-photosToDelete.length),
    });

    setState(() {
      _selectedPhotoIds.clear();
      _selectedPhotoData.clear(); // 清空已選數據
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已刪除${photosToDelete.length}張照片')),
    );

    await _updateAlbumCoverAfterDelete();
  }

  Future<void> _updateAlbumCoverAfterDelete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final albumRef = FirebaseFirestore.instance.collection('albums').doc(widget.albumId);
    final latestPhoto = await FirebaseFirestore.instance
        .collection('photos')
        .where('albumId', isEqualTo: widget.albumId)
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('uploadedAt', descending: true)
        .limit(1)
        .get();

    if (latestPhoto.docs.isEmpty) {
      // 沒有照片了，封面設為 null
      await albumRef.update({'coverUrl': null});
    } else {
      final url = latestPhoto.docs.first['url'] as String?;
      await albumRef.update({'coverUrl': url});
    }
  }

  Future<String?> _getDownloadUrl(String? storagePath, String? urlFromDB) async {
    if (urlFromDB != null && urlFromDB.isNotEmpty) return urlFromDB;
    if (storagePath == null || storagePath.isEmpty) return null;
    try {
      return await FirebaseStorage.instance.ref().child(storagePath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  // 新增：處理圖片選擇邏輯
  void _handlePhotoSelection(String photoId, String imageUrl, String fileName) {
    setState(() {
      if (widget.allowMultiple) {
        // 多選模式：添加或移除
        if (_selectedPhotoIds.contains(photoId)) {
          _selectedPhotoIds.remove(photoId);
          _selectedPhotoData.removeWhere((item) => item['imageUrl'] == imageUrl);
        } else {
          _selectedPhotoIds.add(photoId);
          _selectedPhotoData.add({'imageUrl': imageUrl, 'fileName': fileName});
        }
      } else {
        // 單選模式：替換選中的圖片
        _selectedPhotoIds.clear();
        _selectedPhotoData.clear();
        _selectedPhotoIds.add(photoId);
        _selectedPhotoData.add({'imageUrl': imageUrl, 'fileName': fileName});
      }
    });
  }

  // 新增：確認選擇並返回結果
  void _confirmSelection() {
    if (_selectedPhotoData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇至少一張圖片')),
      );
      return;
    }

    if (widget.allowMultiple) {
      Navigator.pop(context, _selectedPhotoData); // 返回列表
    } else {
      Navigator.pop(context, _selectedPhotoData.first); // 返回單個 Map
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
      appBar: AppBar(
        title: Text(widget.isPickingImage
            ? (widget.allowMultiple ? '選擇多張圖片' : '選擇單張圖片')
            : widget.albumName), // 根據模式和多選狀態顯示不同標題
        actions: [
          if (widget.isPickingImage && _selectedPhotoIds.isNotEmpty) // 選擇模式下，且有選中才顯示確認按鈕
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _confirmSelection,
              tooltip: '確認選擇',
            ),
          if (!widget.isPickingImage) // 只有在非圖片選擇模式下才顯示這些操作
            StreamBuilder<QuerySnapshot>(
              stream: photosStream,
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final allSelected = _selectedPhotoIds.length == docs.length && docs.isNotEmpty;
                return Row(
                  children: [
                    if (_selectedPhotoIds.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: '刪除選取照片',
                        onPressed: () async {
                          final isConfirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('刪除照片'),
                              content: Text('確定要刪除選取的${_selectedPhotoIds.length}張照片嗎？'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除')),
                              ],
                            ),
                          );
                          if (isConfirm == true) {
                            await _deleteSelectedPhotos(docs);
                          }
                        },
                      ),
                    // 只有在非選擇模式下才顯示全選Checkbox
                    if (docs.isNotEmpty)
                      Checkbox(
                        value: allSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedPhotoIds = docs.map((doc) => doc.id).toSet();
                              // 注意：這裡只更新 ID，如果需要返回數據，也要更新 _selectedPhotoData
                              // 為了簡化，這裡假設全選只是刪除操作的前置，如果需要返回所有選中照片，需要遍歷 docs 填充 _selectedPhotoData
                            } else {
                              _selectedPhotoIds.clear();
                              _selectedPhotoData.clear();
                            }
                          });
                        },
                      ),
                    const SizedBox(width: 8),
                  ],
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: photosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text(widget.isPickingImage ? '此相簿沒有可選的照片' : '此相簿尚未上傳任何照片'));
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
              final storagePath = data['storagePath'] as String?;
              final urlFromDB = data['url'] as String?; // 你的數據庫字段是 'url'
              final fileName = data['fileName'] as String? ?? '未知檔案';
              final isSelected = _selectedPhotoIds.contains(doc.id);

              return FutureBuilder<String?>(
                future: _getDownloadUrl(storagePath, urlFromDB),
                builder: (context, snapshot) {
                  final imageUrl = snapshot.data;
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                  }
                  if (imageUrl == null) return const SizedBox();

                  return GestureDetector(
                    onLongPress: !widget.isPickingImage // 非圖片選擇模式下才允許長按選取
                        ? () {
                      setState(() {
                        if (isSelected) {
                          _selectedPhotoIds.remove(doc.id);
                        } else {
                          _selectedPhotoIds.add(doc.id);
                        }
                      });
                    }
                        : null,
                    onTap: () {
                      if (widget.isPickingImage) {
                        // 圖片選擇模式下，點擊圖片就調用選擇處理函數
                        if (!widget.allowMultiple) { // 單選模式
                          _handlePhotoSelection(doc.id, imageUrl, fileName);
                          _confirmSelection(); // 單選直接確認並返回
                        } else { // 多選模式
                          _handlePhotoSelection(doc.id, imageUrl, fileName);
                        }
                      } else if (_selectedPhotoIds.isNotEmpty) {
                        // 非選擇模式且有選取，點擊切換選取狀態
                        setState(() {
                          if (isSelected) {
                            _selectedPhotoIds.remove(doc.id);
                          } else {
                            _selectedPhotoIds.add(doc.id);
                          }
                        });
                      } else {
                        // 非選擇模式且未選取，顯示大圖預覽
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: InteractiveViewer(
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Stack(
                      children: [
                        Hero(
                          tag: imageUrl,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        // 圖片選擇模式下顯示選取標記
                        if (widget.isPickingImage && isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: const Icon(Icons.check, size: 16, color: Colors.white),
                            ),
                          ),
                        // 非圖片選擇模式下才顯示Checkbox
                        if (!widget.isPickingImage && docs.isNotEmpty)
                          Positioned(
                            left: 4,
                            top: 4,
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedPhotoIds.add(doc.id);
                                  } else {
                                    _selectedPhotoIds.remove(doc.id);
                                  }
                                });
                              },
                              shape: const CircleBorder(),
                              side: const BorderSide(width: 1, color: Colors.grey),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      // 只有在非圖片選擇模式下才顯示浮動按鈕
      floatingActionButton: widget.isPickingImage
          ? null
          : FloatingActionButton(
        onPressed: _isUploading ? null : _pickAndUploadImage,
        tooltip: '新增照片',
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add_a_photo),
      ),
    );
  }
}