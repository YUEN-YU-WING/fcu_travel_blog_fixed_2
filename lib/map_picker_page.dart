import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; // 引入 Firestore
import 'package:firebase_auth/firebase_auth.dart'; // 引入 FirebaseAuth
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 引入 dotenv (如果你使用方案一)

// 假設你的 EditArticlePage 位於 'edit_article_page.dart'
import 'edit_article_page.dart';
// 假設你有一個 ArticleDetailPage 用於顯示遊記詳情
import 'my_articles_page.dart'; // 如果有，請取消註解

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? mapController;
  LatLng? _selectedLocation; // 用於新增遊記時的地點
  String? _selectedAddress; // 用於新增遊記時的地址
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {}; // 所有地圖上的標記，包括選定地點和遊記

  List<Map<String, dynamic>> _articles = []; // 儲存從 Firebase 載入的遊記

  // ❗ 替換為你的 Web API Key，或從 dotenv 加載
  final String _googleMapsApiKey = kIsWeb ? dotenv.env['GOOGLE_MAPS_WEB_API_KEY']! : "";

  static const LatLng _initialCameraPosition = LatLng(23.6937, 120.8906);

  @override
  void initState() {
    super.initState();
    // _selectedLocation = _initialCameraPosition;
    // _addMarker(_initialCameraPosition);
    // _getAddressFromLatLng(_initialCameraPosition);
    _loadArticles(); // 載入遊記
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _updateMarkers(); // 在地圖創建後更新所有標記
  }

  void _onTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
      // 點擊地圖時只更新選定位置的標記，保留遊記標記
      _updateMarkers(newSelectedLocation: latLng);
    });
    _getAddressFromLatLng(latLng);
  }

  void _addMarker(LatLng latLng, {String? markerId, String? title, String? snippet, Function? onTapCallback}) {
    _markers.add(
      Marker(
        markerId: MarkerId(markerId ?? 'selected_location'),
        position: latLng,
        infoWindow: InfoWindow(
          title: title ?? '選取的位置',
          snippet: snippet,
          onTap: onTapCallback != null ? () => onTapCallback() : null,
        ),
        icon: onTapCallback != null ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange) : BitmapDescriptor.defaultMarker, // 遊記用橘色標記
      ),
    );
  }

  // 重新整理所有標記
  void _updateMarkers({LatLng? newSelectedLocation}) {
    _markers.clear();
    // 添加所有遊記標記
    for (var article in _articles) {
      final GeoPoint geoPoint = article['location'];
      _addMarker(
        LatLng(geoPoint.latitude, geoPoint.longitude),
        markerId: article['id'],
        title: article['title'],
        snippet: article['address'] ?? '點擊查看詳情',
        onTapCallback: () {
          // 點擊遊記標記時導航到遊記詳情頁面
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => ArticleDetailPage(articleId: article['id'])),
          // );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('點擊了遊記: ${article['title']}')),
          );
        },
      );
    }
    // 添加當前選定地點的標記
    if (newSelectedLocation != null) {
      _addMarker(newSelectedLocation);
    } else if (_selectedLocation != null) {
      _addMarker(_selectedLocation!);
    }
    setState(() {}); // 更新 UI
  }

  // 從 Firestore 載入遊記
  Future<void> _loadArticles() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('articles').get();
      setState(() {
        _articles = querySnapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id, // 將 document ID 也儲存起來
        }).toList();
        _updateMarkers(); // 載入後更新地圖上的標記
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入遊記失敗: $e')),
      );
      print("Error loading articles: $e");
    }
  }

  // --- Web 平台專用的反向地理編碼 ---
  Future<String> _getWebAddressFromLatLng(LatLng latLng) async {
    // ... (保持不變，與上次提供的程式碼相同) ...
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

  // --- Web 平台專用的地理編碼 (搜尋地點) ---
  Future<List<LatLng>> _getWebLatLngFromAddress(String address) async {
    // ... (保持不變，與上次提供的程式碼相同) ...
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

  // --- 判斷平台，調用不同地理編碼邏輯 ---
  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    String addressResult;
    if (kIsWeb) {
      addressResult = await _getWebAddressFromLatLng(latLng);
    } else {
      // Android/iOS 平台繼續使用 geocoding 套件
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
          if (addressResult.isEmpty) {
            addressResult = "無法找到詳細地址，經緯度: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
          }
        } else {
          addressResult = "無法找到地址資訊，經緯度: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
        }
      } catch (e) {
        print("Error getting address on non-web: $e");
        addressResult = "獲取地址失敗 (Native): $e";
      }
    }
    setState(() {
      _selectedAddress = addressResult;
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
      _onTap(latLng); // 更新選取位置和標記
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
    if (_selectedLocation == null || _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先在地圖上選擇一個地點')),
      );
      return;
    }

    // 導航到 EditArticlePage，並傳遞選定地點和地址
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditArticlePage(
          initialLocation: _selectedLocation,
          initialAddress: _selectedAddress,
        ),
      ),
    );

    // 如果 EditArticlePage 儲存成功並返回 true，則重新載入遊記
    if (result == true) {
      _loadArticles();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 檢查用戶登入狀態，以決定是否顯示「新增遊記」按鈕
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇地點與查看遊記'),
        actions: [
          if (isLoggedIn && _selectedLocation != null) // 登入狀態下且選取地點後才顯示
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              onPressed: _createNewArticle,
              tooltip: '新增遊記',
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_selectedLocation != null) {
                Navigator.pop(context, {
                  'location': _selectedLocation,
                  'address': _selectedAddress,
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
      body: Column(
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
          if (_selectedAddress != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                '選取地址: $_selectedAddress',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                target: _initialCameraPosition,
                zoom: 8.0,
              ),
              onTap: _onTap,
              markers: _markers,
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}