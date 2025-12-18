// lib/pages/travel_route_map_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../models/travel_article_data.dart';
import '../models/travel_route_collection.dart';
import 'travel_route_collection_page.dart';
import '../article_detail_page.dart';

// =========================================================================
// CustomInfoWindow 類定義 (樣式已更新)
class CustomInfoWindow extends StatelessWidget {
  final TravelArticleData article;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  const CustomInfoWindow({
    super.key,
    required this.article,
    required this.onClose,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final String title = article.title ?? '無標題遊記';
    final String placeName = article.placeName ?? '';
    final String address = article.address ?? '';
    final String? thumbnailUrl = article.thumbnailUrl;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(10),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題列 (Title)
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 圖片區域
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                  ),
                ),
              ),

            // 地點名稱 (Place Name) - 藍灰色風格
            if (placeName.isNotEmpty)
              Text(
                placeName,
                style: const TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            // 地址
            const SizedBox(height: 4),
            Text(
              address,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),
            // 按鈕
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton.icon(
                icon: const Icon(Icons.read_more, size: 18),
                label: const Text('閱讀文章'),
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// =========================================================================


class TravelRouteMapPage extends StatefulWidget {
  final String? initialCollectionId;

  const TravelRouteMapPage({super.key, this.initialCollectionId});

  @override
  State<TravelRouteMapPage> createState() => _TravelRouteMapPageState();
}

class _TravelRouteMapPageState extends State<TravelRouteMapPage> {
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<TravelArticleData> _articlesInCollection = [];
  String? _currentCollectionId;
  String? _currentCollectionName;
  final Map<String, BitmapDescriptor> _thumbnailCache = {};
  final GlobalKey _mapKey = GlobalKey();

  // 自定義資訊窗口相關狀態
  TravelArticleData? _selectedArticleForInfoWindow;
  Offset? _infoWindowOffset;

  static const LatLng _initialCameraPosition = LatLng(23.6937, 120.8906);

  @override
  void initState() {
    super.initState();
    _currentCollectionId = widget.initialCollectionId;
    if (_currentCollectionId != null) {
      _loadArticlesForCollection(_currentCollectionId!);
    }
  }

  @override
  void didUpdateWidget(covariant TravelRouteMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCollectionId != oldWidget.initialCollectionId) {
      if (widget.initialCollectionId != null) {
        _loadArticlesForCollection(widget.initialCollectionId!);
      } else {
        setState(() {
          _articlesInCollection.clear();
          _markers.clear();
          _polylines.clear();
          _currentCollectionId = null;
          _currentCollectionName = null;
          _selectedArticleForInfoWindow = null;
          _infoWindowOffset = null;
        });
        _updateMapElements();
      }
    }
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_articlesInCollection.isNotEmpty) {
      _animateCameraToRoute();
    }
    _updateMapElements();
  }

  Future<void> _loadArticlesForCollection(String collectionId) async {
    setState(() {
      _articlesInCollection.clear();
      _markers.clear();
      _polylines.clear();
      _currentCollectionId = collectionId;
      _currentCollectionName = null;
      _selectedArticleForInfoWindow = null;
      _infoWindowOffset = null;
    });

    try {
      final collectionDoc = await FirebaseFirestore.instance
          .collection('travelRouteCollections')
          .doc(collectionId)
          .get();

      if (!collectionDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('找不到該行程集合。')),
        );
        setState(() {
          _currentCollectionId = null;
          _currentCollectionName = null;
        });
        _updateMapElements();
        return;
      }

      final collection = TravelRouteCollection.fromFirestore(collectionDoc);
      _currentCollectionName = collection.name;
      final List<String> articleIds = collection.articleIds;

      if (articleIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('行程集合 "${collection.name}" 中沒有遊記。')),
        );
        _updateMapElements();
        return;
      }

      final articlesQuerySnapshot = await FirebaseFirestore.instance
          .collection('articles')
          .where(FieldPath.documentId, whereIn: articleIds)
          .get();

      Map<String, TravelArticleData> articlesMap = {
        for (var doc in articlesQuerySnapshot.docs)
          doc.id: TravelArticleData.fromFirestore(doc)
      };

      List<TravelArticleData> sortedArticles = [];
      for (String id in articleIds) {
        if (articlesMap.containsKey(id)) {
          sortedArticles.add(articlesMap[id]!);
        }
      }

      setState(() {
        _articlesInCollection = sortedArticles;
      });

      _updateMapElements();
      _animateCameraToRoute();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入行程集合遊記失敗: $e')),
      );
      print("Error loading articles for collection $collectionId: $e");
      setState(() {
        _currentCollectionId = null;
        _currentCollectionName = null;
      });
      _updateMapElements();
    }
  }

  // 修改：實現圓形標記圖片 (移植自 travelogue_map_page.dart)
  // 修改後的方法：新增 order 參數
  Future<BitmapDescriptor> _getCustomMarkerIcon(String imageUrl, String markerId, int order) async {
    String cacheKey = '${markerId}_$order';
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _thumbnailCache[cacheKey]!;
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ui.Image image = frameInfo.image;

        // ==========================================
        // 1. 定義尺寸
        // ==========================================
        const double imageSize = 100.0; // 照片本身的直徑
        const double padding = 30.0;    // 預留給數字球的空間 (邊距)
        const double canvasSize = imageSize + padding; // 總畫布大小 (130)

        final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
        // 畫布設為較大的尺寸
        final Canvas canvas = Canvas(pictureRecorder, Rect.fromLTWH(0, 0, canvasSize, canvasSize));

        final Paint paint = Paint()..isAntiAlias = true;

        // ==========================================
        // 2. 繪製照片 (置中)
        // ==========================================
        // 計算照片在畫布中的偏移量，讓它居中
        const double offset = padding / 2;

        // 定義照片的圓形區域 (加上偏移量)
        final Rect imageRect = Rect.fromLTWH(offset, offset, imageSize, imageSize);

        // 裁剪圓形 (只針對照片區域)
        canvas.save(); // 保存畫布狀態
        canvas.clipPath(Path()..addOval(imageRect));

        // 計算圖片來源尺寸 (保持原本的居中裁切邏輯)
        final double sizeMin = image.width < image.height ? image.width.toDouble() : image.height.toDouble();
        final Rect srcRect = Rect.fromLTWH(
            (image.width - sizeMin) / 2,
            (image.height - sizeMin) / 2,
            sizeMin,
            sizeMin
        );

        paint.filterQuality = FilterQuality.high;
        canvas.drawImageRect(image, srcRect, imageRect, paint);
        canvas.restore(); // 恢復畫布，取消裁剪限制，這樣才能在照片外面畫數字球

        // ==========================================
        // 3. 繪製白色邊框
        // ==========================================
        final Paint borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..isAntiAlias = true;
        // 圓心座標也要加上 offset
        canvas.drawCircle(Offset(canvasSize / 2, canvasSize / 2), imageSize / 2 - 2.0, borderPaint);

        // ==========================================
        // 4. 繪製順序標籤 (懸浮在右上角)
        // ==========================================
        final double badgeRadius = 16.0;

        // 計算右上角位置 (利用三角函數算出 45 度角的位置，或者直接抓概略位置)
        // 這裡設定在照片圓形的右上邊緣
        // X 座標: offset + imageSize - 稍微往內一點
        // Y 座標: offset + 稍微往下依點
        final Offset badgeCenter = Offset(offset + imageSize - 10, offset + 15);

        // 畫陰影 (讓球看起來立體一點，可選)
        canvas.drawCircle(
            badgeCenter + const Offset(2, 2),
            badgeRadius,
            Paint()..color = Colors.black.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
        );

        // 畫數字球底色 (藍色)
        final Paint badgeBgPaint = Paint()
          ..color = Colors.blueAccent
          ..style = PaintingStyle.fill;
        canvas.drawCircle(badgeCenter, badgeRadius, badgeBgPaint);

        // 畫數字球邊框 (白色)
        final Paint badgeBorderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(badgeCenter, badgeRadius, badgeBorderPaint);

        // 畫數字文字
        TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: order.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(badgeCenter.dx - textPainter.width / 2, badgeCenter.dy - textPainter.height / 2),
        );

        // ==========================================
        // 5. 輸出圖片
        // ==========================================
        final ui.Picture picture = pictureRecorder.endRecording();
        // 輸出成較大的圖片尺寸
        final ui.Image resizedImage = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
        final ByteData? byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final descriptor = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
          _thumbnailCache[cacheKey] = descriptor;
          return descriptor;
        }
      }
    } catch (e) {
      print('Error loading custom marker: $e');
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  Future<void> _updateMapElements() async {
    _markers.clear();
    _polylines.clear();

    // 修改：使用帶索引的迴圈來取得順序 (i + 1)
    for (int i = 0; i < _articlesInCollection.length; i++) {
      final article = _articlesInCollection[i];
      if (article.location == null || article.id == null) continue;

      final GeoPoint geoPoint = article.location!;
      final String articleId = article.id!;
      final String? thumbnailUrl = article.thumbnailUrl;
      final int sequenceNumber = i + 1; // 順序從 1 開始

      BitmapDescriptor markerIcon;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        // 傳入 sequenceNumber
        markerIcon = await _getCustomMarkerIcon(thumbnailUrl, articleId, sequenceNumber);
      } else {
        // 如果沒有圖片，目前暫時維持預設標記 (如果也想顯示數字，需另外處理)
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }

      _markers.add(
        Marker(
          markerId: MarkerId(articleId),
          position: LatLng(geoPoint.latitude, geoPoint.longitude),
          infoWindow: const InfoWindow(title: '', snippet: ''),
          icon: markerIcon,
          // 為了讓使用者容易點擊到最新的點，可以透過 zIndex 控制堆疊順序
          zIndex: sequenceNumber.toDouble(),
          onTap: () {
            _showCustomInfoWindow(article);
          },
        ),
      );
    }

    // ... (保留原本的 Polylines 邏輯) ...
    if (_articlesInCollection.length > 1) {
      // ... 你的 polyline 程式碼 ...
      List<LatLng> polylinePoints = _articlesInCollection
          .where((article) => article.location != null)
          .map((article) {
        final GeoPoint geoPoint = article.location!;
        return LatLng(geoPoint.latitude, geoPoint.longitude);
      }).toList();

      if (polylinePoints.length > 1) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('travel_route'),
            points: polylinePoints,
            color: Colors.blueAccent,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            patterns: [PatternItem.dash(30), PatternItem.gap(10)],
          ),
        );
      }
    }

    setState(() {});
  }

  Future<void> _animateCameraToRoute() async {
    if (mapController == null || _articlesInCollection.isEmpty) return;

    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;

    for (var article in _articlesInCollection) {
      if (article.location != null) {
        minLat = minLat < article.location!.latitude ? minLat : article.location!.latitude;
        maxLat = maxLat > article.location!.latitude ? maxLat : article.location!.latitude;
        minLng = minLng < article.location!.longitude ? minLng : article.location!.longitude;
        maxLng = maxLng > article.location!.longitude ? maxLng : article.location!.longitude;
      }
    }

    if (minLat == double.infinity) return;

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    final double padding = 80.0;
    await mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
  }


  void _showCustomInfoWindow(TravelArticleData article) {
    if (mapController == null || article.location == null) return;

    // 1. 讓地圖鏡頭移動到該地點 (讓 Marker 跑到畫面中間)
    mapController!.animateCamera(
      CameraUpdate.newLatLng(LatLng(article.location!.latitude, article.location!.longitude)),
    );

    // 2. 計算視窗位置 (固定在畫面中央上方)
    // 模仿 travelogue_map_page.dart 的邏輯
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    // InfoWindow 寬度固定為 300
    // 我們將其置中：(螢幕寬度 / 2) - (視窗寬度 / 2)
    // 高度位置：(螢幕高度 / 2) - 偏移量
    // 偏移量 280 大約是讓視窗底部剛好在畫面中心點(Marker位置)的上方
    final Offset position = Offset(
        screenWidth / 2 - 150,
        screenHeight / 2 - 280
    );

    setState(() {
      _selectedArticleForInfoWindow = article;
      _infoWindowOffset = position;
    });
  }

  void _closeCustomInfoWindow() {
    setState(() {
      _selectedArticleForInfoWindow = null;
      _infoWindowOffset = null;
    });
  }

  void _onEditArticle(String? articleId) {
    if (articleId != null) {
      _closeCustomInfoWindow();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArticleDetailPage(articleId: articleId),
        ),
      ).then((_) {
        if (_currentCollectionId != null) {
          _loadArticlesForCollection(_currentCollectionId!);
        }
      });
    }
  }

  Future<void> _selectRouteCollection() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能選擇行程集合。')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TravelRouteCollectionPage(),
      ),
    );
    _closeCustomInfoWindow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentCollectionName != null
            ? '遊記路徑地圖 - $_currentCollectionName'
            : '遊記路徑地圖'),
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark),
            onPressed: _selectRouteCollection,
            tooltip: '選擇行程集合',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            key: _mapKey, // ✅ 綁定 Key
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _initialCameraPosition,
              zoom: 8.0,
            ),
            markers: _markers,
            polylines: _polylines,
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onTap: (_) {
              _closeCustomInfoWindow();
            },
          ),
          // ... GoogleMap
          // ... 在 Stack 中 ...
          if (_selectedArticleForInfoWindow != null && _infoWindowOffset != null)
            Positioned(
              left: _infoWindowOffset!.dx,
              top: _infoWindowOffset!.dy, // ✅ 改回使用 top，配合上面的計算
              child: CustomInfoWindow(
                article: _selectedArticleForInfoWindow!,
                onClose: _closeCustomInfoWindow,
                onEdit: () => _onEditArticle(_selectedArticleForInfoWindow!.id),
              ),
            ),
        ],
      ),
    );
  }
}