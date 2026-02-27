import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'screens/product_qr_create_screen.dart';
import 'screens/location_qr_create_screen.dart';
import 'screens/inbound_scan_screen.dart';
import 'screens/outbound_scan_screen.dart';
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade600,
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
      if (!kIsWeb) const Tab(icon: Icon(Icons.login), text: '입고(스캔)'),
      if (!kIsWeb) const Tab(icon: Icon(Icons.logout), text: '출고(스캔)'),
      const Tab(icon: Icon(Icons.list_alt), text: '재고조회'),
    ];

    final views = [
      const ProductQrCreateScreen(),
      const LocationQrCreateScreen(),
      if (!kIsWeb) const InboundScanScreen(),
      if (!kIsWeb) const OutboundScanScreen(),
      const InventoryScreen(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('재고관리 (MVP)', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: TabBar(
            tabs: tabs,
            labelColor: Colors.blue.shade800,
            indicatorColor: Colors.blue.shade700,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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