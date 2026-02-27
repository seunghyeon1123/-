// lib/screens/outbound_scan_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class OutboundScanScreen extends StatefulWidget {
  const OutboundScanScreen({super.key});
  @override
  State<OutboundScanScreen> createState() => _OutboundScanScreenState();
}

class _OutboundScanScreenState extends State<OutboundScanScreen> {
  static const String WEBAPP_URL = AppConfig.webAppUrl;
  late MobileScannerController controller;

  Map<String, dynamic>? product;
  Map<String, dynamic>? location;
  bool scanningProduct = true;
  bool isProcessingScan = false;
  bool isSubmitting = false;

  String statusText = '대기중 (제품 QR을 스캔하세요)';
  Color statusColor = Colors.grey;
  String? lastScannedRaw;

  final normalQtyCtrl = TextEditingController();
  final bGradeQtyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(autoStart: false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) controller.start();
    });
  }

  @override
  void dispose() {
    controller.stop();
    controller.dispose();
    normalQtyCtrl.dispose();
    bGradeQtyCtrl.dispose();
    super.dispose();
  }

  void _setStatus(String text, Color color) {
    if (!mounted) return;
    setState(() {
      statusText = text;
      statusColor = color;
    });
  }

  void _showBottomMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4))
    );
  }

  void reset() {
    setState(() {
      product = null;
      location = null;
      scanningProduct = true;
      isProcessingScan = false;
      isSubmitting = false;
      lastScannedRaw = null;
      normalQtyCtrl.clear();
      bGradeQtyCtrl.clear();
      statusText = '대기중 (제품 QR을 스캔하세요)';
      statusColor = Colors.grey;
    });
    controller.start();
  }

  Future<Map<String, dynamic>> _postJsonWithRedirect(Map<String, dynamic> payload) async {
    try {
      var res = await http.post(
          Uri.parse(WEBAPP_URL),
          headers: {'Content-Type': 'text/plain'},
          body: jsonEncode(payload)
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode == 302 || res.statusCode == 303) {
        final redirectUrl = res.headers['location'] ?? res.headers['Location'];
        if (redirectUrl != null) {
          res = await http.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 45));
        }
      }
      if (res.statusCode == 200) {
        try {
          return jsonDecode(res.body) as Map<String, dynamic>;
        } catch (e) {
          throw Exception('구글 응답 파싱 실패: ${res.body}');
        }
      }
      throw Exception('HTTP 상태 코드 에러: ${res.statusCode}');
    } on TimeoutException {
      throw Exception('응답 시간 초과');
    } catch (e) {
      throw Exception('통신 오류: $e');
    }
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (isSubmitting || isProcessingScan) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw == lastScannedRaw) return;
    lastScannedRaw = raw;

    Map<String, dynamic> data;
    try {
      // ✅ 스마트 QR & 일반 QR 동시 지원 로직
      if (raw.startsWith('https://andonghanji.com/board/index.php?app_data=')) {
        final base64String = raw.split('app_data=')[1];
        final decodedJsonString = utf8.decode(base64Decode(base64String));
        data = jsonDecode(decodedJsonString) as Map<String, dynamic>;
      } else {
        data = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {
      _setStatus('유효하지 않은 QR입니다.', Colors.redAccent);
      return;
    }

    setState(() => isProcessingScan = true);
    final type = (data['type'] ?? '').toString();

    if (scanningProduct) {
      if (type != 'product_pack') { _setStatus('위치 QR입니다. 제품 QR을 스캔하세요.', Colors.orange); setState(() => isProcessingScan = false); return; }
      setState(() { product = data; scanningProduct = false; isProcessingScan = false; });
      _setStatus('제품 인식 완료 → 위치 QR 스캔 요망', Colors.blue); _showBottomMessage('✔️ 제품 스캔 완료. 가져올 위치의 QR을 스캔하세요.');
      return;
    }

    if (type != 'location') { _setStatus('제품 QR입니다. 위치 QR을 스캔하세요.', Colors.orange); setState(() => isProcessingScan = false); return; }
    setState(() { location = data; isProcessingScan = false; });
    _setStatus('위치 인식 완료 → 수량을 입력하세요', Colors.green); _showBottomMessage('✔️ 위치 스캔 완료. 출고 및 불량 수량을 입력해주세요.');
    controller.stop();
  }

  Future<void> _confirmOutbound() async {
    final p = product;
    final l = location;
    if (p == null || l == null) return;

    final int normalQty = int.tryParse(normalQtyCtrl.text) ?? 0;
    final int bGradeQty = int.tryParse(bGradeQtyCtrl.text) ?? 0;

    if (normalQty == 0 && bGradeQty == 0) {
      _showBottomMessage('⚠️ 출고 또는 불량 수량을 최소 1개 이상 입력하세요.');
      return;
    }

    setState(() => isSubmitting = true);
    _setStatus('출고 정보 업데이트 중...', Colors.orange);

    try {
      final payload = {
        "time": DateTime.now().toIso8601String(),
        "type": "outbound",
        "sku": p["sku"],
        "name": p["name"],
        "locationCode": l["locationCode"],
        "warehouse": l["warehouse"],
        "normalQty": normalQty,
        "bGradeQty": bGradeQty
      };
      final resp = await _postJsonWithRedirect(payload);
      if (resp["ok"] == true) {
        _setStatus('출고 처리 완료', Colors.green);
        _showBottomMessage('✅ 정상적으로 재고가 차감되었습니다.');
        reset();
      } else {
        throw Exception(resp["error"]);
      }
    } catch (e) {
      _setStatus('오류 발생', Colors.redAccent);
      _showBottomMessage('❌ 상세 오류: $e');
      setState(() => isSubmitting = false);
      controller.start();
    }
  }

  Widget _buildScannerBox() {
    return Container(
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(12),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: MobileScanner(controller: controller, onDetect: onDetect)
        )
    );
  }

  Widget _buildInfoPanel() {
    final p = product;
    final l = location;
    final canConfirm = (p != null && l != null && !isSubmitting);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1), // 최신 문법으로 경고 해결
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5))
              ),
              child: Row(
                  children: [
                    Icon(Icons.info_outline, color: statusColor),
                    const SizedBox(width: 12),
                    Expanded(child: Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15)))
                  ]
              )
          ),
          const SizedBox(height: 12),
          Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('출고 대상 확인', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('📦 제품: ${p != null ? '${p['name']} (${p['sku']})' : '대기중...'}', style: TextStyle(color: p != null ? Colors.black : Colors.grey)),
                        const SizedBox(height: 8),
                        Text('📍 위치: ${l != null ? l['locationCode'] : '대기중...'}', style: TextStyle(color: l != null ? Colors.black : Colors.grey)),

                        if (p != null && l != null) ...[ // 🚨 아까 여기서 괄호 에러가 났었습니다! 지금은 완벽히 수정됨.
                          const SizedBox(height: 20),
                          const Text('수량 입력 (숫자만 입력)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          const SizedBox(height: 12),
                          Row(
                              children: [
                                Expanded(
                                    child: TextField(
                                        controller: normalQtyCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                            labelText: '정상 출고 (장)',
                                            hintText: '예: 40',
                                            border: const OutlineInputBorder(),
                                            fillColor: Colors.blue.shade50,
                                            filled: true
                                        )
                                    )
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: TextField(
                                        controller: bGradeQtyCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                            labelText: 'B급 빼냄 (장)',
                                            hintText: '예: 5',
                                            border: const OutlineInputBorder(),
                                            fillColor: Colors.red.shade50,
                                            filled: true
                                        )
                                    )
                                )
                              ]
                          )
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                            onPressed: canConfirm ? _confirmOutbound : null,
                            style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.orange.shade700
                            ),
                            icon: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle),
                            label: Text(isSubmitting ? '처리 중...' : '출고 확정 및 차감', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                            onPressed: () => reset(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('전체 다시 스캔')
                        )
                      ]
                  )
              )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 720) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildScannerBox()),
                    Expanded(flex: 2, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: _buildInfoPanel())))
                  ]
              );
            } else {
              return Column(
                  children: [
                    Expanded(flex: 4, child: _buildScannerBox()),
                    Expanded(flex: 6, child: _buildInfoPanel())
                  ]
              );
            }
          }
      ),
    );
  }
}