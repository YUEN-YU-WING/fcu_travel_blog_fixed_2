// lib/MapPage.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  /// 在後台右側嵌入時請設為 true，如：const MapPage(embedded: true)
  /// 獨立開頁（一般 push）保持預設 false 會顯示系統返回鍵
  final bool embedded;

  const MapPage({super.key, this.embedded = false});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  LatLng? selectedLocation;

  Future<void> _getCurrentLocation() async {
    // 記得先在外層處理定位權限（此處僅示範）
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        14,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇地點'),
        // 核心：在後台嵌入時不顯示返回鍵；獨立開頁才顯示
        automaticallyImplyLeading: !widget.embedded,
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(25.0340, 121.5645), // 台北預設
          zoom: 14,
        ),
        onMapCreated: (controller) => mapController = controller,
        onTap: (position) {
          setState(() {
            selectedLocation = position;
          });
        },
        markers: {
          if (selectedLocation != null)
            Marker(
              markerId: const MarkerId('selected'),
              position: selectedLocation!,
            ),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (selectedLocation != null) {
            // 保留你原本的路由行為
            Navigator.pushNamed(context, '/newPost', arguments: selectedLocation);
          }
        },
        child: const Icon(Icons.note_add),
      ),
    );
  }
}