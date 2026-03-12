// lib/screens/inbound_scan_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  final Color hanjiIvory = const Color(0xFFFDFBF7);
  final Color yogurtTint = const Color(0xFFE7E2DE);
  final Color stoneShadow = const Color(0xFF586B54);
  final Color textDark = const Color(0xFF333333);
  final Color errorRed = const Color(0xFFEF5350);
  final Color successGreen = const Color(0xFF66BB6A);
  final Color warningOrange = const Color(0xFFFFA726);

  // 🟢 핵심: 스캔 모드 스위치 (inbound: 창고입고, unpack: 매장개봉)
  String scanMode = 'inbound';

  Map<String, dynamic>? product;
  Map<String, dynamic>? location;
  bool scanningProduct = true;
  bool isProcessingScan = false;
  bool isSubmitting = false;
  bool isUndoing = false;

  String statusText = '대기중 (제품 바코드를 스캔하세요)';
  Color statusColor = Colors.grey;
  String? lastBatchId;
  bool? lastDuplicate;
  String? lastScannedRaw;

  double _currentZoom = 0.25;
  double _currentScaleLabel = 1.0;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(autoStart: false);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) controller.start().then((_) => controller.setZoomScale(_currentZoom));
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
      if (!keepLastResult) { lastBatchId = null; lastDuplicate = null; statusText = '대기중 (제품 바코드를 스캔하세요)'; statusColor = Colors.grey; }
      else { statusText = '대기중 (다음 작업 준비 완료)'; statusColor = Colors.grey; }
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
      if (res.statusCode == 200) { try { return jsonDecode(res.body) as Map<String, dynamic>; } catch (e) { throw Exception('파싱 실패'); } }
      throw Exception('HTTP 에러');
    } on TimeoutException { throw Exception('응답 시간 초과'); } catch (e) { throw Exception('통신 오류: $e'); }
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (isSubmitting || isProcessingScan || isUndoing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw == lastScannedRaw) return;
    lastScannedRaw = raw;

    Map<String, dynamic> data;
    try {
      if (raw.startsWith('https://andonghanji.com/board/index.php?app_data=')) {
        data = jsonDecode(utf8.decode(base64Decode(raw.split('app_data=')[1]))) as Map<String, dynamic>;
      } else { data = jsonDecode(raw) as Map<String, dynamic>; }
    } catch (_) { _setStatus('유효하지 않은 바코드입니다.', errorRed); return; }

    setState(() => isProcessingScan = true);
    final type = (data['type'] ?? '').toString();

    if (scanningProduct) {
      if (type != 'product_pack') { _setStatus('제품 바코드를 먼저 스캔하세요.', warningOrange); setState(() => isProcessingScan = false); return; }

      setState(() {
        product = data;
        scanningProduct = false;
        isProcessingScan = false;

        // 🟢 [매장 개봉] 모드일 때는 위치 스캔을 건너뛰고 바로 매장으로 할당!
        if (scanMode == 'unpack') {
          location = {"locationCode": "STORE-DISPLAY", "warehouse": "매장 낱장 진열대", "zone": "", "rack": "", "bin": ""};
          _setStatus('매장 진열 인식 완료 → 개봉 확정 가능', successGreen);
          _showBottomMessage('✔️ 팩 바코드 스캔 완료. 개봉 확정 버튼을 눌러주세요.');
          controller.stop();
        } else {
          _setStatus('제품 인식 완료 → 위치 QR 스캔', Colors.blue);
          _showBottomMessage('✔️ 제품 스캔 완료. 이어서 창고 위치 QR을 스캔해주세요.');
        }
      });
      return;
    }

    // 창고 입고 모드일 때만 위치 스캔 수행
    if (type != 'location') { _setStatus('위치 QR을 스캔하세요.', warningOrange); setState(() => isProcessingScan = false); return; }
    setState(() { location = data; isProcessingScan = false; });
    _setStatus('위치 인식 완료 → 입고 확정 가능', successGreen); _showBottomMessage('✔️ 위치 스캔 완료. 입고 확정 버튼을 눌러주세요.');
    controller.stop();
  }

  // 🟢 서버로 전송할 때 'inbound'인지 'unpack'인지 구분해서 보냅니다.
  Future<void> _confirmAction() async {
    final p = product; final l = location;
    if (p == null || l == null) return;
    setState(() { isSubmitting = true; lastBatchId = null; lastDuplicate = null; });
    controller.stop(); _setStatus('서버 업데이트 중...', warningOrange);

    try {
      final resp = await _postJsonWithRedirect({
        "time": DateTime.now().toIso8601String(),
        "type": scanMode, // 🟢 inbound 또는 unpack 전송
        "tempId": p["tempId"],
        "sku": p["sku"],
        "name": p["name"],
        "producer": p["producer"],
        "producedAt": p["producedAt"],
        "qty": p["qty"],
        "weightKg": p["weightKg"],
        "category": p["category"] ?? "",
        "attrs": p["attrs"] ?? "",
        "locationCode": l["locationCode"],
        "warehouse": l["warehouse"],
        "zone": l["zone"] ?? "",
        "rack": l["rack"] ?? "",
        "bin": l["bin"] ?? "",
        "gsm": p["gsm"] ?? "",
        "lye": p["lye"] ?? "",
        "ply": p["ply"] ?? 1,
        "drying": p["drying"] ?? "열판건조",
        "dochim": p["dochim"] ?? "미도침",
        "variation": p["variation"] ?? "",
        "thickness": p["thickness"] ?? "보통"
      });

      if (resp["ok"] != true) { _setStatus('실패: ${resp["error"]}', errorRed); setState(() => isSubmitting = false); controller.start(); return; }
      final duplicate = resp["duplicate"] == true; final batchId = (resp["batchId"] ?? '').toString();
      setState(() { lastDuplicate = duplicate; lastBatchId = batchId.isEmpty ? null : batchId; });

      if (duplicate) { _setStatus('중복 처리 차단 (Batch: $batchId)', warningOrange); }
      else { _setStatus('성공 (Batch: $batchId)', successGreen); }
      reset(keepLastResult: true);
    } catch (e) { _setStatus('오류 발생: $e', errorRed); setState(() => isSubmitting = false); controller.start(); }
  }

  Future<void> _undoAction() async {
    if (lastBatchId == null) return;
    setState(() => isUndoing = true); _setStatus('작업 취소 중...', warningOrange);
    try {
      final resp = await _postJsonWithRedirect({ "action": "undo", "targetType": scanMode, "targetId": lastBatchId });
      if (resp["ok"] == true) {
        _setStatus('취소 성공', successGreen); _showBottomMessage('✅ 방금 처리한 내역이 삭제되었습니다.');
        setState(() => lastBatchId = null);
      } else { throw Exception(resp["error"]); }
    } catch (e) { _setStatus('취소 실패', errorRed); _showBottomMessage('❌ 오류: $e'); }
    finally { setState(() => isUndoing = false); }
  }

  void _setCameraZoom(double scaleParam) {
    setState(() {
      _currentScaleLabel = scaleParam;
      if (scaleParam == 1.0) _currentZoom = 0.25;
      else if (scaleParam == 2.0) _currentZoom = 0.50;
      else if (scaleParam == 3.0) _currentZoom = 0.75;
      else if (scaleParam == 5.0) _currentZoom = 1.0;
      controller.setZoomScale(_currentZoom);
    });
  }

  Widget _buildScannerBox() {
    return Container(
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? yogurtTint.withOpacity(0.9) : Colors.black.withOpacity(0.4), border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2)),
                            child: Center(child: Text('${scale.toInt()}x', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isSelected ? textDark : Colors.white))),
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.5))), child: Row(children: [Icon(Icons.info_outline, color: statusColor), const SizedBox(width: 12), Expanded(child: Text(statusText, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15)))])), const SizedBox(height: 12),

          if (lastBatchId != null) ...[
            Card(
                color: lastDuplicate == true ? Colors.red.shade50 : Colors.green.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: lastDuplicate == true ? Colors.red.shade200 : Colors.green.shade200)),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(lastDuplicate == true ? '⚠️ 중복 처리 차단됨' : '✅ 정상 처리되었습니다.', style: TextStyle(fontWeight: FontWeight.bold, color: lastDuplicate == true ? Colors.red.shade700 : Colors.green.shade700)), const SizedBox(height: 12),
                        if (lastDuplicate != true) OutlinedButton.icon(onPressed: isUndoing ? null : _undoAction, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), icon: isUndoing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)) : const Icon(Icons.undo), label: const Text('실수로 잘못 눌렀다면? (취소)'))
                      ],
                    )
                )
            ),
            const SizedBox(height: 12),
          ],

          Card(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(scanMode == 'inbound' ? '입고 대상 확인' : '개봉 대상 확인', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textDark)), const Divider(), const SizedBox(height: 8),
            Text('📦 팩 제품: ${p != null ? '${p['name']} / ${p['qty']}장' : '대기중...'}', style: TextStyle(color: p != null ? textDark : Colors.grey)), const SizedBox(height: 8),
            Text('📍 위치: ${l != null ? l['warehouse'] : '대기중...'}', style: TextStyle(color: l != null ? textDark : Colors.grey)),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: canConfirm ? _confirmAction : null,
                style: FilledButton.styleFrom(backgroundColor: scanMode == 'unpack' ? Colors.orange.shade400 : yogurtTint, foregroundColor: textDark, padding: const EdgeInsets.symmetric(vertical: 16)),
                icon: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54)) : Icon(scanMode == 'unpack' ? Icons.content_cut : Icons.check_circle),
                label: Text(isSubmitting ? '처리 중...' : (scanMode == 'unpack' ? '낱장 개봉 확정' : '입고 확정'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            ),
            const SizedBox(height: 12),
            if (scanMode == 'inbound') OutlinedButton.icon(onPressed: (scanningProduct || isSubmitting || isUndoing) ? null : () { setState(() { location = null; lastScannedRaw = null; }); _setStatus('위치 QR을 다시 스캔하세요', warningOrange); controller.start(); }, style: OutlinedButton.styleFrom(foregroundColor: textDark, side: BorderSide(color: yogurtTint, width: 2)), icon: const Icon(Icons.qr_code_scanner), label: const Text('위치만 다시 스캔'))
          ]))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hanjiIvory,
      appBar: AppBar(
          backgroundColor: hanjiIvory, elevation: 0,
          title: Text('바코드 스캔', style: TextStyle(color: textDark, fontWeight: FontWeight.bold)),
          actions: [IconButton(onPressed: () => reset(keepLastResult: false), icon: Icon(Icons.refresh, color: textDark), tooltip: '초기화')]
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        return Column(children: [
          // 🟢 스캔 모드 선택 스위치
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: CupertinoSlidingSegmentedControl<String>(
              backgroundColor: Colors.grey.shade200,
              thumbColor: Colors.white,
              groupValue: scanMode,
              children: {
                'inbound': Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Text('📦 창고 입고', style: TextStyle(fontWeight: scanMode == 'inbound' ? FontWeight.bold : FontWeight.normal))),
                'unpack': Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Text('✂️ 매장 개봉(진열)', style: TextStyle(fontWeight: scanMode == 'unpack' ? FontWeight.bold : FontWeight.normal))),
              },
              onValueChanged: (v) {
                if (v != null) setState(() { scanMode = v; reset(keepLastResult: false); });
              },
            ),
          ),
          Expanded(flex: 5, child: _buildScannerBox()),
          Expanded(flex: 6, child: _buildInfoPanel())
        ]);
      }),
    );
  }
}