// lib/screens/inbound_scan_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class InboundScanScreen extends StatefulWidget {
  const InboundScanScreen({super.key});
  @override
  State<InboundScanScreen> createState() => _InboundScanScreenState();
}

class _InboundScanScreenState extends State<InboundScanScreen> {
  static const String WEBAPP_URL = AppConfig.webAppUrl;
  late MobileScannerController controller;

  Map<String, dynamic>? product;
  Map<String, dynamic>? location;
  bool scanningProduct = true;
  bool isProcessingScan = false;
  bool isSubmitting = false;
  bool isUndoing = false; // 취소 진행 상태 추가

  String statusText = '대기중 (제품 QR을 스캔하세요)';
  Color statusColor = Colors.grey;
  String? lastBatchId;
  bool? lastDuplicate;
  String? lastScannedRaw;

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

  void reset({bool keepLastResult = false}) {
    setState(() {
      product = null; location = null; scanningProduct = true; isProcessingScan = false; isSubmitting = false; isUndoing = false; lastScannedRaw = null;
      if (!keepLastResult) { lastBatchId = null; lastDuplicate = null; statusText = '대기중 (제품 QR을 스캔하세요)'; statusColor = Colors.grey; }
      else { statusText = '대기중 (다음 입고 준비 완료)'; statusColor = Colors.grey; }
    });
    controller.start();
  }

