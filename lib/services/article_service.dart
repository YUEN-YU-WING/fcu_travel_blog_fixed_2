// lib/services/article_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ArticleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 修改此函數，使其返回新文章的 ID
  static Future<String> saveArticle(Map<String, dynamic> articleData) async {
    final docRef = await _firestore.collection('articles').add(articleData);
    return docRef.id; // 返回新文章的 ID
  }

  // ... 可能有其他方法，例如 getArticleById 等
  static Stream<DocumentSnapshot> getArticleStream(String articleId) {
    return _firestore.collection('articles').doc(articleId).snapshots();
  }
}