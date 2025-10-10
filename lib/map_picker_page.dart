import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 引入 kIsWeb
import 'package:http/http.dart' as http; // 引入 http 套件
import 'dart:convert'; // 引入 JSON 解析
import 'package:flutter_dotenv/flutter_dotenv.dart';


class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  final TextEditingController _searchController = TextEditingController();
  Set<Marker> _markers = {};

  List<dynamic> _placeSuggestions = []; // 用於儲存自動完成建議
  String? _sessionToken; // 用於 Places Autocomplete 會話，避免重複計費

  static const LatLng _initialCameraPosition = LatLng(24.1792, 120.6466);

  // ❗ 替換為你的 Web API Key，這個 Key 需要啟用 Geocoding API
  // 為了安全，在生產環境中不應該直接寫死在程式碼中，可以考慮環境變數或 Firebase Config
  final String _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_WEB_API_KEY']!;

  @override
  void initState() {
    super.initState();
    _selectedLocation = _initialCameraPosition;
    _addMarker(_initialCameraPosition);
    _getAddressFromLatLng(_initialCameraPosition);
    _searchController.addListener(_onSearchChanged); // 監聽搜尋框變化
    _startNewSessionToken(); // 初始化會話 token
  }

  void _startNewSessionToken() {
    // 為每個新的地點搜尋會話生成一個新的 token
    // 這有助於 Google Maps API 正確計費
    _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _onSearchChanged() {
    if (_searchController.text.isNotEmpty) {
      _getPlaceAutocompleteSuggestions(_searchController.text);
    } else {
      setState(() {
        _placeSuggestions.clear();
      });
    }
  }

  // 獲取地點自動完成建議
  Future<void> _getPlaceAutocompleteSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _placeSuggestions.clear();
      });
      return;
    }

    final String url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?"
        "input=${Uri.encodeComponent(query)}&"
        "key=$_googleMapsApiKey&"
        "language=zh-TW&"
        "sessiontoken=$_sessionToken"; // 使用會話 token

    // ... 在 _getPlaceAutocompleteSuggestions 函式中 ...
    try {
      final response = await http.get(Uri.parse(url));
      print('HTTP Response Status: ${response.statusCode}'); // 打印狀態碼
      print('HTTP Response Headers: ${response.headers}'); // 打印響應頭
      print('HTTP Response Body Length: ${response.bodyBytes.length}'); // 打印響應體長度

      if (response.statusCode == 200) {
        // 再次嘗試打印原始響應，看是否真的完整到達
        print('Raw response body for autocomplete: ${response.body}');

        // 嘗試在解析前檢查響應體是否為空或無效
        if (response.body.isEmpty) {
          print('Warning: Autocomplete API returned empty body despite 200 OK.');
          setState(() { _placeSuggestions.clear(); });
          return;
        }

        final jsonResponse = json.decode(response.body);
        print('Parsed Autocomplete JSON: $jsonResponse'); // 打印解析後的 JSON
        if (jsonResponse['status'] == 'OK') {
          setState(() {
            _placeSuggestions = jsonResponse['predictions'];
          });
        } else {
          print("Places Autocomplete API Status Error: ${jsonResponse['status']}");
          setState(() { _placeSuggestions.clear(); });
        }
      } else {
        print("HTTP Error for Autocomplete (Non-200): ${response.statusCode}");
        print("Error response body: ${response.body}"); // 打印非200的響應體
        setState(() { _placeSuggestions.clear(); });
      }
    } catch (e) {
      print("Unhandled exception in _getPlaceAutocompleteSuggestions: $e");
      setState(() { _placeSuggestions.clear(); });
    }
  }

  // 當用戶選擇一個建議後，獲取該地點的詳細資訊
  Future<void> _getPlaceDetails(String placeId) async {
    final String url =
        "https://maps.googleapis.com/maps/api/place/details/json?"
        "place_id=$placeId&"
        "key=$_googleMapsApiKey&"
        "language=zh-TW&"
        "sessiontoken=$_sessionToken"; // 再次使用會話 token

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'OK' && jsonResponse['result'] != null) {
          final result = jsonResponse['result'];
          final lat = result['geometry']['location']['lat'];
          final lng = result['geometry']['location']['lng'];
          final formattedAddress = result['formatted_address'];

          final LatLng newLocation = LatLng(lat, lng);
          setState(() {
            _selectedLocation = newLocation;
            _selectedAddress = formattedAddress;
            _markers.clear();
            _addMarker(newLocation);
            _placeSuggestions.clear(); // 清空建議列表
            _searchController.text = formattedAddress; // 更新搜尋框顯示
            _startNewSessionToken(); // 開始新的會話
          });
          mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('獲取地點詳情失敗: ${jsonResponse['status']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('獲取地點詳情 HTTP 錯誤: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('獲取地點詳情時發生錯誤: $e')),
      );
    }
  }

  // @override
  // void initState() {
  //   super.initState();
  //   _selectedLocation = _initialCameraPosition;
  //   _addMarker(_initialCameraPosition);
  //   _getAddressFromLatLng(_initialCameraPosition);
  // }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onTap(LatLng latLng) {
    setState(() {
      _selectedLocation = latLng;
      _markers.clear();
      _addMarker(latLng);
    });
    _getAddressFromLatLng(latLng);
  }

  void _addMarker(LatLng latLng) {
    _markers.add(
      Marker(
        markerId: const MarkerId('selected_location'),
        position: latLng,
        infoWindow: const InfoWindow(title: '選取的位置'),
      ),
    );
  }

  // --- Web 平台專用的反向地理編碼 ---
  Future<String> _getWebAddressFromLatLng(LatLng latLng) async {
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}&key=$_googleMapsApiKey&language=zh-TW";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'OK' && jsonResponse['results'].isNotEmpty) {
          // 返回格式化的地址
          return jsonResponse['results'][0]['formatted_address'] ?? '無法找到地址';
        } else {
          // 如果 API 返回 OK 但沒有結果，或者狀態不是 OK
          return '無法找到地址資訊: ${jsonResponse['status']}';
        }
      } else {
        // HTTP 請求失敗
        return '獲取地址失敗 (HTTP ${response.statusCode})';
      }
    } catch (e) {
      // 捕獲網絡或其他錯誤
      print("Error in _getWebAddressFromLatLng: $e");
      return '獲取地址時發生錯誤: $e';
    }
  }

  // --- Web 平台專用的地理編碼 (搜尋地點) ---
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
            if (!combinedParts.contains(place.name!)) { // 避免重複
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇地點'),
        actions: [
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
            tooltip: '確認',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜尋地點或地址', // 修改提示文字
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              // onSubmitted: (_) => _searchLocation(), // 不再直接調用 searchLocation
            ),
          ),
          // 顯示自動完成建議列表
          if (_placeSuggestions.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _placeSuggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _placeSuggestions[index];
                  return ListTile(
                    title: Text(suggestion['description']),
                    onTap: () {
                      // 當用戶點擊建議時
                      _getPlaceDetails(suggestion['place_id']);
                    },
                  );
                },
              ),
            ),
          // ... 原來的選取地址顯示 ...
          if (_selectedAddress != null && _placeSuggestions.isEmpty) // 當沒有建議時才顯示地圖
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Text(
                '選取地址: $_selectedAddress',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          // 地圖只有在沒有建議時才顯示，避免遮擋
          if (_placeSuggestions.isEmpty)
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