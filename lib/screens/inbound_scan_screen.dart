import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
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

  void reset() {
    setState(() {
      product = null;
      location = null;
      scanningProduct = true;
      isProcessing = false;
    });
    controller.start();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> onDetect(BarcodeCapture capture) async {
    if (isProcessing) return; // ✅ 연속 인식 방지
    final raw = capture.barcodes.firstOrNull?.rawValue;
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

    // 위치까지 완료되면 카메라 일단 멈춰도 됨(선택)
    controller.stop();

    _toast('위치 QR 인식 완료! 이제 입고 확정 버튼을 누르세요.');
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

    final locationText = location == null
        ? '-'
        : '${location!['locationCode']}';

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

            // ✅ 스캐너는 고정 높이로 (아래 패널이 반드시 보이게)
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

            // ✅ 하단 패널(결과 + 버튼) — 항상 보이게
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
                        onPressed: canConfirm
                            ? () {
                          // ✅ 지금은 MVP: 확인만
                          final sku = product!['sku'];
                          final batchId = product!['batchId'];
                          final loc = location!['locationCode'];

                          _toast('입고 완료(MVP): $sku / $batchId → $loc');
                          reset();
                        }
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('입고 확정'),
                      ),

                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: scanningProduct
                            ? null
                            : () {
                          // 위치만 다시 스캔하고 싶을 때
                          setState(() {
                            location = null;
                          });
                          controller.start();
                          _toast('위치 QR을 다시 스캔하세요.');
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('위치만 다시 스캔'),
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
