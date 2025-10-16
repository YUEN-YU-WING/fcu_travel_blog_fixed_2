// lib/services/location_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb; // 導入 kIsWeb
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart'; // 用於非網頁平台

class LocationService {
  static String? _googleMapsApiKey;

  static Future<void> initialize() async {
    await dotenv.load();
    _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_WEB_API_KEY'];
    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
      print("WARNING: GOOGLE_MAPS_WEB_API_KEY is not set in .env file.");
    }
  }

  // 根據經緯度獲取詳細地址 (網頁版)
  static Future<String> getWebAddressFromLatLng(LatLng latLng) async {
    if (_googleMapsApiKey == null) return 'API Key 未設定';
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
      print("Error in getWebAddressFromLatLng: $e");
      return '獲取地址時發生錯誤: $e';
    }
  }

  // 根據地址獲取經緯度 (網頁版)
  static Future<LatLng?> getWebLatLngFromAddress(String address) async {
    if (_googleMapsApiKey == null) return null;
    final String url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_googleMapsApiKey&language=zh-TW";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'OK' && jsonResponse['results'].isNotEmpty) {
          final geometry = jsonResponse['results'][0]['geometry']['location'];
          return LatLng(geometry['lat'], geometry['lng']);
        } else {
          print("Error in getWebLatLngFromAddress: ${jsonResponse['status']}");
          return null;
        }
      } else {
        print("HTTP Error in getWebLatLngFromAddress: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error in getWebLatLngFromAddress: $e");
      return null;
    }
  }

  // 根據經緯度獲取詳細地址和地標名稱 (非網頁版使用 geocoding 套件)
  static Future<Map<String, String>> getAddressAndPlaceNameFromLatLng(LatLng latLng) async {
    if (kIsWeb) {
      // 網頁版使用 Google Geocoding API
      final String addressResult = await getWebAddressFromLatLng(latLng);
      final String placeNameResult = addressResult.split(',').first.trim(); // 簡單地將地址的第一部分作為地標名稱
      return {'address': addressResult, 'placeName': placeNameResult};
    } else {
      // 非網頁版使用 geocoding 套件
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
            if (!combinedParts.contains(place.name!)) { // 避免重複添加
              addressParts.add(place.name!);
            }
          }
          String addressResult = addressParts.join(', ');
          String placeNameResult = place.name ?? place.thoroughfare ?? place.locality ?? addressResult.split(',').first.trim();

          if (addressResult.isEmpty) {
            addressResult = "無法找到詳細地址，經緯度: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
          }
          return {'address': addressResult, 'placeName': placeNameResult};
        } else {
          return {
            'address': "無法找到地址資訊，經緯度: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}",
            'placeName': "未知地標"
          };
        }
      } catch (e) {
        print("Error getting address on non-web: $e");
        return {
          'address': "獲取地址失敗 (Native): $e",
          'placeName': "獲取地標失敗"
        };
      }
    }
  }

  // 新增：根據地名搜索地點，並返回其經緯度、地址和地標名稱
  static Future<Map<String, dynamic>?> searchPlaceByName(String placeNameQuery) async {
    if (placeNameQuery.isEmpty) return null;

    final LatLng? latLng = await getWebLatLngFromAddress(placeNameQuery); // 首先獲取經緯度

    if (latLng != null) {
      // 然後根據經緯度獲取詳細地址和地標名稱
      final Map<String, String> addressDetails = await getAddressAndPlaceNameFromLatLng(latLng);
      return {
        'placeName': addressDetails['placeName'],
        'address': addressDetails['address'],
        'location': latLng, // 使用 LatLng 對象
      };
    }
    return null;
  }
}