import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class StorePosScreen extends StatefulWidget {
  const StorePosScreen({super.key});
  @override
  State<StorePosScreen> createState() => _StorePosScreenState();
}

class _StorePosScreenState extends State<StorePosScreen> {
  final Color stoneShadow = const Color(0xFF586B54);
  Map<String, int> priceList = {}; // SKU별 단가 저장
  List<Map<String, dynamic>> cart = []; // 장바구니
  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchPriceList();
  }

  // 시트에서 단가표 싹 긁어오기
  Future<void> _fetchPriceList() async {
    try {
      final res = await http.post(Uri.parse(AppConfig.webAppUrl),
          body: jsonEncode({"action": "getUnitPriceList"}));
      final data = jsonDecode(res.body);
      if (data['ok'] == true) {
        setState(() {
          priceList = Map<String, int>.from(data['prices']);
          isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('단가표 로딩 실패: $e')));
    }
  }

  // 바코드 스캔 시 장바구니 담기
  void _addToCart(String rawValue) {
    Map<String, dynamic> data;
    try {
      if (rawValue.startsWith('https://')) {
        data = jsonDecode(utf8.decode(base64Decode(rawValue.split('app_data=')[1])));
      } else {
        data = jsonDecode(rawValue);
      }
    } catch (e) { return; }

    String sku = data['sku'];
    String name = data['name'];
    int unitPrice = priceList[sku] ?? 0;

    setState(() {
      // 이미 장바구니에 있으면 수량만 +1
      int existingIdx = cart.indexWhere((item) => item['sku'] == sku);
      if (existingIdx != -1) {
        cart[existingIdx]['qty'] += 1;
        cart[existingIdx]['totalPrice'] = cart[existingIdx]['qty'] * unitPrice;
      } else {
        cart.add({
          "sku": sku,
          "name": name,
          "qty": 1,
          "unitPrice": unitPrice,
          "totalPrice": unitPrice
        });
      }
    });
  }

  // 판매 확정 (서버 전송)
  Future<void> _checkout() async {
    if (cart.isEmpty) return;
    setState(() => isSubmitting = true);

    try {
      final res = await http.post(Uri.parse(AppConfig.webAppUrl),
          body: jsonEncode({
            "action": "processSale",
            "time": DateTime.now().toIso8601String(),
            "cart": cart
          }));
      final data = jsonDecode(res.body);
      if (data['ok'] == true) {
        _showSuccessDialog(data['saleId']);
        setState(() => cart.clear());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('결제 실패: $e')));
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showSuccessDialog(String id) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('✅ 판매 완료'),
      content: Text('전표번호: $id\n재고가 자동으로 차감되었습니다.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    int totalAmount = cart.fold(0, (sum, item) => sum + (item['totalPrice'] as int));

    return Scaffold(
      appBar: AppBar(title: const Text('매장 포스기 (낱장 판매)'), backgroundColor: Colors.white),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 1. 스캐너 영역 (상단 절반)
          Expanded(
            flex: 2,
            child: MobileScanner(
              onDetect: (capture) {
                final code = capture.barcodes.first.rawValue;
                if (code != null) _addToCart(code);
              },
            ),
          ),
          // 2. 장바구니 영역 (하단 절반)
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  const Text('🛒 판매 목록', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        return ListTile(
                          title: Text(item['name']),
                          subtitle: Text('단가: ${item['unitPrice']}원'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () {
                                setState(() {
                                  if (item['qty'] > 1) {
                                    item['qty']--;
                                    item['totalPrice'] = item['qty'] * item['unitPrice'];
                                  } else { cart.removeAt(index); }
                                });
                              }),
                              Text('${item['qty']}장', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {
                                setState(() {
                                  item['qty']++;
                                  item['totalPrice'] = item['qty'] * item['unitPrice'];
                                });
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(thickness: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('총 결제 금액', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${totalAmount.toLocaleString()}원', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: stoneShadow)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton(
                      onPressed: isSubmitting ? null : _checkout,
                      style: FilledButton.styleFrom(backgroundColor: stoneShadow),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('결제 및 재고 차감', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 숫자 콤마 표시를 위한 확장 함수
extension IntExtension on int {
  String toLocaleString() {
    return toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}