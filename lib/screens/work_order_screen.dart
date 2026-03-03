// lib/screens/work_order_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class WorkOrderScreen extends StatefulWidget {
  const WorkOrderScreen({super.key});
  @override
  State<WorkOrderScreen> createState() => _WorkOrderScreenState();
}

class _WorkOrderScreenState extends State<WorkOrderScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 상태 유지

  static const String WEBAPP_URL = AppConfig.webAppUrl;

  final Color stoneShadow = const Color(0xFF586B54);
  final Color hanjiIvory = const Color(0xFFFDFBF7);
  final Color yogurtTint = const Color(0xFFE7E2DE);

  bool isLoading = false;
  List<dynamic> pendingOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkOrders();
  }

  Future<void> _fetchWorkOrders() async {
    setState(() => isLoading = true);
    try {
      var res = await http.post(
          Uri.parse(WEBAPP_URL),
          headers: {'Content-Type': 'text/plain'},
          body: jsonEncode({"action": "getOrders"})
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode == 302 || res.statusCode == 303) {
        final redirectUrl = res.headers['location'] ?? res.headers['Location'];
        if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 45));
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["ok"] == true) {
          setState(() {
            // 상태가 '완료'가 아닌 대기중인 주문만 필터링해서 가져옴
            pendingOrders = data["orders"] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("작업 지시 목록 불러오기 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('목록을 불러오지 못했습니다. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: hanjiIvory,
      appBar: AppBar(
        title: const Text('작업 지시 (출고 대기)', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: hanjiIvory,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchWorkOrders,
            tooltip: '새로고침',
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingOrders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('현재 대기 중인 작업(주문)이 없습니다.', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: pendingOrders.length,
        itemBuilder: (context, index) {
          final order = pendingOrders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: yogurtTint, width: 2)),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: stoneShadow.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('주문번호: ${order["orderId"]}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stoneShadow)),
                      ),
                      Text((order["date"]?.toString().length ?? 0) > 10 ? order["date"].toString().substring(0, 10) : order["date"].toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const Divider(height: 24),
                  Text('🏢 납품처: ${order["client"]}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: Colors.black54),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${order["name"]} (${order["sku"]})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('📦 출고 지시 수량: ${order["qty"]}장', style: const TextStyle(fontSize: 15, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('지시 내용을 확인하셨다면 상단의 [출고 스캔] 탭으로 이동하여 제품을 스캔해주세요!'), duration: Duration(seconds: 3))
                      );
                    },
                    style: FilledButton.styleFrom(backgroundColor: stoneShadow, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('출고하러 가기 (안내)'),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}