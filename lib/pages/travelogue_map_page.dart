import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui; // 引入 ui 用於圖片處理
import 'package:flutter/services.dart';
import '../edit_article_page.dart';
import '../article_detail_page.dart';
import '../models/travel_article_data.dart';

class TravelogueMapPage extends StatefulWidget {
  final bool embedded;
  final bool isPublicView;

  const TravelogueMapPage({
    super.key,
    this.embedded = false,
    this.isPublicView = false,
  });

  @override
  State<TravelogueMapPage> createState() => _TravelogueMapPageState();
}

class _TravelogueMapPageState extends State<TravelogueMapPage> {
  // ... (省略狀態變數宣告，保持不變) ...
  GoogleMapController? mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  String? _selectedPlaceName;
  final TextEditingController _searchController = TextEditingController();
  final Set<Marker> _markers = {};

  List<Map<String, dynamic>> _articles = [];
  final Map<String, BitmapDescriptor> _thumbnailCache = {};

  final String _googleMapsApiKey = kIsWeb ? dotenv.env['GOOGLE_MAPS_WEB_API_KEY']! : "";
  static const LatLng _initialCameraPosition = LatLng(23.6937, 120.8906);

  bool _showCustomInfoWindow = false;
  Map<String, dynamic>? _currentInfoWindowArticle;
  Offset? _customInfoWindowPosition;

  @override
  void initState() {
    super.initState();
    if (!widget.isPublicView) {
      _selectedLocation = _initialCameraPosition;
      _getAddressFromLatLng(_initialCameraPosition);
    }
    _loadArticles();
    _updateMarkers();
  }

  @override
  void dispose() {
    mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _updateMarkers();
  }

  void _onMapTap(LatLng latLng) {
    if (widget.isPublicView) {
      setState(() {
        _showCustomInfoWindow = false;
        _currentInfoWindowArticle = null;
      });
      return;
    }

    setState(() {
      _selectedLocation = latLng;
      _selectedPlaceName = null;
      _showCustomInfoWindow = false;
      _updateMarkers(newSelectedLocation: latLng);
    });
    _getAddressFromLatLng(latLng);
  }

  Future<void> _onMarkerTap(String articleId) async {
    // ... (保持不變) ...
    final article = _articles.firstWhere((a) => a['id'] == articleId);
    final geoPoint = article['location'] as GeoPoint;
    final LatLng markerLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);

    mapController?.animateCamera(CameraUpdate.newLatLng(markerLatLng));

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    final Offset position = Offset(screenWidth / 2 - 150, screenHeight / 2 - 150);

