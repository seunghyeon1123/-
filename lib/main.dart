// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'screens/product_qr_create_screen.dart';
import 'screens/location_qr_create_screen.dart';
import 'screens/inbound_scan_screen.dart';
import 'screens/outbound_scan_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/web_order_screen.dart';
import 'screens/work_order_screen.dart';
import 'screens/store_pos_screen.dart';
import 'screens/login_screen.dart'; // 🟢 로그인 화면 임포트
import 'services/auth_service.dart'; // 🟢 로그인 상태 관리 임포트

void main() async {
  // 🟢 앱 시작 전에 로그인 기록이 있는지 확인합니다.
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.loadSavedAuth();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '안동한지 WMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF586B54)),
        useMaterial3: true,
        fontFamilyFallback: const ['Apple SD Gothic Neo', 'Malgun Gothic', 'sans-serif'],
      ),
      // 🟢 로그인되어 있으면 MainScreen, 아니면 LoginScreen 띄우기
      home: AuthService.isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {

  // 🟢 로그아웃 함수
  void _doLogout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 현재 로그인한 사람의 권한이 '관리자'인지 확인
    bool isAdmin = AuthService.userRole == '관리자';

    final List<Tab> tabs = [];
    final List<Widget> tabViews = [];

    // 1. 주문 현황 (관리자만 보임)
    if (isAdmin) {
      tabs.add(const Tab(icon: Icon(Icons.assignment), text: '주문현황'));
      tabViews.add(const WorkOrderScreen());
    }

    // 2. 생산/위치 QR (모두 보임)
    tabs.add(const Tab(icon: Icon(Icons.qr_code_2), text: '생산 QR'));
    tabViews.add(const ProductQrCreateScreen());
    tabs.add(const Tab(icon: Icon(Icons.location_on), text: '위치 QR'));
    tabViews.add(const LocationQrCreateScreen());

    // 3. 스캐너 및 POS (모바일에서만 보임)
    if (!kIsWeb) {
      tabs.add(const Tab(icon: Icon(Icons.login), text: '입고(스캔)'));
      tabViews.add(const InboundScanScreen());
      tabs.add(const Tab(icon: Icon(Icons.logout), text: '출고(스캔)'));
      tabViews.add(const OutboundScanScreen());
      tabs.add(const Tab(icon: Icon(Icons.point_of_sale), text: '매장 POS'));
      tabViews.add(const StorePosScreen());
    }

    // 4. 재고 조회 (모두 보임)
    tabs.add(const Tab(icon: Icon(Icons.inventory_2_outlined), text: '재고조회'));
    tabViews.add(const InventoryScreen());

    // 5. 주문 입력(웹) (관리자만 보임)
    if (isAdmin) {
      tabs.add(const Tab(icon: Icon(Icons.shopping_cart_checkout), text: '주문 입력(웹)'));
      tabViews.add(const WebOrderScreen());
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          // 🟢 상단에 로그인한 사람 이름과 직급 표시
          title: Text('${AuthService.userName}님 (${AuthService.userRole})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          elevation: 2,
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _doLogout, tooltip: '로그아웃'),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: tabViews,
        ),
      ),
    );
  }
}