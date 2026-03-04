// lib/screens/work_order_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🟢 PC/모바일 구분용
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
  List<dynamic> currentInventory = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkOrders();
  }
// 🟢 주문 취소 (서버 전송)
  Future<void> _cancelOrder(String orderId) async {
    setState(() => isLoading = true);
    try {
      final res = await http.post(
          Uri.parse(WEBAPP_URL),
          headers: {'Content-Type': 'text/plain'},
          body: jsonEncode({"action": "cancelOrder", "orderId": orderId})
      );
      if (jsonDecode(res.body)["ok"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주문이 성공적으로 취소되었습니다.', style: TextStyle(fontSize: 18))));
        _fetchWorkOrders(); // 화면 새로고침
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('취소 실패. 다시 시도해주세요.', style: TextStyle(fontSize: 18))));
      setState(() => isLoading = false);
    }
  }

  // 🟢 주문 수량 수정 팝업 띄우기 및 서버 전송
  void _showEditDialog(dynamic order) {
    TextEditingController qtyCtrl = TextEditingController(text: order["qty"].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문 수량 수정', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('품목: ${order["name"]}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '변경할 수량', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기', style: TextStyle(fontSize: 16))),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => isLoading = true);
              try {
                final res = await http.post(
                    Uri.parse(WEBAPP_URL),
                    headers: {'Content-Type': 'text/plain'},
                    body: jsonEncode({"action": "editOrderQty", "orderId": order["orderId"], "newQty": qtyCtrl.text})
                );
                if (jsonDecode(res.body)["ok"] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수량이 성공적으로 변경되었습니다.', style: TextStyle(fontSize: 18))));
                  _fetchWorkOrders();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정 실패', style: TextStyle(fontSize: 18))));
                setState(() => isLoading = false);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: stoneShadow),
            child: const Text('수정 완료', style: TextStyle(fontSize: 16)),
          )
        ],
      ),
    );
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
            currentInventory = data["inventory"] ?? [];
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
        title: Text(kIsWeb ? '주문 현황 총괄 (관리자용)' : '주문 현황 (출고 대기)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
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
      // 🟢 여기서 기기 환경에 따라 화면을 완벽하게 분리합니다.
          : kIsWeb
          ? _buildWebAdminView()
          : _buildMobileWorkerView(),
    );
  }

// 💻 [관리자용 PC 웹 화면] - 전체 현황 파악 및 통제용 (표 형태)
  Widget _buildWebAdminView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(stoneShadow.withOpacity(0.1)),
            columns: const [
              DataColumn(label: Text('주문일자', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('주문번호', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('납품처', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('품목명', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('지시수량', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('현재고', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('관리', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: pendingOrders.map((order) {
              final itemInv = currentInventory.where((inv) => inv["sku"] == order["sku"]).toList();
              final int stockQty = itemInv.fold(0, (sum, item) => sum + (item["qty"] as num).toInt());
              final int orderQty = (order["qty"] as num).toInt();
              final bool isOutOfStock = stockQty < orderQty;

              return DataRow(cells: [
                DataCell(Text((order["date"]?.toString().length ?? 0) > 10 ? order["date"].toString().substring(0, 10) : order["date"].toString())),
                DataCell(Text('${order["orderId"]}')),
                DataCell(Text('${order["client"]}')),
                DataCell(Text('${order["name"]} (${order["sku"]})')),
                DataCell(Text('$orderQty장', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                DataCell(Text('$stockQty장', style: TextStyle(color: isOutOfStock ? Colors.red : Colors.black, fontWeight: FontWeight.bold))),

                // 🟢 가짜 버튼을 지우고, 기능이 연결된 진짜 버튼으로 교체된 부분입니다!
                DataCell(
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => _showEditDialog(order),
                          child: const Text('수량 수정', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            // 취소 전 안전하게 한 번 더 물어보는 확인창
                            showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('주문 취소', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  content: const Text('이 주문을 정말 취소(삭제)하시겠습니까?', style: TextStyle(fontSize: 18)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('아니오')),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _cancelOrder(order["orderId"]);
                                      },
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('예, 취소합니다'),
                                    )
                                  ],
                                )
                            );
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('취소', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // 📱 [현장 직원용 모바일 앱 화면] - 작업 집중 및 위치 확인용 (카드 형태)
  Widget _buildMobileWorkerView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pendingOrders.length,
      itemBuilder: (context, index) {
        final order = pendingOrders[index];

        final itemInv = currentInventory.where((inv) => inv["sku"] == order["sku"]).toList();
        final int stockQty = itemInv.fold(0, (sum, item) => sum + (item["qty"] as num).toInt());
        final List<String> locations = itemInv.map((e) => e["locationCode"].toString()).toSet().toList();
        final String locationText = locations.isEmpty ? "위치 미지정(입고 전)" : locations.join(", ");

        final int orderQty = (order["qty"] as num).toInt();
        final bool isOutOfStock = stockQty < orderQty;

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
                              Text('재고가 부족합니다! (관리자 확인 요망)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    // 출고 탭으로 이동
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
    );
  }
}