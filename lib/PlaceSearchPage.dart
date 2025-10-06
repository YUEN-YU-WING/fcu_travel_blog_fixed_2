import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({super.key});

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final _places = FlutterGooglePlacesSdk('YOUR_GOOGLE_API_KEY');
  List<AutocompletePrediction> predictions = [];

  void _onSearchChanged(String query) async {
    if (query.isEmpty) return;
    final result = await _places.findAutocompletePredictions(query);
    setState(() {
      predictions = result.predictions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜尋地點')),
      body: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '輸入地點名稱',
            ),
            onChanged: _onSearchChanged,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                final p = predictions[index];
                return ListTile(
                  title: Text(p.fullText ?? ''),
                  onTap: () async {
                    final details = await _places.fetchPlace(
                      p.placeId,
                      fields: [PlaceField.Location],
                    );
                    final loc = details.place?.latLng;
                    if (loc != null) {
                      Navigator.pop(context, loc);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
