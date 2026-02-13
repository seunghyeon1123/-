import 'package:flutter/material.dart';
import 'screens/product_qr_create_screen.dart';
import 'screens/location_qr_create_screen.dart';
import 'screens/inbound_scan_screen.dart'; // ✅ 추가

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeTabs(),
    );
  }
}

class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // ✅ 2 → 3
      child: Scaffold(
        appBar: AppBar(
          title: const Text('재고관리 (MVP)'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: '생산 QR'),
              Tab(icon: Icon(Icons.place_outlined), text: '위치 QR'),
              Tab(icon: Icon(Icons.qr_code_scanner), text: '입고(스캔)'), // ✅ 추가
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ProductQrCreateScreen(),
            LocationQrCreateScreen(),
            InboundScanScreen(), // ✅ 추가
          ],
        ),
      ),
    );
  }
}
