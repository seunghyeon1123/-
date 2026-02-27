// lib/screens/inbound_scan_screen.dart

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

  final MobileScannerController controller = MobileScannerController();

  Map<String, dynamic>? product;
  Map<String, dynamic>? location;
  bool scanningProduct = true;

  bool isProcessingScan = false;
  bool isSubmitting = false;

  String statusText = '대기중 (제품 QR을 스캔하세요)';
  Color statusColor = Colors.grey;

  String? lastBatchId;
  bool? lastDuplicate;

  // ✅ 중복 인식 스팸 방지용 변수
  String? lastScannedRaw;

  void _setStatus(String text, Color color) {
    if (!mounted) return;
    setState(() {
      statusText = text;
      statusColor = color;
    });
  }

  // ✅ 하단에 간결하게 한 번만 뜨는 플로팅 스낵바
  void _showBottomMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating, // 화면 하단에 떠오르는 스타일
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void reset({bool keepLastResult = false}) {
    setState(() {
      product = null;
      location = null;
      scanningProduct = true;
      isProcessingScan = false;
      isSubmitting = false;
      lastScannedRaw = null; // 초기화 시 스캔 기록도 삭제

      if (!keepLastResult) {
        lastBatchId = null;
        lastDuplicate = null;
        statusText = '대기중 (제품 QR을 스캔하세요)';
        statusColor = Colors.grey;
      } else {
        statusText = '대기중 (다음 입고 준비 완료)';
        statusColor = Colors.grey;
      }
    });

    controller.start();
  }

  // ✅ 수정된 네트워크 전송 함수 (CORS 우회)
  Future<Map<String, dynamic>> _postJsonWithRedirect(Map<String, dynamic> payload) async {
    try {
      // JSON이지만 브라우저 보안(CORS OPTIONS)을 피하기 위해 text/plain으로 보냅니다.
      final res = await http.post(
        Uri.parse(WEBAPP_URL),
        headers: {'Content-Type': 'text/plain'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      // 정상 응답 또는 리다이렉트 응답 처리
      if (res.statusCode == 200 || res.statusCode == 302) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw Exception('HTTP ${res.statusCode}');
    } catch (e) {
      // 웹에서 302 리다이렉트 후 투명 에러가 발생해도, 시트가 업데이트 되는 경우가 많음
      // 에러가 나더라도 'ok: true' 인 척 무시하고 진행하거나 서버에 get으로 확인하는 방법도 있지만,
      // text/plain 방식으로 대부분 해결됩니다.
      throw Exception('서버 응답 오류 (CORS 또는 네트워크 확인): $e');
    }
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (isSubmitting || isProcessingScan) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    // ✅ 방금 인식한 바코드와 똑같으면 무시 (스팸 방지 핵심)
    if (raw == lastScannedRaw) return;
    lastScannedRaw = raw;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _setStatus('앱에서 생성한 QR이 아닙니다.', Colors.redAccent);
      return;
    }

    setState(() => isProcessingScan = true);
    final type = (data['type'] ?? '').toString();

    // 1) 제품 QR 단계
    if (scanningProduct) {
      if (type != 'product_pack') {
        _setStatus('위치 QR입니다. 제품 QR을 먼저 스캔하세요.', Colors.orange);
        setState(() => isProcessingScan = false);
        return;
      }

      final tempId = (data['tempId'] ?? '').toString().trim();
      if (tempId.isEmpty) {
        _setStatus('유효하지 않은 제품 QR입니다.', Colors.redAccent);
        setState(() => isProcessingScan = false);
        return;
      }

      setState(() {
        product = data;
        scanningProduct = false;
        isProcessingScan = false;
      });
      _setStatus('제품 인식 완료 → 위치 QR 스캔 요망', Colors.blue);
      _showBottomMessage('✔️ 제품 스캔 완료. 이어서 위치 QR을 스캔해주세요.');
      return;
    }

    // 2) 위치 QR 단계
    if (type != 'location') {
      _setStatus('제품 QR입니다. 위치 QR을 스캔하세요.', Colors.orange);
      setState(() => isProcessingScan = false);
      return;
    }

    setState(() {
      location = data;
      isProcessingScan = false;
    });
    _setStatus('위치 인식 완료 → 입고 확정 가능', Colors.blue);
    _showBottomMessage('✔️ 위치 스캔 완료. 입고 확정 버튼을 눌러주세요.');

    // 두 개 다 찍었으면 카메라 일시정지 (불필요한 배터리 소모 및 인식 방지)
    controller.stop();
  }

  Future<void> _confirmInbound() async {
    final p = product;
    final l = location;

    if (p == null || l == null) return;

    setState(() {
      isSubmitting = true;
      lastBatchId = null;
      lastDuplicate = null;
    });

    controller.stop();
    _setStatus('재고 정보 업데이트 중...', Colors.orange);

    try {
      final inbound = <String, dynamic>{
        "time": DateTime.now().toIso8601String(),
        "type": "inbound",
        "tempId": p["tempId"],
        "sku": p["sku"],
        "name": p["name"],
        "producer": p["producer"],
        "producedAt": p["producedAt"],
        "qty": p["qty"],
        "weightKg": p["weightKg"],
        "category": p["category"],
        "locationCode": l["locationCode"],
        "warehouse": l["warehouse"],
      };

      final resp = await _postJsonWithRedirect(inbound);
      final ok = resp["ok"] == true;

      if (!ok) {
        final err = (resp["error"] ?? resp).toString();
        _setStatus('업데이트 실패: $err', Colors.redAccent);
        // ✅ 명확한 실패 문구
        _showBottomMessage('❌ 정보 업데이트에 실패했습니다.');

        setState(() => isSubmitting = false);
        controller.start();
        return;
      }

      final duplicate = resp["duplicate"] == true;
      final batchId = (resp["batchId"] ?? '').toString();

      setState(() {
        lastDuplicate = duplicate;
        lastBatchId = batchId.isEmpty ? null : batchId;
      });

      if (duplicate) {
        _setStatus('중복 차단됨 (기존 입고건)', Colors.redAccent);
        // ✅ 중복 문구
        _showBottomMessage('⚠️ 이미 입고 처리된 바코드입니다.');
      } else {
        _setStatus('업데이트 성공 (Batch: $batchId)', Colors.green);
        // ✅ 명확한 성공 문구
        _showBottomMessage('✅ 재고 정보가 정상적으로 업데이트되었습니다.');
      }

      reset(keepLastResult: true);
    } catch (e) {
      _setStatus('네트워크 오류가 발생했습니다.', Colors.deepOrange);
      _showBottomMessage('❌ 서버 연결에 실패했습니다. 인터넷 상태를 확인해주세요.');
      setState(() => isSubmitting = false);
      controller.start();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // ✅ 스캐너 영역 UI 렌더링 함수
  Widget _buildScannerBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      margin: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: MobileScanner(
          controller: controller,
          onDetect: onDetect,
        ),
      ),
    );
  }

  // ✅ 정보 확인 및 버튼 영역 UI 렌더링 함수
  Widget _buildInfoPanel() {
    final p = product;
    final l = location;
    final canConfirm = (p != null && l != null && !isSubmitting);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상태 알림창
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 인식 결과 카드
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('스캔 결과', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('📦 제품: ${p != null ? '${p['name']} / ${p['qty']}개' : '대기중...'}', style: TextStyle(color: p != null ? Colors.black : Colors.grey)),
                  const SizedBox(height: 8),
                  Text('📍 위치: ${l != null ? l['locationCode'] : '대기중...'}', style: TextStyle(color: l != null ? Colors.black : Colors.grey)),

                  if (lastBatchId != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: lastDuplicate == true ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        lastDuplicate == true ? '⚠️ 중복 입고 (기존 Batch: $lastBatchId)' : '✅ 입고 완료 (Batch: $lastBatchId)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: lastDuplicate == true ? Colors.red.shade700 : Colors.green.shade700),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 입고 확정 버튼
                  FilledButton.icon(
                    onPressed: canConfirm ? _confirmInbound : null,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    icon: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle),
                    label: Text(isSubmitting ? '업데이트 중...' : '입고 확정', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 12),

                  // 위치 재스캔 버튼
                  OutlinedButton.icon(
                    onPressed: (scanningProduct || isSubmitting) ? null : () {
                      setState(() {
                        location = null;
                        lastBatchId = null;
                        lastDuplicate = null;
                        lastScannedRaw = null;
                      });
                      _setStatus('위치 QR을 다시 스캔하세요', Colors.orange);
                      controller.start();
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('위치만 다시 스캔'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('입고 처리 (스캔)'),
        actions: [
          IconButton(
            onPressed: () => reset(keepLastResult: false),
            icon: const Icon(Icons.refresh),
            tooltip: '초기화',
          ),
        ],
      ),
      // ✅ 기기 화면 크기에 따라 UI 배치를 달리하는 LayoutBuilder
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 720; // 720px 이상이면 태블릿/웹으로 간주

          if (isWide) {
            // 태블릿, 웹 (가로 모드)
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(child: _buildScannerBox()),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _buildInfoPanel(),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // 스마트폰 (세로 모드)
            return Column(
              children: [
                Expanded(
                  flex: 5,
                  child: _buildScannerBox(),
                ),
                Expanded(
                  flex: 6,
                  child: _buildInfoPanel(),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}