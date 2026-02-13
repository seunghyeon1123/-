import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


class LocationQrCreateScreen extends StatefulWidget {
  const LocationQrCreateScreen({super.key});

  @override
  State<LocationQrCreateScreen> createState() => _LocationQrCreateScreenState();
}

class _LocationQrCreateScreenState extends State<LocationQrCreateScreen> {
  Future<void> printLocationQr() async {
    if (qrData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 위치 QR을 생성하세요.')),
      );
      return;
    }

    final doc = pw.Document();
    final pageFormat = PdfPageFormat(58 * PdfPageFormat.mm, 60 * PdfPageFormat.mm);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('위치 라벨', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData!,
                  width: 120,
                  height: 120,
                ),
                pw.SizedBox(height: 6),
                pw.Text('LOC: ${locationCode ?? "-"}', style: pw.TextStyle(fontSize: 9)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  final warehouseCtrl = TextEditingController(text: 'WH1'); // 창고
  final zoneCtrl = TextEditingController(text: 'A'); // 구역
  final rackCtrl = TextEditingController(text: '01'); // 랙
  final binCtrl = TextEditingController(text: '01'); // 빈/칸

  String? locationCode; // 사람이 읽는 코드 (예: WH1-A-01-01)
  String? qrData;       // QR에 들어갈 JSON

  @override
  void dispose() {
    warehouseCtrl.dispose();
    zoneCtrl.dispose();
    rackCtrl.dispose();
    binCtrl.dispose();
    super.dispose();
  }

  void generateLocationQr() {
    final wh = warehouseCtrl.text.trim();
    final zone = zoneCtrl.text.trim();
    final rack = rackCtrl.text.trim();
    final bin = binCtrl.text.trim();

    if (wh.isEmpty || zone.isEmpty || rack.isEmpty || bin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('창고/구역/랙/빈은 모두 필수입니다.')),
      );
      return;
    }

    final code = '$wh-$zone-$rack-$bin';

    // ✅ 생산QR과 헷갈리지 않게 type을 "location"으로 고정
    final payload = <String, dynamic>{
      "type": "location",
      "warehouse": wh,
      "zone": zone,
      "rack": rack,
      "bin": bin,
      "locationCode": code,
      "version": 1,
    };

    setState(() {
      locationCode = code;
      qrData = jsonEncode(payload);
    });
  }

  void resetForm() {
    setState(() {
      warehouseCtrl.text = 'WH1';
      zoneCtrl.text = 'A';
      rackCtrl.text = '01';
      binCtrl.text = '01';
      locationCode = null;
      qrData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 QR 생성'),
        actions: [
          IconButton(
            onPressed: resetForm,
            icon: const Icon(Icons.refresh),
            tooltip: '초기화',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('위치 정보 입력', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          TextField(
            controller: warehouseCtrl,
            decoration: const InputDecoration(
              labelText: '창고 코드 (예: WH1) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: zoneCtrl,
            decoration: const InputDecoration(
              labelText: '구역 (예: A) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: rackCtrl,
            decoration: const InputDecoration(
              labelText: '랙 (예: 01) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: binCtrl,
            decoration: const InputDecoration(
              labelText: '빈/칸 (예: 01) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          FilledButton.icon(
            onPressed: generateLocationQr,
            icon: const Icon(Icons.qr_code_2_outlined),
            label: const Text('위치 QR 생성'),
          ),

          const SizedBox(height: 18),
          const Divider(),

          if (qrData == null) ...[
            const SizedBox(height: 18),
            const Center(child: Text('입력 후 [위치 QR 생성]을 누르면 QR이 표시됩니다.')),
          ] else ...[
            const SizedBox(height: 8),
            Text('위치 코드: $locationCode', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: qrData!,
                version: QrVersions.auto,
                size: 260,
              ),
            ),
            const SizedBox(height: 12),
            const Text('QR 내부 데이터(JSON)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SelectableText(qrData!),
          ],
        ],
      ),
    );
  }
}
