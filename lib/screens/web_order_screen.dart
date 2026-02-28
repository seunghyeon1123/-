// lib/screens/web_order_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/product_catalog.dart';

class WebOrderScreen extends StatefulWidget {
  const WebOrderScreen({super.key});
  @override
  State<WebOrderScreen> createState() => _WebOrderScreenState();
}

class OrderItemRow {
  ProductItem? selectedProduct;
  double weightKg;
  int qty;
  double price;

  OrderItemRow({this.selectedProduct, this.weightKg = 3.0, this.qty = 1, this.price = 0});

  double get supplyPrice => price * qty;
  double get vat => supplyPrice * 0.1;
  double get total => supplyPrice + vat;
}

class _WebOrderScreenState extends State<WebOrderScreen> {
  static const String WEBAPP_URL = AppConfig.webAppUrl;

  final Color stoneShadow = const Color(0xFF586B54);
  final Color hanjiIvory = const Color(0xFFFDFBF7);

  bool isLoading = false;
  List<Map<String, dynamic>> customers = [];
  Map<String, dynamic>? selectedCustomer;

  final searchCtrl = TextEditingController();
  final parseCtrl = TextEditingController();

  // 고객 정보 수동 입력용
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  List<OrderItemRow> orderRows = [OrderItemRow()];

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> payload) async {
    var res = await http.post(Uri.parse(WEBAPP_URL), headers: {'Content-Type': 'text/plain'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 45));
    if (res.statusCode == 302 || res.statusCode == 303) {
      final redirectUrl = res.headers['location'] ?? res.headers['Location'];
      if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 45));
    }
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('HTTP Error: ${res.statusCode}');
  }

  Future<void> _fetchCustomers() async {
    setState(() => isLoading = true);
    try {
      final res = await _post({"action": "getCustomers"});
      if (res["ok"] == true) {
        setState(() {
          customers = List<Map<String, dynamic>>.from(res["customers"] ?? []);
        });
      }
    } catch (e) {
      debugPrint("고객 목록 불러오기 실패: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 🟢 스마트 문자열 파싱 (단순 키워드 매칭)
  void _parseText() {
    final text = parseCtrl.text;
    if (text.isEmpty) return;

    List<OrderItemRow> newRows = [];

    // 임시 파싱 로직: catalogItems의 품목명이 텍스트에 포함되어 있는지 검사
    for (var product in catalogItems) {
      if (text.contains(product.name)) {
        // 품목명 뒤에 나오는 숫자(장, 개 등)를 정규식으로 대략적 추출
        RegExp exp = RegExp('${product.name}.*?([0-9]+)[장|개|박스]');
        var match = exp.firstMatch(text);
        int parsedQty = 1;
        if (match != null && match.groupCount >= 1) {
          parsedQty = int.tryParse(match.group(1) ?? '1') ?? 1;
        }
        newRows.add(OrderItemRow(selectedProduct: product, qty: parsedQty));
      }
    }

    if (newRows.isNotEmpty) {
      setState(() => orderRows = newRows);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('문장 분석 완료! 명세표에 품목이 추가되었습니다.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('등록된 품목을 찾지 못했습니다. 수동으로 입력해주세요.')));
    }
  }

  Future<void> _submitOrder() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('고객명/상호명을 입력하세요.')));
      return;
    }

    final validRows = orderRows.where((r) => r.selectedProduct != null).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('최소 1개의 품목을 선택하세요.')));
      return;
    }

    setState(() => isLoading = true);
    try {
      List<Map<String, dynamic>> orders = validRows.map((r) => {
        "sku": r.selectedProduct!.sku,
        "name": r.selectedProduct!.name,
        "weightKg": r.weightKg,
        "qty": r.qty,
        "price": r.price,
        "supplyPrice": r.supplyPrice,
        "vat": r.vat,
        "totalPrice": r.total
      }).toList();

      final payload = {
        "action": "addOrders",
        "customerName": nameCtrl.text.trim(),
        "customerPhone": phoneCtrl.text.trim(),
        "customerAddress": addressCtrl.text.trim(),
        "orders": orders
      };

      final res = await _post(payload);
      if (res["ok"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('주문이 등록되었습니다. (주문번호: ${res["orderNo"]})')));
        setState(() {
          orderRows = [OrderItemRow()];
          parseCtrl.clear();
        });
      } else {
        throw Exception(res["error"]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('주문 등록 실패: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _selectCustomer(Map<String, dynamic> c) {
    setState(() {
      selectedCustomer = c;
      nameCtrl.text = c["name"] ?? "";
      phoneCtrl.text = c["phone"] ?? "";
      addressCtrl.text = c["address"] ?? "";
      searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustomers = searchCtrl.text.isEmpty
        ? <Map<String,dynamic>>[]
        : customers.where((c) => (c["name"] ?? "").toString().contains(searchCtrl.text) || (c["phone"] ?? "").toString().contains(searchCtrl.text)).toList();

    return Scaffold(
      backgroundColor: hanjiIvory,
      appBar: AppBar(
        title: const Text('주문서 입력 (거래명세표)'),
        backgroundColor: hanjiIvory,
        elevation: 0,
        foregroundColor: stoneShadow,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽 패널: 고객 정보 & 문자열 파싱
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('1. 고객 정보 입력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: stoneShadow)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      labelText: '기존 고객 검색 (이름 또는 연락처)',
                      prefixIcon: const Icon(Icons.search),
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState((){}),
                  ),
                  if (filteredCustomers.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), color: Colors.white),
                      child: ListView.builder(
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, i) {
                          final c = filteredCustomers[i];
                          return ListTile(
                            title: Text(c["name"]),
                            subtitle: Text(c["phone"]),
                            onTap: () => _selectCustomer(c),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '상호명/이름 *', filled: true, fillColor: Colors.white)),
                  const SizedBox(height: 8),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: '전화번호', filled: true, fillColor: Colors.white)),
                  const SizedBox(height: 8),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: '주소', filled: true, fillColor: Colors.white)),

                  const Divider(height: 40),

                  Text('2. 스마트 주문 입력 (선택)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: stoneShadow)),
                  const SizedBox(height: 8),
                  const Text('카톡이나 문자로 받은 내용을 그대로 붙여넣으세요.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: parseCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '예) 순지 대발 100장, 2절지 50장 내일 보내주세요.',
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _parseText,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('주문 분석하기'),
                    style: ElevatedButton.styleFrom(backgroundColor: stoneShadow, foregroundColor: Colors.white),
                  )
                ],
              ),
            ),
          ),

          // 오른쪽 패널: 거래명세표 폼
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('거래명세표 세부내역', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: stoneShadow)),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => orderRows.add(OrderItemRow())),
                        icon: const Icon(Icons.add), label: const Text('행 추가'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: stoneShadow),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: orderRows.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final row = orderRows[index];
                        return Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<ProductItem>(
                                decoration: const InputDecoration(labelText: '품목명/규격', filled: true, fillColor: Colors.white),
                                value: row.selectedProduct,
                                isExpanded: true,
                                items: catalogItems.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.sku})'))).toList(),
                                onChanged: (v) => setState(() => row.selectedProduct = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                initialValue: row.weightKg.toString(),
                                decoration: const InputDecoration(labelText: '무게(kg)', filled: true, fillColor: Colors.white),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setState(() => row.weightKg = double.tryParse(v) ?? 3.0),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                key: ValueKey('qty_${index}_${row.qty}'),
                                initialValue: row.qty.toString(),
                                decoration: const InputDecoration(labelText: '수량', filled: true, fillColor: Colors.white),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setState(() => row.qty = int.tryParse(v) ?? 1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                decoration: const InputDecoration(labelText: '단가(원)', filled: true, fillColor: Colors.white),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setState(() => row.price = double.tryParse(v) ?? 0),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.grey.shade100,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('공급가: ${row.supplyPrice.toInt()}'),
                                    Text('부가세: ${row.vat.toInt()}'),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => orderRows.removeAt(index)),
                            )
                          ],
                        );
                      },
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    color: stoneShadow.withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('총 합계 금액:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: stoneShadow)),
                        Text('${orderRows.fold(0.0, (sum, r) => sum + r.total).toInt()} 원', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: stoneShadow)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isLoading ? null : _submitOrder,
                    style: FilledButton.styleFrom(backgroundColor: stoneShadow, padding: const EdgeInsets.symmetric(vertical: 20)),
                    child: const Text('주문 등록 및 현장 작업 지시', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}