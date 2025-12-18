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
  Future<BitmapDescriptor> _getCustomMarkerIcon(String imageUrl, String markerId) async {
    if (_thumbnailCache.containsKey(markerId)) {
      return _thumbnailCache[markerId]!;
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;

        // 1. 解碼圖片
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ui.Image image = frameInfo.image;

        // 2. 設定畫布與尺寸 (調整為 100 以獲得更清晰的圓形)
        const double size = 100.0;
        final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(pictureRecorder);
        final Rect rect = Rect.fromLTWH(0, 0, size, size);
        final Paint paint = Paint()..isAntiAlias = true;

        // 3. 畫出圓形裁切區域
        canvas.clipPath(Path()..addOval(rect));

        // 4. 計算圖片來源矩形，確保居中裁切成正方形
        final double sizeMin = image.width < image.height ? image.width.toDouble() : image.height.toDouble();
        final Rect srcRect = Rect.fromLTWH(
            (image.width - sizeMin) / 2,
            (image.height - sizeMin) / 2,
            sizeMin,
            sizeMin
        );

        // 5. 將圖片繪製到圓形區域內
        paint.filterQuality = FilterQuality.high;
        canvas.drawImageRect(image, srcRect, rect, paint);

        // 6. 加上白色邊框
        final Paint borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 // 邊框寬度
          ..isAntiAlias = true;
        canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2.0, borderPaint);

        // 7. 將畫布轉換為 PNG 圖片數據
        final ui.Picture picture = pictureRecorder.endRecording();
        final ui.Image resizedImage = await picture.toImage(size.toInt(), size.toInt());
        final ByteData? byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final descriptor = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
          _thumbnailCache[markerId] = descriptor;
          return descriptor;
        }
      }
    } catch (e) {
      print('Error loading custom marker icon for $imageUrl: $e');
    }
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }

  Future<void> _updateMapElements() async {
    _markers.clear();
    _polylines.clear();

    for (var article in _articlesInCollection) {
      if (article.location == null || article.id == null) continue;

      final GeoPoint geoPoint = article.location!;
      final String articleId = article.id!;
      final String? thumbnailUrl = article.thumbnailUrl;

      BitmapDescriptor markerIcon;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        markerIcon = await _getCustomMarkerIcon(thumbnailUrl, articleId);
      } else {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }

      _markers.add(
        Marker(
          markerId: MarkerId(articleId),
          position: LatLng(geoPoint.latitude, geoPoint.longitude),
          // InfoWindow 設為空，因為我們使用自定義的 CustomInfoWindow
          infoWindow: const InfoWindow(title: '', snippet: ''),
          icon: markerIcon,
          onTap: () {
            _showCustomInfoWindow(article);
          },
        ),
      );
    }

    // 保留路徑連線效果
    if (_articlesInCollection.length > 1) {
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
            color: Colors.blueAccent, // 稍微調整顏色使其更亮眼
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            patterns: [PatternItem.dash(30), PatternItem.gap(10)], // 可選：加上虛線效果增加設計感，如果不喜歡可移除
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