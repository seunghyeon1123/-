import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // ✅ 다이얼(휠)용
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProductItem {
  final String name;
  final String sku;
  const ProductItem({required this.name, required this.sku});
}

class ProductQrCreateScreen extends StatefulWidget {
  const ProductQrCreateScreen({super.key});

  @override
  State<ProductQrCreateScreen> createState() => _ProductQrCreateScreenState();
}

class _ProductQrCreateScreenState extends State<ProductQrCreateScreen> {
  // ✅ 생산자 4명
  final List<String> producers = ['안승탁', '박운서', '이병섭', '이응직'];
  String? selectedProducer;

  // ✅ 카테고리
  final List<String> categories = ['전체', '대발', '배접', '2.7/3.6/120', '옻지', '인쇄/나염', '기타'];
  String selectedCategory = '전체';

  // ✅ 수량: 기본 100
  int qty = 100;

  DateTime? producedAt;
  String? batchId;
  String? qrData;

  int dailySerial = 1;

  // ✅ 품목 리스트(49개)
  final List<ProductItem> items = const [
    ProductItem(name: '배접지(140*80)', sku: 'HJ-BJ-140x80'),
    ProductItem(name: '순지 배접지(140*80)', sku: 'HJ-BJ-SJ-140x80'),
    ProductItem(name: '대발지', sku: 'HJ-DB'),
    ProductItem(name: '순지 대발', sku: 'HJ-DB-SJ'),
    ProductItem(name: '무표백 순지 대발', sku: 'HJ-DB-NB-SJ'),
    ProductItem(name: '국내 순지 대발', sku: 'HJ-DB-KR-SJ'),
    ProductItem(name: '무표백 국내 순지 대발', sku: 'HJ-DB-NB-KR-SJ'),
    ProductItem(name: '무표백 국내 순지 대발 (황촉규)', sku: 'HJ-DB-NB-KR-SJ-HC'),
    ProductItem(name: '무표백 국내 순지 대발 (無)', sku: 'HJ-DB-NB-KR-SJ-MU'),
    ProductItem(name: '무표백 국내 순지 대발 (황촉규,無)', sku: 'HJ-DB-NB-KR-SJ-HC-MU'),
    ProductItem(name: '국내 백닥 대발', sku: 'HJ-DB-KR-BD'),
    ProductItem(name: '국내 백닥 대발 (無)', sku: 'HJ-DB-KR-BD-MU'),
    ProductItem(name: '국내 백닥 대발 (황촉규)', sku: 'HJ-DB-KR-BD-HC'),
    ProductItem(name: '국내 백닥 대발 (황촉규,無)', sku: 'HJ-DB-KR-BD-HC-MU'),
    ProductItem(name: '무표백 국내 백닥 대발 (황촉규)', sku: 'HJ-DB-NB-KR-BD-HC'),
    ProductItem(name: '무표백 국내 백닥 대발 (황촉규,無)', sku: 'HJ-DB-NB-KR-BD-HC-MU'),
    ProductItem(name: '무표백 순지 대발 (無)', sku: 'HJ-DB-NB-SJ-MU'),
    ProductItem(name: '무표백 순지 대발 (색)', sku: 'HJ-DB-NB-SJ-CL'),
    ProductItem(name: '무표백 순지 대발 (황촉규)', sku: 'HJ-DB-NB-SJ-HC'),
    ProductItem(name: '호두지', sku: 'HJ-HDJ'),
    ProductItem(name: '백닥 소발(박)', sku: 'HJ-SB-BD-PK'),
    ProductItem(name: '외발지', sku: 'HJ-WB'),
    ProductItem(name: '2.7지', sku: 'HJ-27'),
    ProductItem(name: '순지 2.7지', sku: 'HJ-27-SJ'),
    ProductItem(name: '국내 2.7지', sku: 'HJ-27-KR'),
    ProductItem(name: '백닥 2.7지', sku: 'HJ-27-BD'),
    ProductItem(name: '무표백 3.6지', sku: 'HJ-36-NB'),
    ProductItem(name: '무표백 국내 3.6지', sku: 'HJ-36-NB-KR'),
    ProductItem(name: '백닥 3.6지', sku: 'HJ-36-BD'),
    ProductItem(name: '120호', sku: 'HJ-120'),
    ProductItem(name: '120호 (황촉규)', sku: 'HJ-120-HC'),
    ProductItem(name: '3.6 옻지', sku: 'HJ-36-OT'),
    ProductItem(name: '2.7 옻지', sku: 'HJ-27-OT'),
    ProductItem(name: '120호 옻지', sku: 'HJ-120-OT'),
    ProductItem(name: '창호지', sku: 'HJ-CH'),
    ProductItem(name: '중지', sku: 'HJ-JZ'),
    ProductItem(name: '순지', sku: 'HJ-SJ'),
    ProductItem(name: '지방지', sku: 'HJ-JB'),
    ProductItem(name: '색한지', sku: 'HJ-CLHJ'),
    ProductItem(name: '피지 1합', sku: 'HJ-PI-1H'),
    ProductItem(name: '피지 2합', sku: 'HJ-PI-2H'),
    ProductItem(name: '낙수지', sku: 'HJ-LSJ'),
    ProductItem(name: '꽃나염지', sku: 'HJ-FPR'),
    ProductItem(name: '나염지', sku: 'HJ-PR'),
    ProductItem(name: '글지', sku: 'HJ-GJ'),
    ProductItem(name: '색인쇄지', sku: 'HJ-CPR'),
    ProductItem(name: '실크 스크린지', sku: 'HJ-SS'),
    ProductItem(name: '옻지 40*60', sku: 'HJ-OT-40x60'),
    ProductItem(name: '옻지 50*70', sku: 'HJ-OT-50x70'),
  ];

