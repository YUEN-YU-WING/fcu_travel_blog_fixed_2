// lib/models/travel_article_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TravelArticleData {
  String? id;
  String? title;
  String? placeName;
  String? address;
  GeoPoint? location;
  // String userDescription; // 這個字段可以保留作為總結，或者移除
  String? generatedHtmlContent;
  String? thumbnailUrl;
  List<String> materialImageUrls;
  List<String> materialImageDescriptions;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? ownerUid;

  // 新增結構化提示詞字段
  String? companions; // 同行者
  String? activities; // 活動或體驗
  String? moodOrPurpose; // 心情或目的

  TravelArticleData({
    this.id,
    this.title,
    this.placeName,
    this.address,
    this.location,
    // required this.userDescription, // 如果要移除，這裡也要改
    this.generatedHtmlContent,
    this.thumbnailUrl,
    this.materialImageUrls = const [],
    this.materialImageDescriptions = const [],
    this.createdAt,
    this.updatedAt,
    this.ownerUid,
    // 初始化新增字段
    this.companions,
    this.activities,
    this.moodOrPurpose,
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
      // userDescription: data['userDescription'] ?? '', // 如果移除，這裡也要改
      generatedHtmlContent: data['generatedHtmlContent'],
      thumbnailUrl: data['thumbnailImageUrl'],
      materialImageUrls: List<String>.from(data['materialImageUrls'] ?? []),
      materialImageDescriptions: List<String>.from(data['materialImageDescriptions'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      ownerUid: data['ownerUid'],
      // 從 Firestore 讀取新增字段
      companions: data['companions'],
      activities: data['activities'],
      moodOrPurpose: data['moodOrPurpose'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'placeName': placeName,
      'address': address,
      'location': location,
      // 'userDescription': userDescription, // 如果移除，這裡也要改
      'generatedHtmlContent': generatedHtmlContent,
      'thumbnailUrl': thumbnailUrl,
      'materialImageUrls': materialImageUrls,
      'materialImageDescriptions': materialImageDescriptions,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'ownerUid': ownerUid,
      // 儲存新增字段
      'companions': companions,
      'activities': activities,
      'moodOrPurpose': moodOrPurpose,
    };
  }
}