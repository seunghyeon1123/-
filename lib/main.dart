import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ 웹(Web) 환경인지 감지하는 패키지 추가

// 화면 임포트
import 'screens/product_qr_create_screen.dart';
import 'screens/location_qr_create_screen.dart';
import 'screens/inbound_scan_screen.dart';
import 'screens/outbound_scan_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/web_order_screen.dart';
import 'screens/work_order_screen.dart'; // 🟢 신규: 작업 지시 화면

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '재고관리 (MVP)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF586B54)), // 스톤 섀도우 톤
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {

    // ✅ 1. 탭 메뉴 리스트 구성 (현장 작업자용 '작업지시' 탭 추가)
    final List<Tab> tabs = [
      if (!kIsWeb) const Tab(icon: Icon(Icons.assignment), text: '주문현황'), // 🟢 모바일 첫 화면으로 배치!
      const Tab(icon: Icon(Icons.qr_code_2), text: '생산 QR'),
      const Tab(icon: Icon(Icons.location_on), text: '위치 QR'),
      if (!kIsWeb) const Tab(icon: Icon(Icons.login), text: '입고(스캔)'),
      if (!kIsWeb) const Tab(icon: Icon(Icons.logout), text: '출고(스캔)'),
      const Tab(icon: Icon(Icons.inventory_2_outlined), text: '재고조회'),
      const Tab(icon: Icon(Icons.shopping_cart_checkout), text: '주문 입력(웹)'),
    ];

    // ✅ 2. 실제 화면 리스트 구성
    final List<Widget> tabViews = [
      if (!kIsWeb) const WorkOrderScreen(), // 🟢 모바일 첫 화면 연결
      const ProductQrCreateScreen(),
      const LocationQrCreateScreen(),
      if (!kIsWeb) const InboundScanScreen(),
      if (!kIsWeb) const OutboundScanScreen(),
      const InventoryScreen(),
      const WebOrderScreen(),
    ];

    return DefaultTabController(
      length: tabs.length, // 탭 개수를 상황에 맞게 자동 조절
      child: Scaffold(
        appBar: AppBar(
          title: const Text('안동한지 WMS', style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 2,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            tabs: tabs, // 구성된 탭 리스트 적용
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), // 스캐너 화면에서 스와이프 오작동 방지
          children: tabViews, // 구성된 화면 리스트 적용
        ),
      ),
    );
  }
}