  ProductItem? selectedItem;

  // ✅ 카테고리 분류 함수(이름 기반)
  String _categoryOf(ProductItem it) {
    final n = it.name;

    if (n.contains('대발') || n.contains('소발')) return '대발';
    if (n.contains('배접')) return '배접';
    if (n.contains('2.7') || n.contains('3.6') || n.contains('120호')) return '2.7/3.6/120';
    if (n.contains('옻지')) return '옻지';
    if (n.contains('나염') || n.contains('인쇄') || n.contains('실크')) return '인쇄/나염';

    // 그 외
    return '기타';
  }

  List<ProductItem> get _filteredItems {
    if (selectedCategory == '전체') return items;
    return items.where((it) => _categoryOf(it) == selectedCategory).toList();
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

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ✅ 1~99 다이얼(휠) 선택 바텀시트
  Future<void> _pickQtyDial() async {
    int temp = qty.clamp(1, 99); // 현재값이 100이면 임시로 99로
    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text('수량 선택 (1~99)', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),

                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: temp - 1),
                    itemExtent: 44,
                    onSelectedItemChanged: (i) {
                      temp = i + 1;
                    },
                    children: List.generate(99, (i) {
                      final v = i + 1;
                      return Center(
                        child: Text(
                          v.toString().padLeft(2, '0'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      );
                    }),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() => qty = temp); // ✅ 확정
                            Navigator.pop(context);
                          },
                          child: const Text('확정'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void generateQr() {
    final producer = (selectedProducer ?? '').trim();
    final item = selectedItem;

    if (producer.isEmpty) {
      _toast('생산자를 선택하세요.');
      return;
    }
    if (producedAt == null) {
      _toast('생산일자를 선택하세요.');
      return;
    }
    if (item == null) {
      _toast('품목을 선택하세요.');
      return;
    }
    if (qty <= 0 || qty > 100) {
      _toast('수량은 1~100만 가능합니다.');
      return;
    }

    final dateStr = _yyyyMMdd(producedAt!);
    final serialStr = dailySerial.toString().padLeft(3, '0');
    final newBatchId = 'B$dateStr-$serialStr';

    final payload = <String, dynamic>{
      "type": "product_pack",
      "producer": producer,
      "producedAt": producedAt!.toIso8601String().substring(0, 10),
      "sku": item.sku,
      "name": item.name,
      "batchId": newBatchId,
      "qty": qty, // ✅ 여기로 고정
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
      selectedProducer = null;
      selectedCategory = '전체';
      selectedItem = null;
      producedAt = null;
      batchId = null;
      qrData = null;
      dailySerial = 1;
      qty = 100; // ✅ 기본 100
    });
  }

  Future<void> printQr() async {
    if (qrData == null) {
      _toast('먼저 QR을 생성하세요.');
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
                pw.Text('SKU: ${selectedItem?.sku ?? "-"}', style: pw.TextStyle(fontSize: 9)),
                pw.Text('Qty: $qty', style: pw.TextStyle(fontSize: 9)),
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

    // ✅ 카테고리 바꾸면 선택 품목이 필터 밖이면 자동 해제
    final currentList = _filteredItems;
    if (selectedItem != null && !currentList.contains(selectedItem)) {
      selectedItem = null;
    }

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
          const SizedBox(height: 10),

          // ✅ 생산자 칩
          const Text('생산자 선택 *', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: producers.map((p) {
              final isSelected = selectedProducer == p;
              return ChoiceChip(
                label: Text(p),
                selected: isSelected,
                onSelected: (_) => setState(() => selectedProducer = p),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(dateText),
          ),

          const SizedBox(height: 12),

          // ✅ 카테고리 칩
          const Text('품목 카테고리', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((c) {
                final selected = selectedCategory == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setState(() => selectedCategory = c),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ 품목 드롭다운(필터 적용)
          DropdownButtonFormField<ProductItem>(
            value: selectedItem,
            decoration: const InputDecoration(
              labelText: '품목 선택 *',
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            items: _filteredItems.map((it) {
              return DropdownMenuItem<ProductItem>(
                value: it,
                child: Text('${it.name}   (${it.sku})'),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedItem = v),
          ),

          const SizedBox(height: 12),

          // ✅ 수량 선택 UI (기본 100 + 다이얼)
          const Text('수량 (최대 100)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('100 (Pack)'),
                selected: qty == 100,
                onSelected: (_) => setState(() => qty = 100),
              ),
              ChoiceChip(
                label: Text(qty == 100 ? '1~99 선택' : '선택됨: ${qty.toString().padLeft(2, '0')}'),
                selected: qty != 100,
                onSelected: (_) async {
                  // ✅ 1~99는 다이얼로 선택
                  await _pickQtyDial();
                },
              ),
            ],
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
            const Center(child: Text('선택 후 [QR 생성]을 누르면 QR이 표시됩니다.')),
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