    setState(() {
      _showCustomInfoWindow = true;
      _currentInfoWindowArticle = article;
      _customInfoWindowPosition = position;
    });
  }

  // [修改 1] 實現圓形標記圖片
  // 這個函式現在會下載圖片，並使用 Canvas 將其裁切成圓形
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

        // 2. 設定畫布與尺寸
        const double size = 100.0; // 設定標記的大小
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

        // 可選：加上一個邊框讓它更明顯
        final Paint borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..isAntiAlias = true;
        canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 2.0, borderPaint);


        // 6. 將畫布轉換為 PNG 圖片數據
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
    // 如果載入失敗，回傳預設標記
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }


  Future<void> _updateMarkers({LatLng? newSelectedLocation}) async {
    // ... (保持不變) ...
    _markers.clear();
    for (var article in _articles) {
      final GeoPoint geoPoint = article['location'];
      final String articleId = article['id'];
      final String? thumbnailUrl = article['thumbnailImageUrl'];

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
          icon: markerIcon,
          onTap: () => _onMarkerTap(articleId),
        ),
      );
    }

    if (!widget.isPublicView && (newSelectedLocation != null || _selectedLocation != null)) {
      LatLng currentSelected = newSelectedLocation ?? _selectedLocation!;
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: currentSelected,
          infoWindow: InfoWindow(
            title: _selectedPlaceName ?? '選取的位置',
            snippet: _selectedAddress ?? '',
          ),
          icon: BitmapDescriptor.defaultMarker,
          onTap: () {
            setState(() {
              _showCustomInfoWindow = false;
            });
          },
        ),
      );
    }
    if (mounted) setState(() {});
  }

  // ... (省略 _loadArticles, _getWebAddressFromLatLng, _getWebLatLngFromAddress, _getAddressFromLatLng, _searchLocation, _createNewArticle 方法，保持不變) ...
  Future<void> _loadArticles() async {
    // 保持原樣...
    try {
      Query query = FirebaseFirestore.instance.collection('articles');
      if (widget.isPublicView) {
        query = query.where('isPublic', isEqualTo: true);
      }
      final querySnapshot = await query.get();
      if (mounted) {
        setState(() {
          _articles = querySnapshot.docs.map((doc) => {
            ...doc.data() as Map<String, dynamic>,
            'id': doc.id,
          }).toList();
        });
        _updateMarkers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('載入遊記失敗: $e')),
        );
      }
      print("Error loading articles: $e");
    }
  }
  Future<String> _getWebAddressFromLatLng(LatLng latLng) async {
    // 保持原樣...
    final String url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}&key=$_googleMapsApiKey&language=zh-TW";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'OK' && jsonResponse['results'].isNotEmpty) {
          return jsonResponse['results'][0]['formatted_address'] ?? '無法找到地址';
        }
      }
      return '地址查詢失敗';
    } catch (e) {
      return '錯誤: $e';
    }
  }
  Future<List<LatLng>> _getWebLatLngFromAddress(String address) async {
    // 保持原樣...
    final String url = "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_googleMapsApiKey&language=zh-TW";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'OK' && jsonResponse['results'].isNotEmpty) {
          final geometry = jsonResponse['results'][0]['geometry']['location'];
          return [LatLng(geometry['lat'], geometry['lng'])];
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    // 保持原樣...
    String addressResult;
    String placeNameResult = '';
    if (kIsWeb) {
      addressResult = await _getWebAddressFromLatLng(latLng);
      placeNameResult = addressResult.split(',').first.trim();
    } else {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          List<String> addressParts = [];
          if (place.country != null && place.country!.isNotEmpty) addressParts.add(place.country!);
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) addressParts.add(place.administrativeArea!);
          if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
          if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
          if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) addressParts.add(place.thoroughfare!);
          if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) addressParts.add(place.subThoroughfare!);
          if (place.name != null && place.name!.isNotEmpty) {
            String combinedParts = addressParts.join('');
            if (!combinedParts.contains(place.name!)) {
              addressParts.add(place.name!);
            }
          }
          addressResult = addressParts.join(', ');
          placeNameResult = place.name ?? place.thoroughfare ?? place.locality ?? addressResult.split(',').first.trim();

          if (addressResult.isEmpty) addressResult = "無法找到詳細地址";
        } else {
          addressResult = "無法找到地址資訊";
          placeNameResult = "未知地標";
        }
      } catch (e) {
        addressResult = "獲取地址失敗";
        placeNameResult = "獲取地標失敗";
      }
    }
    setState(() {
      _selectedAddress = addressResult;
      _selectedPlaceName = placeNameResult;
    });
  }
  Future<void> _searchLocation() async {
    // 保持原樣...
    final query = _searchController.text;
    if (query.isEmpty) return;
    List<LatLng> locations = [];
    if (kIsWeb) {
      locations = await _getWebLatLngFromAddress(query);
    } else {
      try {
        List<Location> geocodingLocations = await locationFromAddress(query);
        locations = geocodingLocations.map((loc) => LatLng(loc.latitude, loc.longitude)).toList();
      } catch (e) {
        print(e);
      }
    }
    if (locations.isNotEmpty) {
      final latLng = locations[0];
      mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      _onMapTap(latLng);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('找不到該地點')));
    }
  }
  Future<void> _createNewArticle() async {
    // 保持原樣...
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先登入才能新增遊記')));
      return;
    }
    if (_selectedLocation == null || _selectedAddress == null || _selectedPlaceName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先在地圖上選擇一個地點並確認地標名稱')));
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditArticlePage(
          initialLocation: _selectedLocation,
          initialAddress: _selectedAddress,
          initialPlaceName: _selectedPlaceName,
        ),
      ),
    );
    if (result == true) {
      _loadArticles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPublicView ? '公開遊記地圖' : '遊記地點標記地圖'),
        actions: [
          if (!widget.isPublicView && isLoggedIn && _selectedLocation != null && _selectedPlaceName != null)
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              onPressed: _createNewArticle,
              tooltip: '新增遊記',
            ),
          if (!widget.isPublicView)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                if (_selectedLocation != null && _selectedAddress != null && _selectedPlaceName != null) {
                  Navigator.pop(context, {
                    'location': _selectedLocation,
                    'address': _selectedAddress,
                    'placeName': _selectedPlaceName,
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請在地圖上選擇一個地點')),
                  );
                }
              },
              tooltip: '確認選取地點',
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '搜尋地點',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onSubmitted: (_) => _searchLocation(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchLocation,
                    ),
                  ],
                ),
              ),
              if (!widget.isPublicView && _selectedPlaceName != null && _selectedPlaceName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: Text(
                    '地標名稱: $_selectedPlaceName',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (!widget.isPublicView && _selectedAddress != null && _selectedAddress!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    '選取地址: $_selectedAddress',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Expanded(
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: const CameraPosition(
                    target: _initialCameraPosition,
                    zoom: 8.0,
                  ),
                  onTap: _onMapTap,
                  markers: _markers,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
            ],
          ),
          if (_showCustomInfoWindow && _currentInfoWindowArticle != null && _customInfoWindowPosition != null)
            Positioned(
              left: _customInfoWindowPosition!.dx,
              top: _customInfoWindowPosition!.dy,
              child: CustomInfoWindow(
                article: _currentInfoWindowArticle!,
                isPublicView: widget.isPublicView,
                onClose: () {
                  setState(() {
                    _showCustomInfoWindow = false;
                    _currentInfoWindowArticle = null;
                  });
                },
                onAction: () async {
                  setState(() {
                    _showCustomInfoWindow = false;
                  });

                  if (widget.isPublicView) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleDetailPage(
                          articleId: _currentInfoWindowArticle!['id'],
                        ),
                      ),
                    );
                  } else {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditArticlePage(
                          articleId: _currentInfoWindowArticle!['id'],
                          initialTitle: _currentInfoWindowArticle!['title'],
                          initialContent: _currentInfoWindowArticle!['content'],
                          initialLocation: LatLng(
                            (_currentInfoWindowArticle!['location'] as GeoPoint).latitude,
                            (_currentInfoWindowArticle!['location'] as GeoPoint).longitude,
                          ),
                          initialAddress: _currentInfoWindowArticle!['address'],
                          initialPlaceName: _currentInfoWindowArticle!['placeName'],
                          initialThumbnailImageUrl: _currentInfoWindowArticle!['thumbnailImageUrl'],
                          initialThumbnailFileName: _currentInfoWindowArticle!['thumbnailFileName'],
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadArticles();
                    }
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// --- 自定義 InfoWindow Widget ---
class CustomInfoWindow extends StatelessWidget {
  final Map<String, dynamic> article;
  final VoidCallback onClose;
  final VoidCallback onAction;
  final bool isPublicView;

  const CustomInfoWindow({
    super.key,
    required this.article,
    required this.onClose,
    required this.onAction,
    this.isPublicView = false,
  });

  @override
  Widget build(BuildContext context) {
    final String title = article['title'] ?? '無標題遊記';
    final String placeName = article['placeName'] ?? '';
    final String address = article['address'] ?? '';
    final String? thumbnailUrl = article['thumbnailImageUrl'];

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
                  // [修改 2] 這裡改為顯示標題 (Title)
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
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 80),
                  ),
                ),
              ),
            // [修改 2] 這裡改為顯示地名 (Place Name)
            if (placeName.isNotEmpty)
              Text(
                placeName,
                style: const TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              address,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton.icon(
                icon: Icon(isPublicView ? Icons.visibility : Icons.edit, size: 18),
                label: Text(isPublicView ? '查看詳情' : '編輯遊記'),
                onPressed: onAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}