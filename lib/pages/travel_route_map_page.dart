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
import '../article_detail_page.dart'; // 引入文章詳情頁面，用於編輯

// =========================================================================
// CustomInfoWindow 類定義
class CustomInfoWindow extends StatelessWidget {
  final TravelArticleData article; // 使用 TravelArticleData 模型
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    placeName.isNotEmpty ? placeName : title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 80),
                  ),
                ),
              ),
            Text(
              title, // 遊記標題
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              address, // 詳細地址
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton.icon(
                icon: const Icon(Icons.read_more, size: 18),
                label: const Text('閱讀文章'),
                onPressed: onEdit,
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

  // 自定義資訊窗口相關狀態
  TravelArticleData? _selectedArticleForInfoWindow;
  Offset? _infoWindowOffset; // 資訊窗口的位置

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
        // 如果新的 initialCollectionId 是 null，清空地圖和選中的資訊窗口
        setState(() {
          _articlesInCollection.clear();
          _markers.clear();
          _polylines.clear();
          _currentCollectionId = null;
          _currentCollectionName = null;
          _selectedArticleForInfoWindow = null; // 清空選中的文章
          _infoWindowOffset = null;
        });
        _updateMapElements(); // 確保所有地圖元素都被清空
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
    // 在地圖創建後，嘗試將攝像機移動到路徑中心，如果已經有數據
    if (_articlesInCollection.isNotEmpty) {
      _animateCameraToRoute();
    }
    // 移除：mapController?.addListener(_onMapMove);
    _updateMapElements();
  }


  // =========================================================================
  // 這個方法是之前提到的，確保它存在於此處
  Future<void> _loadArticlesForCollection(String collectionId) async {
    setState(() {
      _articlesInCollection.clear();
      _markers.clear();
      _polylines.clear();
      _currentCollectionId = collectionId;
      _currentCollectionName = null;
      _selectedArticleForInfoWindow = null; // 清空選中的文章
      _infoWindowOffset = null; // 清空資訊窗口位置
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
  // =========================================================================


  Future<BitmapDescriptor> _getCustomMarkerIcon(String imageUrl, String markerId) async {
    if (_thumbnailCache.containsKey(markerId)) {
      return _thumbnailCache[markerId]!;
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 80, targetHeight: 80);
        final ui.FrameInfo frameInfo = await codec.getNextFrame();
        final ByteData? byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
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
          infoWindow: const InfoWindow(title: '', snippet: ''), // 保持為空
          icon: markerIcon,
          onTap: () {
            _showCustomInfoWindow(article);
          },
        ),
      );
    }

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
            color: Colors.blue,
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
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


  void _showCustomInfoWindow(TravelArticleData article) async {
    if (mapController == null || article.location == null) return;

    setState(() {
      _selectedArticleForInfoWindow = article;
      _infoWindowOffset = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateInfoWindowPosition(LatLng(article.location!.latitude, article.location!.longitude));
    });

    await mapController!.animateCamera(
      CameraUpdate.newLatLng(LatLng(article.location!.latitude, article.location!.longitude)),
    );
  }

  void _updateInfoWindowPosition(LatLng markerLatLng) async {
    if (mapController == null || !mounted) return;

    try {
      ScreenCoordinate screenCoordinate = await mapController!.getScreenCoordinate(markerLatLng);
      RenderBox? renderBox = context.findRenderObject() as RenderBox?;

      if (renderBox == null || !renderBox.attached) {
        return;
      }

      Offset offset = renderBox.localToGlobal(Offset.zero);

      setState(() {
        final double infoWindowWidth = 300;
        final double infoWindowHeight = 250;

        _infoWindowOffset = Offset(
          screenCoordinate.x.toDouble() + offset.dx - (infoWindowWidth / 2),
          screenCoordinate.y.toDouble() + offset.dy - infoWindowHeight - 20,
        );
      });
    } catch (e) {
      print("Error getting screen coordinate: $e");
    }
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
        // 從編輯頁面返回後，可以考慮重新載入當前集合，確保數據是最新的
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
            onCameraMove: (CameraPosition position) {
              if (_selectedArticleForInfoWindow != null && _selectedArticleForInfoWindow!.location != null) {
                _updateInfoWindowPosition(LatLng(
                  _selectedArticleForInfoWindow!.location!.latitude,
                  _selectedArticleForInfoWindow!.location!.longitude,
                ));
              }
            },
          ),
          if (_selectedArticleForInfoWindow != null && _infoWindowOffset != null)
            Positioned(
              left: _infoWindowOffset!.dx,
              top: _infoWindowOffset!.dy,
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