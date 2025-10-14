import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcu_travel_blog_fixed_2/image_recognition.dart';

void main() {
  testWidgets('Landmark detection page loads correctly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LandmarkTestPage()));
    expect(find.text('地標辨識'), findsOneWidget);
    expect(find.text('選擇照片'), findsOneWidget);
    expect(find.text('尚未選擇圖片'), findsOneWidget);
  });

  testWidgets('Initial state shows correct UI elements', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LandmarkTestPage()));
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('尚未選擇圖片'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}