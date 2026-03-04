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
  bool get wantKeepAlive => true;

  static const String WEBAPP_URL = AppConfig.webAppUrl;

  final Color stoneShadow = const Color(0xFF586B54);
  final Color hanjiIvory = const Color(0xFFFDFBF7);
  final Color yogurtTint = const Color(0xFFE7E2DE);

  bool isLoading = false;
  List<dynamic> pendingOrders = [];
  List<dynamic> currentInventory = []; // 재고 데이터 저장용

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
            pendingOrders = data["orders"] ?? [];
            currentInventory = data["inventory"] ?? []; // 서버에서 재고 데이터도 같이 받아옴
          });
        }
      }
    } catch (e) {
      debugPrint("주문 현황 목록 불러오기 실패: $e");
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
        title: const Text('주문 현황 (출고 대기)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: hanjiIvory,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
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
            Text('현재 대기 중인 주문이 없습니다.', style: TextStyle(fontSize: 20, color: Colors.grey.shade600)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: pendingOrders.length,
        itemBuilder: (context, index) {
          final order = pendingOrders[index];

          // 해당 품목의 현재 창고 재고 및 위치 찾기
          final itemInv = currentInventory.where((inv) => inv["sku"] == order["sku"]).toList();
          final int stockQty = itemInv.fold(0, (sum, item) => sum + (item["qty"] as num).toInt());
          final List<String> locations = itemInv.map((e) => e["locationCode"].toString()).toSet().toList();
          final String locationText = locations.isEmpty ? "위치 미지정(입고 전)" : locations.join(", ");

          final int orderQty = (order["qty"] as num).toInt();
          final bool isOutOfStock = stockQty < orderQty; // 주문량보다 재고가 적은지 확인

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: yogurtTint, width: 2)),
            elevation: 2,
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: stoneShadow.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text('주문번호: ${order["orderId"]}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: stoneShadow)),
                      ),
                      Text((order["date"]?.toString().length ?? 0) > 10 ? order["date"].toString().substring(0, 10) : order["date"].toString(), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                  const Divider(height: 24, thickness: 1.5),
                  Text('🏢 납품처: ${order["client"]}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${order["name"]} (${order["sku"]})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('📦 지시 수량: $orderQty장', style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            Text('현재 재고: $stockQty장', style: TextStyle(fontSize: 16, color: isOutOfStock ? Colors.red : Colors.black87, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('📍 보관 위치: $locationText', style: const TextStyle(fontSize: 16, color: Colors.black54)),

                        if (isOutOfStock)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('재고가 부족합니다! (생산 또는 입고 필요)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      // 탭 5번째(인덱스 4)인 '출고(스캔)' 탭으로 즉시 화면 이동시킴
                      DefaultTabController.of(context).animateTo(4);
                    },
                    style: FilledButton.styleFrom(backgroundColor: stoneShadow, padding: const EdgeInsets.symmetric(vertical: 16)),
                    icon: const Icon(Icons.qr_code_scanner, size: 24),
                    label: const Text('출고 화면으로 바로 이동', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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