// lib/services/article_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ArticleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> saveArticle(Map<String, dynamic> articleData) async {
    try {
      await _firestore.collection('articles').add(articleData);
      print('Article saved successfully!');
    } catch (e) {
      print('Error saving article: $e');
      rethrow;
    }
  }
}