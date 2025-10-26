import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class TravelRouteMapPage extends StatefulWidget {
  const TravelRouteMapPage({super.key});

  @override
  State<TravelRouteMapPage> createState() => _TravelRouteMapPageState();
}

class _TravelRouteMapPageState extends State<TravelRouteMapPage> {
  GoogleMapController? mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _articles = [];
  List<Map<String, dynamic>> _selectedArticles = []; // <--- 初始為空列表
  final Map<String, BitmapDescriptor> _thumbnailCache = {};

  static const LatLng _initialCameraPosition = LatLng(23.6937, 120.8906);

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _updateMapElements();
  }

  Future<void> _loadArticles() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('articles')
          .orderBy('updatedAt', descending: false) // 假設遊記有時間戳，按時間排序來連接路徑
          .get();
      setState(() {
        _articles = querySnapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList();
        // 初始載入時，_selectedArticles 保持為空，讓用戶手動選擇
        // _selectedArticles = List.from(_articles); // 移除此行，讓 _selectedArticles 初始為空
      });
      _updateMapElements(); // 載入後更新地圖，此時應只顯示預設地點（如果有的話）
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入遊記失敗: $e')),
      );
      print("Error loading articles for route map: $e");
    }
  }

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

    // 添加選定遊記的標記
    for (var article in _selectedArticles) {
      final GeoPoint geoPoint = article['location'];
      final String articleId = article['id'];
      // final String? thumbnailUrl = article['thumbnailImageUrl']; // 暫時註釋，因為沒有使用到

      BitmapDescriptor markerIcon;
      // 如果需要自定義標記圖標，可以取消註釋下面這段
      // if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      //   markerIcon = await _getCustomMarkerIcon(thumbnailUrl, articleId);
      // } else {
      //   markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      // }
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);


      _markers.add(
        Marker(
          markerId: MarkerId(articleId),
          position: LatLng(geoPoint.latitude, geoPoint.longitude),
          infoWindow: InfoWindow(
            title: article['placeName'] ?? article['title'] ?? '遊記',
            snippet: article['address'] ?? '',
          ),
          icon: markerIcon,
          onTap: () {
            // 可以添加點擊標記後的互動，例如顯示詳細資訊
          },
        ),
      );
    }

    // 連接選定遊記的路徑
    if (_selectedArticles.length > 1) { // <--- 確保至少有兩個遊記才繪製路徑
      List<LatLng> polylinePoints = _selectedArticles.map((article) {
        final GeoPoint geoPoint = article['location'];
        return LatLng(geoPoint.latitude, geoPoint.longitude);
      }).toList();

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

    setState(() {});
  }

  void _showArticleSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // 使用 StatefulBuilder 來管理對話框內部的狀態
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: const Text('選擇遊記來顯示路徑'),
              content: _articles.isEmpty
                  ? const Text('目前沒有遊記可供選擇。')
                  : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _articles.map((article) {
                    final isSelected = _selectedArticles.any((selected) => selected['id'] == article['id']);
                    return CheckboxListTile(
                      title: Text(article['title'] ?? article['placeName'] ?? '無標題'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setStateInDialog(() {
                          if (value == true) {
                            _selectedArticles.add(article);
                          } else {
                            _selectedArticles.removeWhere((selected) => selected['id'] == article['id']);
                          }
                          // 對選擇的遊記進行排序，例如按時間戳 (如果遊記數據中有 timestamp 欄位)
                          _selectedArticles.sort((a, b) {
                            final tsA = a['timestamp'];
                            final tsB = b['timestamp'];

                            if (tsA is Timestamp && tsB is Timestamp) {
                              return tsA.compareTo(tsB);
                            }
                            // 如果 timestamp 不存在或不是 Timestamp 類型，則使用其他方式排序或保持原有順序
                            // 這裡簡單地將沒有 timestamp 的放在後面，或根據id排序
                            if (tsA == null && tsB == null) return 0;
                            if (tsA == null) return 1;
                            if (tsB == null) return -1;
                            return (a['id'] as String).compareTo(b['id'] as String); // fallback to ID sort
                          });
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: const Text('確認'),
                  onPressed: () {
                    // 更新地圖上的標記和路徑
                    _updateMapElements();
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('遊記路徑地圖'),
        actions: [
          IconButton(
            icon: const Icon(Icons.line_axis),
            onPressed: _showArticleSelectionDialog,
            tooltip: '選擇遊記來顯示路徑',
          ),
        ],
      ),
      body: GoogleMap(
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
      ),
    );
  }
}