import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '個人資料',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blueGrey[300],
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('姓名：王小明', style: TextStyle(fontSize: 20)),
                  SizedBox(height: 8),
                  Text('Email：test@example.com', style: TextStyle(fontSize: 16)),
                  // 加入更多個人資料欄位
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}