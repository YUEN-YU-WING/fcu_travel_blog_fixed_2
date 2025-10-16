import 'package:cloud_firestore/cloud_firestore.dart';

class TravelArticleData {
  String? title; // 遊記標題，AI可以根據內容建議
  String? placeName; // 主要地點名稱
  String? address; // 地點地址
  GeoPoint? location; // 地點經緯度
  String? thumbnailUrl; // 縮圖的 URL
  List<String> materialImageUrls = []; // 用作遊記內容的圖片 URL 列表
  String userDescription; // 用戶描述的行程
  String? generatedHtmlContent; // AI 生成的 HTML 內容

  TravelArticleData({
    this.title,
    this.placeName,
    this.address,
    this.location,
    this.thumbnailUrl,
    required this.userDescription,
    this.materialImageUrls = const [],
    this.generatedHtmlContent,
  });

  // 轉換為 Map，便於傳給 OpenAI 或保存到 Firestore
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'placeName': placeName,
      'address': address,
      'location': location,
      'thumbnailUrl': thumbnailUrl,
      'materialImageUrls': materialImageUrls,
      'userDescription': userDescription,
      'generatedHtmlContent': generatedHtmlContent,
    };
  }
}