import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

class InboundScanScreen extends StatefulWidget {
  const InboundScanScreen({super.key});

  @override
  State<InboundScanScreen> createState() => _InboundScanScreenState();
}

class _InboundScanScreenState extends State<InboundScanScreen> {
  final MobileScannerController controller = MobileScannerController();

  Map<String, dynamic>? product;   // type=product_pack
  Map<String, dynamic>? location;  // type=location
  bool scanningProduct = true;     // true: 제품QR 단계, false: 위치QR 단계
  bool isProcessing = false;       // 연속 스캔 방지
  bool isSending = false;          // 전송 중 중복 클릭 방지

  // ✅ 너의 Apps Script URL (네가 쓰던 것)
  static const String sheetUrl =
      'https://script.google.com/macros/s/AKfycbxRO0zYqYdz6Wvuk1mTHzWSwSFhsE3BcTqtk8A9-tZU3fmJZB-EWoPScBTuMCwWfQ/exec';

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void reset() {
    setState(() {
      product = null;
      location = null;
      scanningProduct = true;
      isProcessing = false;
      isSending = false;
    });
    controller.start();
  }

  Future<void> sendInboundToGoogleSheet(Map<String, dynamic> inbound) async {
    const url = 'https://script.google.com/macros/s/AKfycbw81rMmPPn6prQbxskqP5jG6orZithi8giJY44jLPfnHNC-5eREKiXZrJm-Ib-A/exec';

    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(inbound),
    );

    if (res.statusCode != 200) {
      throw Exception('Sheet 전송 실패: ${res.statusCode} / ${res.body}');
    }

    final body = (res.body).trim();
    if (body == 'DUPLICATE') {
      throw Exception('이미 입고된 Batch 입니다. (중복 입고 차단)');
    }
    if (body != 'OK') {
      throw Exception('Sheet 응답 오류: $body');
    }
  }


  Future<void> onDetect(BarcodeCapture capture) async {
    if (isProcessing) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _toast('이 QR은 JSON이 아니에요. (우리 앱에서 만든 QR만 인식)');
      return;
    }

    final type = data['type'];
    setState(() => isProcessing = true);

    // ✅ 1) 제품 QR 단계
    if (scanningProduct) {
      if (type != 'product_pack') {
        _toast('제품 QR을 먼저 스캔하세요. (type=product_pack)');
        setState(() => isProcessing = false);
        return;
      }

      setState(() {
        product = data;
        scanningProduct = false; // 다음은 위치QR
        isProcessing = false;
      });

      _toast('제품 QR 인식 완료! 이제 위치 QR을 스캔하세요.');
      return;
    }

    // ✅ 2) 위치 QR 단계
    if (type != 'location') {
      _toast('위치 QR을 스캔하세요. (type=location)');
      setState(() => isProcessing = false);
      return;
    }

    setState(() {
      location = data;
      isProcessing = false;
    });

    // 위치까지 완료되면 카메라 멈춤
    controller.stop();
    _toast('위치 QR 인식 완료! 아래 [입고 확정]을 누르세요.');
  }

  Future<void> confirmInbound() async {
    if (product == null || location == null) return;
    if (isSending) return;

    setState(() => isSending = true);

    try {
      final inbound = <String, dynamic>{
        "time": DateTime.now().toIso8601String(),
        "type": "inbound",

        // 제품QR에서 온 값
        "batchId": product!["batchId"],
        "sku": product!["sku"],
        "name": product!["name"],
        "producer": product!["producer"],
        "producedAt": product!["producedAt"],
        "qty": product!["qty"],

        // 위치QR에서 온 값
        "locationCode": location!["locationCode"],
        "warehouse": location!["warehouse"],
        "zone": location!["zone"],
        "rack": location!["rack"],
        "bin": location!["bin"],
      };

      await sendInboundToGoogleSheet(inbound);

      if (!mounted) return;
      _toast('입고 확정 완료! (구글시트 기록됨)');
      reset();
    } catch (e) {
      if (!mounted) return;
      _toast('입고 전송 실패: $e');
      setState(() => isSending = false);
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

    final productText = product == null
        ? '-'
        : '${product!['sku']} / ${product!['batchId']} / qty=${product!['qty']}';

    final locationText = location == null ? '-' : '${location!['locationCode']}';

    final canConfirm = (product != null && location != null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('입고 처리 (스캔)'),
        actions: [
          IconButton(
            onPressed: reset,
            icon: const Icon(Icons.refresh),
            tooltip: '초기화',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ✅ 상단 안내
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      stepTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (product != null) const Chip(label: Text('제품 OK')),
                  const SizedBox(width: 8),
                  if (location != null) const Chip(label: Text('위치 OK')),
                ],
              ),
            ),

            // ✅ 스캐너
            SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MobileScanner(
                    controller: controller,
                    onDetect: onDetect,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ✅ 하단 패널(결과 + 버튼)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('스캔 결과', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('제품: $productText'),
                      const SizedBox(height: 4),
                      Text('위치: $locationText'),
                      const SizedBox(height: 12),

                      FilledButton.icon(
                        onPressed: canConfirm ? confirmInbound : null,
                        icon: isSending
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(isSending ? '전송 중...' : '입고 확정'),
                      ),

                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed: scanningProduct
                            ? null
                            : () {
                          setState(() {
                            location = null;
                            isSending = false;
                          });
                          controller.start();
                          _toast('위치 QR을 다시 스캔하세요.');
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('위치만 다시 스캔'),
                      ),

                      const SizedBox(height: 8),

                      OutlinedButton.icon(
                        onPressed: scanningProduct
                            ? () {
                          // 제품 단계에서 카메라 멈춰있을 수도 있으니 안전하게 start
                          controller.start();
                          _toast('제품 QR을 스캔하세요.');
                        }
                            : () {
                          // 제품까지 다시 하려면 완전 리셋
                          reset();
                          _toast('처음을 다시 시작합니다. 제품 QR부터 스캔하세요.');
                        },
                        icon: const Icon(Icons.restart_alt),
                        label: Text(scanningProduct ? '스캔 재개' : '처음부터 다시'),
                      ),
                    ],
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
