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
  // ✅ Apps Script 웹앱 /exec URL
  static const String WEBAPP_URL =AppConfig.webAppUrl;

  final MobileScannerController controller = MobileScannerController();

  Map<String, dynamic>? product; // type=product_pack
  Map<String, dynamic>? location; // type=location
  bool scanningProduct = true; // true: 제품QR 단계, false: 위치QR 단계

  bool isProcessingScan = false; // 연속 스캔 방지
  bool isSubmitting = false; // ✅ 입고 확정 중(네트워크 처리중) 잠금

  // ✅ 화면에 고정 표시할 상태
  String statusText = '대기중';
  Color statusColor = Colors.grey;

  // ✅ 마지막 서버 결과 표시용
  String? lastBatchId;
  bool? lastDuplicate;

  void _setStatus(String text, Color color) {
    if (!mounted) return;
    setState(() {
      statusText = text;
      statusColor = color;
    });
  }

  void _toastOnce(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void reset({bool keepLastResult = false}) {
    setState(() {
      product = null;
      location = null;
      scanningProduct = true;
      isProcessingScan = false;
      isSubmitting = false;

      if (!keepLastResult) {
        lastBatchId = null;
        lastDuplicate = null;
        statusText = '대기중';
        statusColor = Colors.grey;
      } else {
        statusText = '대기중(다음 입고 준비)';
        statusColor = Colors.grey;
      }
    });

    controller.start();
  }

  /// ✅ 리다이렉트(302/303/307/308)까지 따라가며 POST 유지
  Future<Map<String, dynamic>> _postJsonWithRedirect(Map<String, dynamic> payload) async {
    final client = http.Client();
    try {
      Uri current = Uri.parse(WEBAPP_URL);
      final body = jsonEncode(payload);

      for (int i = 0; i < 5; i++) {
        final req = http.Request('POST', current)
          ..headers['Content-Type'] = 'application/json'
          ..headers['Accept'] = 'application/json'
          ..followRedirects = false
          ..body = body;

        final streamed = await client.send(req).timeout(const Duration(seconds: 15));
        final res = await http.Response.fromStream(streamed);

        if (res.statusCode == 200) {
          final dynamic decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) return decoded;
          throw Exception('서버 응답이 JSON이 아님: ${res.body}');
        }

        if (res.statusCode == 302 ||
            res.statusCode == 303 ||
            res.statusCode == 307 ||
            res.statusCode == 308) {
          final loc = res.headers['location'];
          if (loc == null || loc.isEmpty) {
            throw Exception('리다이렉트(Location)가 비어있음: ${res.statusCode} / ${res.body}');
          }
          current = Uri.parse(loc);
          continue;
        }

        throw Exception('HTTP ${res.statusCode} / ${res.body}');
      }

      throw Exception('리다이렉트가 너무 많음(5회 초과).');
    } finally {
      client.close();
    }
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    // ✅ 확정 처리중이면 스캔 이벤트는 전부 무시
    if (isSubmitting) return;

    // ✅ 연속 인식 방지
    if (isProcessingScan) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _toastOnce('이 QR은 JSON이 아니에요. (앱에서 만든 QR만 인식)');
      return;
    }

    setState(() => isProcessingScan = true);

    final type = (data['type'] ?? '').toString();

    // 1) 제품 QR 단계
    if (scanningProduct) {
      if (type != 'product_pack') {
        _toastOnce('제품 QR을 먼저 스캔하세요.');
        setState(() => isProcessingScan = false);
        return;
      }

      final tempId = (data['tempId'] ?? '').toString().trim();
      if (tempId.isEmpty) {
        _toastOnce('이 제품 QR에는 tempId가 없어요. (새로 생성 필요)');
        setState(() => isProcessingScan = false);
        return;
      }

      setState(() {
        product = data;
        scanningProduct = false;
        isProcessingScan = false;
      });
      _setStatus('제품 OK → 위치 QR을 스캔하세요', Colors.blueGrey);
      return;
    }

    // 2) 위치 QR 단계
    if (type != 'location') {
      _toastOnce('위치 QR을 스캔하세요.');
      setState(() => isProcessingScan = false);
      return;
    }

    setState(() {
      location = data;
      isProcessingScan = false;
    });
    _setStatus('위치 OK → 입고 확정을 누르세요', Colors.blueGrey);

    // ✅ 위치까지 찍었으면 카메라 정지(불필요 스캔/토스트 방지)
    controller.stop();
  }

  Future<void> _confirmInbound() async {
    final p = product;
    final l = location;

    if (p == null) {
      _toastOnce('제품 QR을 먼저 스캔하세요.');
      return;
    }
    if (l == null) {
      _toastOnce('위치 QR을 먼저 스캔하세요.');
      return;
    }

    // ✅ 확정 시작: 스캐너 stop + UI 잠금
    setState(() {
      isSubmitting = true;
      lastBatchId = null;
      lastDuplicate = null;
    });
    controller.stop();
    _setStatus('입고 처리중…', Colors.orange);

    try {
      final inbound = <String, dynamic>{
        "time": DateTime.now().toIso8601String(),
        "type": "inbound",

        // 제품QR
        "tempId": p["tempId"],
        "sku": p["sku"],
        "name": p["name"],
        "producer": p["producer"],
        "producedAt": p["producedAt"],
        "qty": p["qty"],
        "weightKg": p["weightKg"],
        "perSheetG": p["perSheetG"],
        "category": p["category"],
        "attrs": p["attrs"],

        // 위치QR
        "locationCode": l["locationCode"],
        "warehouse": l["warehouse"],
        "zone": l["zone"],
        "rack": l["rack"],
        "bin": l["bin"],
      };

      final resp = await _postJsonWithRedirect(inbound);
      debugPrint('INBOUND resp: $resp');

      final ok = resp["ok"] == true;
      if (!ok) {
        final err = (resp["error"] ?? resp).toString();
        _setStatus('실패: $err', Colors.redAccent);
        _toastOnce('입고 실패: $err');

        // 실패면 잠금 해제 + 스캐너 재시작(현재 상태 유지)
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
        _setStatus('중복 차단됨 (batchId: $batchId)', Colors.redAccent);
        _toastOnce('중복 입고라서 차단됨');
      } else {
        _setStatus('입고 완료 (batchId: $batchId)', Colors.green);
        _toastOnce('입고 완료');
      }

      // ✅ 다음 작업 준비 (결과는 화면에 남김)
      reset(keepLastResult: true);
    } catch (e) {
      _setStatus('응답 확인 실패: 네트워크/웹앱 응답 문제', Colors.deepOrange);
      _toastOnce('응답 확인 실패(기록은 됐을 수 있음). 네트워크/웹앱 상태 확인');

      // 다음 시도를 위해 잠금 해제 + 스캐너 재시작
      setState(() => isSubmitting = false);
      controller.start();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepTitle = scanningProduct ? '1) 제품 QR 스캔' : '2) 위치 QR 스캔';

    final p = product;
    final l = location;

    final productText = p == null
        ? '-'
        : '${p['sku'] ?? '-'} / tempId=${p['tempId'] ?? '-'} / qty=${p['qty'] ?? '-'}';

    final locationText = l == null ? '-' : '${l['locationCode'] ?? '-'}';

    final canConfirm = (p != null && l != null && !isSubmitting);

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

      // ✅ 오버플로(노랑/검정 줄무늬) 제거 핵심:
      // - 스캐너는 Expanded로 화면에 맞춰 늘리고
      // - 하단 패널은 SafeArea + SingleChildScrollView로 작아도 안 잘리게
      body: SafeArea(
        child: Column(
          children: [
            // 상단 안내 + 상태
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stepTitle,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (p != null) const Chip(label: Text('제품 OK')),
                      const SizedBox(width: 8),
                      if (l != null) const Chip(label: Text('위치 OK')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(fontWeight: FontWeight.w800, color: statusColor),
                    ),
                  ),
                ],
              ),
            ),

            // 스캐너: 남는 공간을 모두 사용(고정 높이 제거)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    controller: controller,
                    onDetect: onDetect,
                  ),
                ),
              ),
            ),

            // 하단 패널: 작은 화면에서도 안 잘리도록 스크롤 + 하단 SafeArea
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('스캔 결과', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('제품: $productText'),
                        const SizedBox(height: 4),
                        Text('위치: $locationText'),
                        const SizedBox(height: 10),

                        if (lastBatchId != null) ...[
                          Text(
                            lastDuplicate == true
                                ? '중복 차단됨 (기존 batchId): $lastBatchId'
                                : '발급된 batchId: $lastBatchId',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: lastDuplicate == true ? Colors.redAccent : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        FilledButton.icon(
                          onPressed: canConfirm ? _confirmInbound : null,
                          icon: isSubmitting
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(isSubmitting ? '처리중…' : '입고 확정'),
                        ),

                        const SizedBox(height: 8),

                        OutlinedButton.icon(
                          onPressed: (scanningProduct || isSubmitting)
                              ? null
                              : () {
                            setState(() {
                              location = null;
                              lastBatchId = null;
                              lastDuplicate = null;
                            });
                            _setStatus('위치 QR을 다시 스캔하세요', Colors.blueGrey);
                            controller.start();
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('위치만 다시 스캔'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