  Future<Map<String, dynamic>> _postJsonWithRedirect(Map<String, dynamic> payload) async {
    try {
      var res = await http.post(Uri.parse(WEBAPP_URL), headers: {'Content-Type': 'text/plain'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 45));
      if (res.statusCode == 302 || res.statusCode == 303) {
        final redirectUrl = res.headers['location'] ?? res.headers['Location'];
        if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 45));
      }
      if (res.statusCode == 200) { try { return jsonDecode(res.body) as Map<String, dynamic>; } catch (e) { throw Exception('구글 응답 파싱 실패 (JSON 아님): ${res.body.length > 50 ? res.body.substring(0, 50) + "..." : res.body}'); } }
      throw Exception('HTTP 상태 코드 에러: ${res.statusCode}');
    } on TimeoutException { throw Exception('구글 서버 응답 시간 초과 (데이터는 시트에 기록되었을 수 있습니다!)'); } catch (e) { throw Exception('기기 통신 오류: $e'); }
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (isSubmitting || isProcessingScan || isUndoing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw == lastScannedRaw) return;
    lastScannedRaw = raw;

    Map<String, dynamic> data;
    try {
      if (raw.startsWith('https://andonghanji.com/board/index.php?app_data=')) {
        final base64String = raw.split('app_data=')[1];
        final decodedJsonString = utf8.decode(base64Decode(base64String));
        data = jsonDecode(decodedJsonString) as Map<String, dynamic>;
      } else {
        data = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {
      _setStatus('앱에서 생성한 QR이 아닙니다.', Colors.redAccent);
      return;
    }

    setState(() => isProcessingScan = true);
    final type = (data['type'] ?? '').toString();

    if (scanningProduct) {
      if (type != 'product_pack') { _setStatus('위치 QR입니다. 제품 QR을 먼저 스캔하세요.', Colors.orange); setState(() => isProcessingScan = false); return; }
      final tempId = (data['tempId'] ?? '').toString().trim();
      if (tempId.isEmpty) { _setStatus('유효하지 않은 제품 QR입니다.', Colors.redAccent); setState(() => isProcessingScan = false); return; }
      setState(() { product = data; scanningProduct = false; isProcessingScan = false; });
      _setStatus('제품 인식 완료 → 위치 QR 스캔 요망', Colors.blue); _showBottomMessage('✔️ 제품 스캔 완료. 이어서 위치 QR을 스캔해주세요.');
      return;
    }

    if (type != 'location') { _setStatus('제품 QR입니다. 위치 QR을 스캔하세요.', Colors.orange); setState(() => isProcessingScan = false); return; }
    setState(() { location = data; isProcessingScan = false; });
    _setStatus('위치 인식 완료 → 입고 확정 가능', Colors.blue); _showBottomMessage('✔️ 위치 스캔 완료. 입고 확정 버튼을 눌러주세요.');
    controller.stop();
  }

  Future<void> _confirmInbound() async {
    final p = product; final l = location;
    if (p == null || l == null) return;

    setState(() { isSubmitting = true; lastBatchId = null; lastDuplicate = null; });
    controller.stop(); _setStatus('재고 정보 업데이트 중 (최대 45초 대기)...', Colors.orange);

    try {
      final inbound = { "time": DateTime.now().toIso8601String(), "type": "inbound", "tempId": p["tempId"], "sku": p["sku"], "name": p["name"], "producer": p["producer"], "producedAt": p["producedAt"], "qty": p["qty"], "weightKg": p["weightKg"], "perSheetG": p["perSheetG"] ?? 0, "category": p["category"] ?? "", "attrs": p["attrs"] ?? "", "locationCode": l["locationCode"], "warehouse": l["warehouse"], "zone": l["zone"] ?? "", "rack": l["rack"] ?? "", "bin": l["bin"] ?? "" };
      final resp = await _postJsonWithRedirect(inbound);
      final ok = resp["ok"] == true;

      if (!ok) { _setStatus('업데이트 실패: ${resp["error"] ?? resp}', Colors.redAccent); _showBottomMessage('❌ 서버가 에러를 반환했습니다.'); setState(() => isSubmitting = false); controller.start(); return; }
      final duplicate = resp["duplicate"] == true; final batchId = (resp["batchId"] ?? '').toString();
      setState(() { lastDuplicate = duplicate; lastBatchId = batchId.isEmpty ? null : batchId; });

      if (duplicate) { _setStatus('중복 차단됨 (기존 입고건)', Colors.redAccent); _showBottomMessage('⚠️ 이미 입고 처리된 바코드입니다.'); } else { _setStatus('업데이트 성공 (Batch: $batchId)', Colors.green); _showBottomMessage('✅ 재고 정보가 정상적으로 업데이트되었습니다.'); }
      reset(keepLastResult: true);
    } catch (e) { _setStatus('오류 발생', Colors.deepOrange); _showBottomMessage('❌ 상세 오류: $e'); setState(() => isSubmitting = false); controller.start(); }
  }

  // 🔴 [신규 추가] 입고 취소 함수
  Future<void> _undoInbound() async {
    if (lastBatchId == null) return;

    setState(() => isUndoing = true);
    _setStatus('입고 취소 중...', Colors.orange);

    try {
      final payload = { "action": "undo", "targetType": "inbound", "targetId": lastBatchId };
      final resp = await _postJsonWithRedirect(payload);

      if (resp["ok"] == true) {
        _setStatus('취소 성공', Colors.green);
        _showBottomMessage('✅ 방금 처리한 입고 내역이 삭제되었습니다.');
        setState(() => lastBatchId = null); // 취소 버튼 숨기기
      } else {
        throw Exception(resp["error"]);
      }
    } catch (e) {
      _setStatus('취소 실패', Colors.redAccent);
      _showBottomMessage('❌ 오류: $e');
    } finally {
      setState(() => isUndoing = false);
    }
  }

  Widget _buildScannerBox() { return Container(decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.all(12), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: MobileScanner(controller: controller, onDetect: onDetect))); }

  Widget _buildInfoPanel() {
    final p = product; final l = location; final canConfirm = (p != null && l != null && !isSubmitting && !isUndoing);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.5))), child: Row(children: [Icon(Icons.info_outline, color: statusColor), const SizedBox(width: 12), Expanded(child: Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15)))])), const SizedBox(height: 12),
          Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('스캔 결과', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const Divider(), const SizedBox(height: 8),
            Text('📦 제품: ${p != null ? '${p['name']} / ${p['qty']}개' : '대기중...'}', style: TextStyle(color: p != null ? Colors.black : Colors.grey)), const SizedBox(height: 8),
            Text('📍 위치: ${l != null ? l['locationCode'] : '대기중...'}', style: TextStyle(color: l != null ? Colors.black : Colors.grey)),

            if (lastBatchId != null) ...[
              const SizedBox(height: 16),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: lastDuplicate == true ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(lastDuplicate == true ? '⚠️ 중복 입고 (기존 Batch: $lastBatchId)' : '✅ 입고 완료 (Batch: $lastBatchId)', style: TextStyle(fontWeight: FontWeight.bold, color: lastDuplicate == true ? Colors.red.shade700 : Colors.green.shade700))),

              // 🔴 [신규 추가] 취소 버튼
              if (lastDuplicate != true) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                    onPressed: isUndoing ? null : _undoInbound,
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    icon: isUndoing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)) : const Icon(Icons.undo),
                    label: const Text('방금 한 작업 취소')
                )
              ]
            ],

            const SizedBox(height: 20),
            FilledButton.icon(onPressed: canConfirm ? _confirmInbound : null, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), icon: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle), label: Text(isSubmitting ? '업데이트 중...' : '입고 확정', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), const SizedBox(height: 12), OutlinedButton.icon(onPressed: (scanningProduct || isSubmitting || isUndoing) ? null : () { setState(() { location = null; lastBatchId = null; lastDuplicate = null; lastScannedRaw = null; }); _setStatus('위치 QR을 다시 스캔하세요', Colors.orange); controller.start(); }, icon: const Icon(Icons.qr_code_scanner), label: const Text('위치만 다시 스캔'))
          ]))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('입고 처리 (스캔)'), actions: [IconButton(onPressed: () => reset(keepLastResult: false), icon: const Icon(Icons.refresh), tooltip: '초기화')]),
      body: LayoutBuilder(builder: (context, constraints) { if (constraints.maxWidth >= 720) { return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _buildScannerBox()), Expanded(flex: 2, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: _buildInfoPanel())))]); } else { return Column(children: [Expanded(flex: 5, child: _buildScannerBox()), Expanded(flex: 6, child: _buildInfoPanel())]); } }),
    );
  }
}