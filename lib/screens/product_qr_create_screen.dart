import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProductQrCreateScreen extends StatefulWidget {
  const ProductQrCreateScreen({super.key});

  @override
  State<ProductQrCreateScreen> createState() => _ProductQrCreateScreenState();
}

class _ProductQrCreateScreenState extends State<ProductQrCreateScreen> {
  final producerCtrl = TextEditingController();
  final skuCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '30');

  DateTime? producedAt;
  String? batchId;
  String? qrData;

  int dailySerial = 1;

  @override
  void dispose() {
    producerCtrl.dispose();
    skuCtrl.dispose();
    nameCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: producedAt ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => producedAt = picked);
  }

  String _yyyyMMdd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  void generateQr() {
    final producer = producerCtrl.text.trim();
    final sku = skuCtrl.text.trim();
    final name = nameCtrl.text.trim();
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;

    if (producer.isEmpty || sku.isEmpty || name.isEmpty || producedAt == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생산자 / SKU / 품목명 / 생산일자 / 수량(1 이상)은 필수입니다.')),
      );
      return;
    }

    final dateStr = _yyyyMMdd(producedAt!);
    final serialStr = dailySerial.toString().padLeft(3, '0');
    final newBatchId = 'B$dateStr-$serialStr';

    final payload = <String, dynamic>{
      "type": "product_pack",
      "producer": producer,
      "producedAt": producedAt!.toIso8601String().substring(0, 10),
      "sku": sku,
      "name": name,
      "batchId": newBatchId,
      "qty": qty,
      "version": 1,
    };

    setState(() {
      batchId = newBatchId;
      qrData = jsonEncode(payload);
      dailySerial += 1;
    });
  }

  void resetForm() {
    setState(() {
      producerCtrl.clear();
      skuCtrl.clear();
      nameCtrl.clear();
      qtyCtrl.text = '30';
      producedAt = null;
      batchId = null;
      qrData = null;
      dailySerial = 1;
    });
  }

  // ✅ 반드시 State 클래스 안에 있어야 함
  Future<void> printQr() async {
    if (qrData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 QR을 생성하세요.')),
      );
      return;
    }

    final doc = pw.Document();

    // ✅ 소형 프린터(58mm 폭) 라벨 느낌
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
                pw.Text('제품 라벨', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData!,
                  width: 120,
                  height: 120,
                ),
                pw.SizedBox(height: 6),
                pw.Text('Batch: ${batchId ?? "-"}', style: pw.TextStyle(fontSize: 9)),
                pw.Text('SKU: ${skuCtrl.text}', style: pw.TextStyle(fontSize: 9)),
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

  @override
  Widget build(BuildContext context) {
    final dateText = producedAt == null
        ? '생산일자 선택'
        : '${producedAt!.year}-${producedAt!.month.toString().padLeft(2, '0')}-${producedAt!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('제품 등록 → QR 생성'),
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
          const Text('필수 입력', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: producerCtrl,
            decoration: const InputDecoration(
              labelText: '생산자(회사/담당자) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(dateText),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: skuCtrl,
            decoration: const InputDecoration(
              labelText: 'SKU/품목코드 *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: '품목명 *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '수량(qty) *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: generateQr,
            icon: const Icon(Icons.qr_code_2_outlined),
            label: const Text('QR 생성'),
          ),
          const SizedBox(height: 18),
          const Divider(),

          if (qrData == null) ...[
            const SizedBox(height: 18),
            const Center(child: Text('입력 후 [QR 생성]을 누르면 QR이 표시됩니다.')),
          ] else ...[
            const SizedBox(height: 8),
            Text('생성된 Batch: $batchId', style: const TextStyle(fontWeight: FontWeight.w700)),
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

            // ✅ 버튼은 build()의 children 안에 있어야 함
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: printQr,
              icon: const Icon(Icons.print),
              label: const Text('QR 인쇄'),
            ),
          ],
        ],
      ),
    );
  }
}
