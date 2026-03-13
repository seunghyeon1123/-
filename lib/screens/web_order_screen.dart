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

class _WebOrderScreenState extends State<WebOrderScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  static const String WEBAPP_URL = AppConfig.webAppUrl;

  final Color stoneShadow = const Color(0xFF586B54);
  final Color hanjiIvory = const Color(0xFFFDFBF7);

  bool isLoading = false;
  List<Map<String, dynamic>> customers = [];
  List<dynamic> currentInventory = []; // 재고 확인용
  Map<String, dynamic>? selectedCustomer;

  final searchCtrl = TextEditingController();
  final parseCtrl = TextEditingController();

  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  List<OrderItemRow> orderRows = [OrderItemRow()];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
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

// 🟢 고객 목록과 재고를 한 번에 불러옴 (초고속 버전)
  Future<void> _fetchInitialData() async {
    setState(() => isLoading = true);
    try {
      // 🚀 두 번 통신하던 걸 'getFastScreenData' 1번으로 단축!
      final res = await _post({"action": "getFastScreenData"});

      if (res["ok"] == true) {
        setState(() {
          // 서버가 한방에 보내준 고객 목록과 재고 데이터를 각각 나눠 담음
          customers = List<Map<String, dynamic>>.from(res["customers"] ?? []);
          currentInventory = res["items"] ?? [];
        });
      }
    } catch (e) {
      debugPrint("초기 데이터 불러오기 실패: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

// 🟢 최신 2.0-flash 모델 적용 코드
// 🟢 100% 무료 자체 내장 파서 (구글 AI 서버 접속 안 함)
  void _parseText() {
    final text = parseCtrl.text;
    if (text.isEmpty) return;

    // 1. 전화번호 추출 (010-XXXX-XXXX 패턴)
    final phoneRegExp = RegExp(r'01[016789][- .]?\d{3,4}[- .]?\d{4}');
    final phoneMatch = phoneRegExp.firstMatch(text);
    if (phoneMatch != null) {
      phoneCtrl.text = phoneMatch.group(0)!;
    }

    // 2. 주소 대략적 추출 (시/도, 구/군, 동/로/길 패턴)
    final addressRegExp = RegExp(r'([가-힣]+(시|도)\s+[가-힣]+(구|군|시)\s+[가-힣]+(동|면|리|읍|길|로)\s*\d*(-\d+)?)');
    final addressMatch = addressRegExp.firstMatch(text);
    if (addressMatch != null) {
      addressCtrl.text = addressMatch.group(0)!;
    }

    // 3. 상호명 추출 (문맥상 '~~로' 앞의 단어 추정)
    final nameRegExp = RegExp(r'([가-힣a-zA-Z0-9]+)(으)?로\s+(보내|배송|출고|부탁)');
    final nameMatch = nameRegExp.firstMatch(text);
    if (nameMatch != null) {
      nameCtrl.text = nameMatch.group(1)!;
    }

    // 4. 품목 및 수량 추출
    List<OrderItemRow> newRows = [];
    String pureText = text.replaceAll(' ', '');

    for (var product in catalogItems) {
      String pureName = product.name.replaceAll(' ', '');

      if (pureText.contains(pureName) || text.contains(product.name)) {
        // 품목명 뒤에 나오는 숫자 최대 4자리 추출
        RegExp exp = RegExp('${product.name}.*?([0-9]{1,4})\\s*(장|개|박스|롤|권|연)');
        var match = exp.firstMatch(text);

        int parsedQty = 1;
        if (match != null && match.groupCount >= 1) {
          parsedQty = int.tryParse(match.group(1) ?? '1') ?? 1;
        }
        newRows.add(OrderItemRow(selectedProduct: product, qty: parsedQty));
      }
    }

    setState(() {
      if (newRows.isNotEmpty) orderRows = newRows;
    });

    if (newRows.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ 내장 분석 완료! 데이터가 즉시 입력되었습니다.', style: TextStyle(fontSize: 18))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ 품목을 자동으로 찾지 못했습니다. 수동으로 입력해주세요.', style: TextStyle(fontSize: 18))));
    }
  }

