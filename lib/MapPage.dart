import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  LatLng? selectedLocation;

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 14),
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
      appBar: AppBar(title: const Text('選擇地點')),
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
            Navigator.pushNamed(context, '/newPost', arguments: selectedLocation);
          }
        },
        child: const Icon(Icons.note_add),
      ),
    );
  }
}
