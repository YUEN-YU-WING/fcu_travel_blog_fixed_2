import 'package:flutter/material.dart';
import 'travelogue_map_page.dart'; // 舊的 MapPickerPage 更名為此
import 'pages/travel_route_collection_page.dart'; // 新增的路徑地圖頁面
import 'pages/travel_route_map_page.dart';

class MapSelectionPage extends StatelessWidget {
  final bool embedded;

  const MapSelectionPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇地圖類型'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text('查看遊記地點地圖'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TravelogueMapPage()),
                );
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.alt_route),
              label: const Text('查看遊記路徑地圖'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TravelRouteCollectionPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}