// 🟢 1. 새롭게 추가된 기능: 단골(주소록) 고객 정보만 시트에 따로 저장/수정
  Future<void> _saveCustomer() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상호명/이름을 먼저 입력해주세요.', style: TextStyle(fontSize: 18))));
      return;
    }
    setState(() => isLoading = true);
    try {
      final res = await _post({
        "action": "saveCustomer",
        "customerName": nameCtrl.text.trim(),
        "phone": phoneCtrl.text.trim(),
        "address": addressCtrl.text.trim()
      });
      if (res["ok"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res["message"], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))));
        _fetchInitialData(); // 저장 후 고객 검색 목록을 실시간으로 새로고침
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('고객 저장 실패: $e', style: const TextStyle(fontSize: 18))));
    } finally {
      setState(() => isLoading = false);
    }
  }


  // 🔵 2. 기존의 완벽한 기능: 거래명세표 주문 등록 및 현장(창고)으로 작업 지시 전송
  Future<void> _submitOrder() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('고객명/상호명을 입력하세요.', style: TextStyle(fontSize: 18))));
      return;
    }

    final validRows = orderRows.where((r) => r.selectedProduct != null).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('최소 1개의 품목을 선택하세요.', style: TextStyle(fontSize: 18))));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주문이 정상적으로 등록되었습니다.', style: TextStyle(fontSize: 18))));
        setState(() {
          orderRows = [OrderItemRow()];
          parseCtrl.clear();
        });
      } else {
        throw Exception(res["error"]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('주문 등록 실패: $e', style: const TextStyle(fontSize: 18))));
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

  // 선택된 품목의 현재 총 재고를 계산하는 함수
  int _getStockForProduct(String? sku) {
    if (sku == null) return 0;
    final itemInv = currentInventory.where((inv) => inv["sku"] == sku).toList();
    return itemInv.fold(0, (sum, item) => sum + (item["qty"] as num).toInt());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final filteredCustomers = searchCtrl.text.isEmpty
        ? <Map<String,dynamic>>[]
        : customers.where((c) => (c["name"] ?? "").toString().contains(searchCtrl.text) || (c["phone"] ?? "").toString().contains(searchCtrl.text)).toList();

    return Scaffold(
      backgroundColor: hanjiIvory,
      appBar: AppBar(
        title: const Text('주문서 입력 (거래명세표)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: hanjiIvory,
        elevation: 0,
        foregroundColor: stoneShadow,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('1. 고객 정보 입력', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: stoneShadow)),
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
                            title: Text(c["name"], style: const TextStyle(fontSize: 18)),
                            subtitle: Text(c["phone"], style: const TextStyle(fontSize: 16)),
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

                  // 🟢 여기에 버튼 추가! (어르신들도 누르기 편하게 큼직하게)
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saveCustomer,
                    icon: const Icon(Icons.save_alt, size: 24),
                    label: const Text('단골(주소록)에 저장 / 주소 수정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: stoneShadow, width: 2),
                      foregroundColor: stoneShadow,
                    ),
                  ),

                  const Divider(height: 40),

                  Text('2. 스마트 주문 입력 (AI 자동 완성)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: stoneShadow)),
                  const SizedBox(height: 8),
                  const Text('카톡이나 문자로 받은 내용을 그대로 붙여넣으세요.', style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                    icon: const Icon(Icons.auto_awesome, size: 24),
                    label: const Text('AI 주문 자동 분석하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: stoneShadow, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  )
                ],
              ),
            ),
          ),

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
                      Text('거래명세표 세부내역', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: stoneShadow)),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => orderRows.add(OrderItemRow())),
                        icon: const Icon(Icons.add), label: const Text('행 추가', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: stoneShadow, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
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
                        final currentStock = _getStockForProduct(row.selectedProduct?.sku);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start, // 위쪽 정렬
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
                            // 🟢 비고 (재고 상태 표시) 칸 추가
                            Expanded(
                              flex: 1,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: row.selectedProduct == null ? Colors.grey.shade100 : (currentStock < row.qty ? Colors.red.shade50 : Colors.green.shade50),
                                    border: Border.all(color: Colors.grey.shade300)
                                ),
                                child: Text(
                                  row.selectedProduct == null ? '품목 선택' :
                                  (currentStock < row.qty ? '⚠️ 재고부족\n(보유: $currentStock)' : '재고 충분\n(보유: $currentStock)'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: row.selectedProduct == null ? Colors.grey : (currentStock < row.qty ? Colors.red : Colors.green.shade700)
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 30),
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
                        Text('총 합계 금액:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: stoneShadow)),
                        Text('${orderRows.fold(0.0, (sum, r) => sum + r.total).toInt()} 원', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: stoneShadow)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isLoading ? null : _submitOrder,
                    style: FilledButton.styleFrom(backgroundColor: stoneShadow, padding: const EdgeInsets.symmetric(vertical: 24)),
                    child: const Text('주문 등록 (주문 현황으로 전송)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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