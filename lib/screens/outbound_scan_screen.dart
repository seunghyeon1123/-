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

  final Color hanjiIvory = const Color(0xFFFDFBF7);
  final Color yogurtTint = const Color(0xFFE7E2DE);
  final Color textDark = const Color(0xFF333333);

  Map<String, dynamic>? product;
  Map<String, dynamic>? location;

  bool isFetchingLocation = false;
  bool isProcessingScan = false;
  bool isSubmitting = false;
  bool isUndoing = false;

  String statusText = '대기중 (제품 QR을 스캔하세요)';
  Color statusColor = Colors.grey;
  String? lastScannedRaw;

  String? lastTransactionTime;
  int? lastBGradeQty;

  // ✅ 줌 배율 세팅
  double _currentZoom = 0.25;
  double _currentScaleLabel = 1.0;

  final normalQtyCtrl = TextEditingController();
  final bGradeQtyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(autoStart: false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        controller.start().then((_) {
          controller.setZoomScale(_currentZoom);
        });
      }
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
    setState(() { statusText = text; statusColor = color; });
  }

  void _showBottomMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)));
  }

  void reset() {
    setState(() {
      product = null; location = null;
      isFetchingLocation = false; isProcessingScan = false; isSubmitting = false; isUndoing = false;
      lastScannedRaw = null; normalQtyCtrl.clear(); bGradeQtyCtrl.clear();
      statusText = '대기중 (제품 QR을 스캔하세요)'; statusColor = Colors.grey;
    });
    controller.start().then((_) => controller.setZoomScale(_currentZoom));
  }

  Future<Map<String, dynamic>> _postJsonWithRedirect(Map<String, dynamic> payload) async {
    try {
      var res = await http.post(Uri.parse(WEBAPP_URL), headers: {'Content-Type': 'text/plain'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 45));
      if (res.statusCode == 302 || res.statusCode == 303) {
        final redirectUrl = res.headers['location'] ?? res.headers['Location'];
        if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 45));
      }
      if (res.statusCode == 200) {
        try {
          return jsonDecode(res.body) as Map<String, dynamic>;
        } catch (e) {
          if(res.body.contains("<html")) throw Exception('서버 설정 오류: 구글 스크립트 새 배포가 필요하거나 URL이 잘못되었습니다.');
          throw Exception('구글 응답 파싱 실패');
        }
      }
      throw Exception('HTTP 상태 코드 에러: ${res.statusCode}');
    } on TimeoutException { throw Exception('서버 응답 시간 초과'); } catch (e) { throw Exception('통신 오류: $e'); }
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (isSubmitting || isProcessingScan || isFetchingLocation || isUndoing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw == lastScannedRaw) return;
    lastScannedRaw = raw;

    Map<String, dynamic> data;
    try {
      if (raw.startsWith('https://andonghanji.com/board/index.php?app_data=')) {
        data = jsonDecode(utf8.decode(base64Decode(raw.split('app_data=')[1]))) as Map<String, dynamic>;
      } else {
        data = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {
      _setStatus('유효하지 않은 QR입니다.', Colors.redAccent); return;
    }

    final type = (data['type'] ?? '').toString();
    if (type != 'product_pack') {
      _setStatus('제품 QR만 스캔 가능합니다.', Colors.orange);
      return;
    }

    setState(() { product = data; isFetchingLocation = true; });
    controller.stop();
    _setStatus('위치 확인 중...', Colors.orange);

    try {
      final resp = await _postJsonWithRedirect({ "action": "getLocationByTempId", "tempId": data["tempId"] });
      if (resp["ok"] == true) {
        setState(() { location = { "locationCode": resp["locationCode"], "warehouse": resp["warehouse"] }; isFetchingLocation = false; });
        _setStatus('위치 확인 완료! 수량을 입력하세요.', Colors.green);
        _showBottomMessage('✔️ 서버에서 위치 정보를 자동으로 불러왔습니다.');
      } else { throw Exception(resp["error"]); }
    } catch (e) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('입고 기록이 없는')) {
        _setStatus('입고되지 않은 제품입니다', Colors.redAccent); _showBottomMessage('⚠️ 이 QR은 입고 처리된 기록이 없어 출고할 수 없습니다.');
      } else {
        _setStatus('서버 응답 오류', Colors.redAccent); _showBottomMessage('❌ 통신 실패: $errorMsg');
      }
      setState(() => isFetchingLocation = false);
      controller.start();
    }
  }

  Future<void> _confirmOutbound() async {
    final p = product; final l = location;
    if (p == null || l == null) return;

    final int normalQty = int.tryParse(normalQtyCtrl.text) ?? 0;
    final int bGradeQty = int.tryParse(bGradeQtyCtrl.text) ?? 0;

    if (normalQty == 0 && bGradeQty == 0) { _showBottomMessage('⚠️ 출고 또는 불량 수량을 최소 1개 이상 입력하세요.'); return; }

    setState(() { isSubmitting = true; lastTransactionTime = null; lastBGradeQty = null; });
    _setStatus('출고 처리 중...', Colors.orange);

    try {
      final submitTime = DateTime.now().toIso8601String();
      final payload = { "time": submitTime, "type": "outbound", "sku": p["sku"], "name": p["name"], "weightKg": p["weightKg"] ?? 0, "locationCode": l["locationCode"], "warehouse": l["warehouse"], "normalQty": normalQty, "bGradeQty": bGradeQty };
      final resp = await _postJsonWithRedirect(payload);
      if (resp["ok"] == true) {
        _setStatus('출고 완료', Colors.green); _showBottomMessage('✅ 정상적으로 재고가 차감되었습니다.');
        setState(() { lastTransactionTime = submitTime; lastBGradeQty = bGradeQty; });
        reset();
        setState(() { statusText = '대기중 (다음 제품 QR 스캔)'; statusColor = Colors.grey; });
      } else { throw Exception(resp["error"]); }
    } catch (e) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('재고가 부족합니다')) { _setStatus('재고 부족', Colors.redAccent); _showBottomMessage('⚠️ $errorMsg'); }
      else { _setStatus('처리 실패', Colors.redAccent); _showBottomMessage('❌ 오류: $errorMsg'); }
      setState(() => isSubmitting = false); controller.start();
    }
  }

  Future<void> _undoOutbound() async {
    if (lastTransactionTime == null) return;
    setState(() => isUndoing = true); _setStatus('출고 취소 중...', Colors.orange);
    try {
      final resp = await _postJsonWithRedirect({ "action": "undo", "targetType": "outbound", "targetId": lastTransactionTime, "bGradeQty": lastBGradeQty ?? 0 });
      if (resp["ok"] == true) {
        _setStatus('취소 완료', Colors.green); _showBottomMessage('✅ 방금 처리한 출고 내역이 원상복구 되었습니다.');
        setState(() { lastTransactionTime = null; lastBGradeQty = null; });
      } else { throw Exception(resp["error"]); }
    } catch (e) {
      _setStatus('취소 실패', Colors.redAccent); _showBottomMessage('❌ 오류: ${e.toString().replaceAll('Exception: ', '')}');
    } finally { setState(() => isUndoing = false); }
  }

  // ✅ 카메라 실제 배율 적용 (초광각 배제)
  void _setCameraZoom(double scaleParam) {
    setState(() {
      _currentScaleLabel = scaleParam;
      if (scaleParam == 1.0) { _currentZoom = 0.25; }
      else if (scaleParam == 2.0) { _currentZoom = 0.50; }
      else if (scaleParam == 3.0) { _currentZoom = 0.75; }
      else if (scaleParam == 5.0) { _currentZoom = 1.0; }

      controller.setZoomScale(_currentZoom);
    });
  }

  // ✅ 줌 컨트롤 UI: 반투명 원형 태그
  Widget _buildScannerBox() {
    return Container(
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
        margin: const EdgeInsets.all(12),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: controller, onDetect: onDetect),
                Positioned(
                    bottom: 20, left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [1.0, 2.0, 3.0, 5.0].map((scale) {
                        final isSelected = _currentScaleLabel == scale;
                        return GestureDetector(
                          onTap: () => _setCameraZoom(scale),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? yogurtTint.withOpacity(0.9) : Colors.black.withOpacity(0.4),
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                            ),
                            child: Center(
                              child: Text('${scale.toInt()}x', style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16,
                                color: isSelected ? textDark : Colors.white,
                              )),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                )
              ],
            )
        )
    );
  }

  Widget _buildInfoPanel() {
    final p = product; final l = location; final canConfirm = (p != null && l != null && !isSubmitting && !isUndoing);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.5))), child: Row(children: [isFetchingLocation ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.info_outline, color: statusColor), const SizedBox(width: 12), Expanded(child: Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15)))])), const SizedBox(height: 12),

          if (lastTransactionTime != null && p == null) ...[
            Card(
                color: Colors.green.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade200)),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('방금 출고 처리가 완료되었습니다.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), const SizedBox(height: 12),
                        OutlinedButton.icon(onPressed: isUndoing ? null : _undoOutbound, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), icon: isUndoing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)) : const Icon(Icons.undo), label: const Text('실수로 잘못 눌렀다면? (취소)'))
                      ],
                    )
                )
            ),
            const SizedBox(height: 12),
          ],

          Card(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('출고 대상 확인', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textDark)), const Divider(), const SizedBox(height: 8),
            Text('📦 제품: ${p != null ? '${p['name']} (${p['sku']})' : '대기중...'}', style: TextStyle(color: p != null ? textDark : Colors.grey)), const SizedBox(height: 8),
            Text('📍 위치: ${l != null ? l['locationCode'] : (isFetchingLocation ? '서버에서 찾는 중...' : '대기중...')}', style: TextStyle(color: l != null ? textDark : Colors.grey, fontWeight: l != null ? FontWeight.bold : FontWeight.normal)),

            if (p != null && l != null) ...[
              const SizedBox(height: 20), Text('수량 입력 (숫자만 입력)', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)), const SizedBox(height: 12),
              Row(children: [Expanded(child: TextField(controller: normalQtyCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '정상 출고 (장)', labelStyle: TextStyle(color: textDark), hintText: '예: 40', filled: true, fillColor: Colors.white, enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: yogurtTint, width: 2), borderRadius: BorderRadius.circular(8))))), const SizedBox(width: 12), Expanded(child: TextField(controller: bGradeQtyCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'B급 빼냄 (장)', labelStyle: TextStyle(color: textDark), hintText: '예: 5', filled: true, fillColor: Colors.white, enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: yogurtTint, width: 2), borderRadius: BorderRadius.circular(8)))))])
            ],
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: canConfirm ? _confirmOutbound : null, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: yogurtTint, foregroundColor: textDark, disabledBackgroundColor: Colors.grey.shade200), icon: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 2)) : const Icon(Icons.check_circle), label: Text(isSubmitting ? '처리 중...' : '출고 확정 및 차감', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => reset(), style: OutlinedButton.styleFrom(foregroundColor: textDark, side: BorderSide(color: yogurtTint, width: 2)), icon: const Icon(Icons.refresh), label: const Text('취소하고 다시 스캔'))
          ]))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hanjiIvory,
      appBar: AppBar(backgroundColor: hanjiIvory, elevation: 0, title: Text('출고 스캔', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)), actions: [IconButton(onPressed: () => reset(), icon: Icon(Icons.refresh, color: textDark), tooltip: '초기화')]),
      body: LayoutBuilder(builder: (context, constraints) { if (constraints.maxWidth >= 720) { return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _buildScannerBox()), Expanded(flex: 2, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: _buildInfoPanel())))]); } else { return Column(children: [Expanded(flex: 4, child: _buildScannerBox()), Expanded(flex: 6, child: _buildInfoPanel())]); } }),
    );
  }
}