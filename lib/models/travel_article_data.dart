// lib/models/travel_article_data.dart (示例，請根據你的實際模型調整)
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
      location: data['location'] is Map ? GeoPoint(data['location']['latitude'], data['location']['longitude']) : data['location'] as GeoPoint?,
      userDescription: data['userDescription'] ?? '',
      generatedHtmlContent: data['generatedHtmlContent'],
      thumbnailUrl: data['thumbnailImageUrl'],
      materialImageUrls: List<String>.from(data['materialImageUrls'] ?? []),
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
      'thumbnailUrl': thumbnailUrl,
      'materialImageUrls': materialImageUrls,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'ownerUid': ownerUid,
    };
  }
}