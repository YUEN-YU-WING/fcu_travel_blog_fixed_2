// lib/models/travel_article_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TravelArticleData {
  String? id;
  String? title;
  String? placeName;
  String? address;
  GeoPoint? location;
  String userDescription;
  String? generatedHtmlContent;
  String? thumbnailUrl;
  List<String> materialImageUrls;
  List<String> materialImageDescriptions; // 新增：用於儲存素材圖片的識別內容
  DateTime? createdAt;
  DateTime? updatedAt;
  String? ownerUid;

  TravelArticleData({
    this.id,
    this.title,
    this.placeName,
    this.address,
    this.location,
    required this.userDescription,
    this.generatedHtmlContent,
    this.thumbnailUrl,
    this.materialImageUrls = const [],
    this.materialImageDescriptions = const [], // 初始化為空列表
    this.createdAt,
    this.updatedAt,
    this.ownerUid,
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
      userDescription: data['userDescription'] ?? '',
      generatedHtmlContent: data['generatedHtmlContent'],
      thumbnailUrl: data['thumbnailImageUrl'], // 注意這裡你用的是 'thumbnailImageUrl'
      materialImageUrls: List<String>.from(data['materialImageUrls'] ?? []),
      materialImageDescriptions: List<String>.from(data['materialImageDescriptions'] ?? []), // 從 Firestore 讀取
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      ownerUid: data['ownerUid'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'placeName': placeName,
      'address': address,
      'location': location,
      'userDescription': userDescription,
      'generatedHtmlContent': generatedHtmlContent,
      'thumbnailUrl': thumbnailUrl, // 注意這裡你用的是 'thumbnailUrl'
      'materialImageUrls': materialImageUrls,
      'materialImageDescriptions': materialImageDescriptions, // 儲存到 Firestore
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'ownerUid': ownerUid,
    };
  }
}