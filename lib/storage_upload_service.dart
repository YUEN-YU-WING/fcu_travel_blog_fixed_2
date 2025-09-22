import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageUploadService {
  /// 從檔案系統選取檔案並上傳，可自訂 metadata
  static Future<String?> pickAndUploadFile({String folder = "uploads", Map<String, String>? metadata}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery); // 可改 ImageSource.camera
    if (picked == null) return null;

    final file = File(picked.path);
    final filename = "${DateTime.now().millisecondsSinceEpoch}_${picked.name}";
    final ref = FirebaseStorage.instance.ref().child("$folder/$filename");
    final SettableMetadata settableMetadata = metadata != null ? SettableMetadata(customMetadata: metadata) : SettableMetadata();

    final uploadTask = ref.putFile(file, settableMetadata);
    await uploadTask.whenComplete(() {});
    final downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }
}