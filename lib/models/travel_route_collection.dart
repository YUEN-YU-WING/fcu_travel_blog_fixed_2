// lib/models/travel_route_collection.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TravelRouteCollection {
  String? id; // Firestore 文檔 ID
  String name; // 行程集合的名稱，例如「2023 台中三天兩夜」
  List<String> articleIds; // 包含的遊記 ID 列表
  DateTime createdAt; // 創建時間
  DateTime updatedAt; // 更新時間
  String? ownerUid; // 所屬用戶 ID (可選)
  String? thumbnailUrl;

  TravelRouteCollection({
    this.id,
    required this.name,
    required this.articleIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.ownerUid,
    this.thumbnailUrl,
  }) : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // 從 Firestore 數據轉換
  factory TravelRouteCollection.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TravelRouteCollection(
      id: doc.id,
      name: data['name'] ?? '未命名行程',
      articleIds: List<String>.from(data['articleIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ownerUid: data['ownerUid'],
      thumbnailUrl: data['thumbnailImageUrl'],
    );
  }

  // 轉換為 Firestore 數據
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'articleIds': articleIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'ownerUid': ownerUid,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}