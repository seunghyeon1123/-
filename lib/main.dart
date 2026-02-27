// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/product_qr_create_screen.dart';
import 'screens/location_qr_create_screen.dart';
import 'screens/inbound_scan_screen.dart';
import 'screens/inventory_screen.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // ✅ 앱 전체 테마를 편안한 블루 톤으로 설정
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade600, // 차분한 블루
          primary: Colors.blue.shade700,
        ),
        useMaterial3: true,
      ),
      home: const HomeTabs(),
    );
  }
}

class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(icon: Icon(Icons.inventory_2_outlined), text: '생산 QR'),
      const Tab(icon: Icon(Icons.place_outlined), text: '위치 QR'),
      if (!kIsWeb) const Tab(icon: Icon(Icons.qr_code_scanner), text: '입고(스캔)'),
      const Tab(icon: Icon(Icons.list_alt), text: '재고조회'),
    ];

    final views = [
      const ProductQrCreateScreen(),
      const LocationQrCreateScreen(),
      if (!kIsWeb) const InboundScanScreen(),
      const InventoryScreen(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('재고관리 (MVP)', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            tabs: tabs,
            labelColor: Colors.blue.shade800, // 선택된 탭 텍스트 색상
            indicatorColor: Colors.blue.shade700, // 선택된 탭 밑줄 색상
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: views,
        ),
      ),
    );
  }
}