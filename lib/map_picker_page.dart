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
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'edit_article_page.dart';

class MapPickerPage extends StatefulWidget {
  final bool embedded;

  const MapPickerPage({super.key, this.embedded = false});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
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

  // --- 自定義 InfoWindow 相關狀態 ---
  bool _showCustomInfoWindow = false;
  Map<String, dynamic>? _currentInfoWindowArticle; // 儲存當前點擊遊記的資料
  Offset? _customInfoWindowPosition; // InfoWindow 的螢幕位置

  @override
  void initState() {
    super.initState();
    _selectedLocation = _initialCameraPosition;
    _getAddressFromLatLng(_initialCameraPosition);
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

  // 修改 _onTap，現在它只用於選擇地點，點擊標記則觸發自定義 InfoWindow
  void _onMapTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
      _selectedPlaceName = null; // 點擊新地點時清除地標名稱
      _showCustomInfoWindow = false; // 點擊地圖空白處關閉 InfoWindow
      _updateMarkers(newSelectedLocation: latLng);
    });
    _getAddressFromLatLng(latLng);
  }

  // 點擊 Marker 的處理邏輯，現在用於顯示自定義 InfoWindow
  Future<void> _onMarkerTap(String articleId) async {
    final article = _articles.firstWhere((a) => a['id'] == articleId);
    final geoPoint = article['location'] as GeoPoint;
    final LatLng markerLatLng = LatLng(geoPoint.latitude, geoPoint.longitude);

    // 將地圖中心移動到標記點
    mapController?.animateCamera(CameraUpdate.newLatLng(markerLatLng));

    // 計算 InfoWindow 的螢幕位置
    // 這是一個近似值，更精確的計算需要地圖的投影轉換
    // 這裡簡單地將 InfoWindow 顯示在螢幕中央上方
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    // 將 InfoWindow 放置在螢幕上方中央附近
    final Offset position = Offset(screenWidth / 2 - 150, screenHeight / 2 - 150);


    setState(() {
      _showCustomInfoWindow = true;
      _currentInfoWindowArticle = article;
      _customInfoWindowPosition = position;
    });
  }


  Future<BitmapDescriptor> _getCustomMarkerIcon(String imageUrl, String markerId) async {
    if (_thumbnailCache.containsKey(markerId)) {
      return _thumbnailCache[markerId]!;
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        final ui.Codec codec = await ui.instantiateImageCodec(bytes, targetWidth: 80, targetHeight: 80); // 確保是正方形
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

  Future<void> _updateMarkers({LatLng? newSelectedLocation}) async {
    _markers.clear();
    for (var article in _articles) {
      final GeoPoint geoPoint = article['location'];
      final String articleId = article['id'];
      final String? thumbnailUrl = article['thumbnailImageUrl'];

      BitmapDescriptor markerIcon;
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
          // 注意：這裡 InfoWindow 的 onTap 不再是導航，而是觸發自定義 InfoWindow
          // 原生的 InfoWindow 只用於顯示簡單的文字提示，實際交互由 _onMarkerTap 處理
          // infoWindow: InfoWindow(
          //   title: article['placeName'] ?? article['title'] ?? '遊記',
          //   snippet: article['address'] ?? '',
          // ),
          icon: markerIcon,
          onTap: () => _onMarkerTap(articleId), // 點擊 Marker 觸發自定義 InfoWindow
        ),
      );
    }

    // 當前選定地點的標記
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
          // 點擊選定地點標記時，可以選擇顯示一個簡單的原生 InfoWindow
          // 或者關閉自定義 InfoWindow
          setState(() {
            _showCustomInfoWindow = false; // 點擊藍色標記時關閉自定義 InfoWindow
          });
        },
      ),
    );
    setState(() {});
  }

  Future<void> _loadArticles() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('articles').get();
      setState(() {
        _articles = querySnapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList();
      });
      _updateMarkers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入遊記失敗: $e')),
      );
      print("Error loading articles: $e");
    }
  }

  Future<String> _getWebAddressFromLatLng(LatLng latLng) async {
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}&key=$_googleMapsApiKey&language=zh-TW";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'OK' && jsonResponse['results'].isNotEmpty) {
          return jsonResponse['results'][0]['formatted_address'] ?? '無法找到地址';
        } else {
          return '無法找到地址資訊: ${jsonResponse['status']}';
        }
      } else {
        return '獲取地址失敗 (HTTP ${response.statusCode})';
      }
    } catch (e) {
      print("Error in _getWebAddressFromLatLng: $e");
      return '獲取地址時發生錯誤: $e';
    }
  }

  Future<List<LatLng>> _getWebLatLngFromAddress(String address) async {
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_googleMapsApiKey&language=zh-TW";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'OK' && jsonResponse['results'].isNotEmpty) {
          final geometry = jsonResponse['results'][0]['geometry']['location'];
          return [LatLng(geometry['lat'], geometry['lng'])];
        } else {
          print("Error in _getWebLatLngFromAddress: ${jsonResponse['status']}");
          return [];
        }
      } else {
        print("HTTP Error in _getWebLatLngFromAddress: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error in _getWebLatLngFromAddress: $e");
      return [];
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
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

          if (addressResult.isEmpty) {
            addressResult = "無法找到詳細地址，經緯度: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
          }
        } else {
          addressResult = "無法找到地址資訊，經緯度: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
          placeNameResult = "未知地標";
        }
      } catch (e) {
        print("Error getting address on non-web: $e");
        addressResult = "獲取地址失敗 (Native): $e";
        placeNameResult = "獲取地標失敗";
      }
    }
    setState(() {
      _selectedAddress = addressResult;
      _selectedPlaceName = placeNameResult;
    });
  }

  Future<void> _searchLocation() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜尋失敗 (Native): $e')),
        );
        print("Error searching location on non-web: $e");
      }
    }

    if (locations.isNotEmpty) {
      final latLng = locations[0];
      mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      _onMapTap(latLng); // 使用 _onMapTap 處理，因為它會清除 InfoWindow
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到該地點')),
      );
    }
  }

  Future<void> _createNewArticle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先登入才能新增遊記')),
      );
      return;
    }
    if (_selectedLocation == null || _selectedAddress == null || _selectedPlaceName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先在地圖上選擇一個地點並確認地標名稱')),
      );
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
        title: const Text('選擇地點與查看遊記'),
        actions: [
          if (isLoggedIn && _selectedLocation != null && _selectedPlaceName != null)
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              onPressed: _createNewArticle,
              tooltip: '新增遊記',
            ),
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
      body: Stack( // 使用 Stack 來疊加地圖和自定義 InfoWindow
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
              if (_selectedPlaceName != null && _selectedPlaceName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  child: Text(
                    '地標名稱: $_selectedPlaceName',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_selectedAddress != null && _selectedAddress!.isNotEmpty)
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
                  onTap: _onMapTap, // 點擊地圖時關閉 InfoWindow
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
                onClose: () {
                  setState(() {
                    _showCustomInfoWindow = false;
                    _currentInfoWindowArticle = null;
                  });
                },
                onEdit: () async {
                  setState(() {
                    _showCustomInfoWindow = false; // 關閉 InfoWindow
                  });
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
                    _loadArticles(); // 重新載入遊記
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
  final VoidCallback onEdit;

  const CustomInfoWindow({
    super.key,
    required this.article,
    required this.onClose,
    required this.onEdit,
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
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
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
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('編輯遊記'),
                onPressed: onEdit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}