// lib/models/travel_article_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TravelArticleData {
  String? id;
  String? title;
  String? placeName;
  String? address;
  GeoPoint? location;
  String? generatedHtmlContent;
  String? thumbnailUrl;
  List<String> materialImageUrls;
  List<String> materialImageDescriptions;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? ownerUid;

  // 新增結構化提示詞字段
  String? companions;
  String? activities;
  String? moodOrPurpose;

  // ✅ 新增：作者資訊快照 (Snapshot)
  String? authorName;     // 作者名稱
  String? authorPhotoUrl; // 作者頭像 URL

  TravelArticleData({
    this.id,
    this.title,
    this.placeName,
    this.address,
    this.location,
    this.generatedHtmlContent,
    this.thumbnailUrl,
    this.materialImageUrls = const [],
    this.materialImageDescriptions = const [],
    this.createdAt,
    this.updatedAt,
    this.ownerUid,
    this.companions,
    this.activities,
    this.moodOrPurpose,
    // 初始化新增字段
    this.authorName,      // ✅
    this.authorPhotoUrl,  // ✅
  });

  factory TravelArticleData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TravelArticleData(
      id: doc.id,
      title: data['title'],
      placeName: data['placeName'],
      address: data['address'],
      location: data['location'] is Map
          ? GeoPoint(data['location']['latitude'], data['location']['longitude'])
          : data['location'] as GeoPoint?,
      generatedHtmlContent: data['generatedHtmlContent'],
      thumbnailUrl: data['thumbnailImageUrl'], // 注意這裡 Firestore 存的 key 是 thumbnailImageUrl
      materialImageUrls: List<String>.from(data['materialImageUrls'] ?? []),
      materialImageDescriptions: List<String>.from(data['materialImageDescriptions'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      ownerUid: data['ownerUid'],
      companions: data['companions'],
      activities: data['activities'],
      moodOrPurpose: data['moodOrPurpose'],
      // 讀取新增字段
      authorName: data['authorName'],           // ✅
      authorPhotoUrl: data['authorPhotoUrl'],   // ✅
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'placeName': placeName,
      'address': address,
      'location': location,
      'generatedHtmlContent': generatedHtmlContent,
      'thumbnailImageUrl': thumbnailUrl, // 對應上方 key
      'materialImageUrls': materialImageUrls,
      'materialImageDescriptions': materialImageDescriptions,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'ownerUid': ownerUid,
      'companions': companions,
      'activities': activities,
      'moodOrPurpose': moodOrPurpose,
      // 寫入新增字段
      'authorName': authorName,         // ✅
      'authorPhotoUrl': authorPhotoUrl, // ✅
    };
  }
}