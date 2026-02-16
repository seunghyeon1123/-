// lib/screens/product_qr_create_screen.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  // ✅ 수량: 기본 100 (Pack), 아니면 1~99
  int qty = 100;

  // ✅ 생산일자: 기본 오늘
  late DateTime producedAt;

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

  @override
  void initState() {
    super.initState();
    producedAt = DateTime.now();
  }

  // ✅ 카테고리 분류(이름 기반)
  String _categoryOf(ProductItem it) {
    final n = it.name;
    if (n.contains('대발') || n.contains('소발')) return '대발';
    if (n.contains('배접')) return '배접';
    if (n.contains('2.7') || n.contains('3.6') || n.contains('120호')) return '2.7/3.6/120';
    if (n.contains('옻지')) return '옻지';
    if (n.contains('나염') || n.contains('인쇄') || n.contains('실크')) return '인쇄/나염';
    return '기타';
  }

  List<ProductItem> get _filteredItems {
    if (selectedCategory == '전체') return items;
    return items.where((it) => _categoryOf(it) == selectedCategory).toList();
  }

  String _yyyyMMdd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  String _dateText(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: producedAt,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => producedAt = picked);
  }

  // ✅ 1~99: 두자리 다이얼 (십의 자리 / 일의 자리) — 라벨(십/일) 없음
  Future<void> _pickQtyTwoDial() async {
    int tens = (qty == 100 ? 9 : (qty ~/ 10)).clamp(0, 9);
    int ones = (qty == 100 ? 9 : (qty % 10)).clamp(0, 9);

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
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: tens),
                          itemExtent: 44,
                          onSelectedItemChanged: (i) => tens = i,
                          children: List.generate(10, (i) {
                            return Center(
                              child: Text(
                                i.toString(),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                              ),
                            );
                          }),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: ones),
                          itemExtent: 44,
                          onSelectedItemChanged: (i) => ones = i,
                          children: List.generate(10, (i) {
                            return Center(
                              child: Text(
                                i.toString(),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
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
                            int v = tens * 10 + ones;
                            if (v == 0) v = 1; // 00이면 01로 보정
                            if (v > 99) v = 99;
                            setState(() => qty = v);
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
    if (item == null) {
      _toast('품목을 선택하세요.');
      return;
    }
    if (qty < 1 || qty > 100) {
      _toast('수량은 1~100만 가능합니다.');
      return;
    }

    final dateStr = _yyyyMMdd(producedAt);
    final serialStr = dailySerial.toString().padLeft(3, '0');
    final newBatchId = 'B$dateStr-$serialStr';

    final payload = <String, dynamic>{
      "type": "product_pack",
      "producer": producer,
      "producedAt": producedAt.toIso8601String().substring(0, 10),
      "sku": item.sku,
      "name": item.name,
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
      selectedProducer = null;
      selectedCategory = '전체';
      selectedItem = null;
      producedAt = DateTime.now(); // ✅ 리셋 시에도 오늘
      batchId = null;
      qrData = null;
      dailySerial = 1;
      qty = 100;
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

  // =========================
  // ✅ 공통 폼(모바일/웹에서 재사용)
  // =========================
  Widget _buildFormContent() {
    // ✅ 카테고리 바꾸면 선택 품목이 필터 밖이면 자동 해제
    final currentList = _filteredItems;
    if (selectedItem != null && !currentList.contains(selectedItem)) {
      selectedItem = null;
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('필수 입력', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),

        // ✅ 생산자 칩 (간격 촘촘하게)
        const Text('생산자 선택 *', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,     // ✅ 간격 줄임
          runSpacing: 6,  // ✅ 간격 줄임
          children: producers.map((p) {
            final isSelected = selectedProducer == p;
            return ChoiceChip(
              label: Text(p),
              selected: isSelected,
              onSelected: (_) => setState(() => selectedProducer = p),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // ✅ 생산일자: 기본 오늘, 누르면 달력으로 변경
        OutlinedButton.icon(
          onPressed: pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(_dateText(producedAt)),
        ),

        const SizedBox(height: 12),

        // ✅ 카테고리: "가로 2열" 느낌(두 줄로 wrap) + 칩 크게
        const Text('품목 카테고리', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,     // ✅ 칩 사이 간격 줄임
          runSpacing: 6,  // ✅ 줄 간격 줄임 (두 줄로 자연스럽게 감김)
          children: categories.map((c) {
            final selected = selectedCategory == c;
            return ChoiceChip(
              label: Text(c, overflow: TextOverflow.ellipsis),
              selected: selected,
              onSelected: (_) => setState(() => selectedCategory = c),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
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

        // ✅ 수량 선택: 100(Pack) 기본 + 100미만(1~99) 두자리 다이얼
        const Text('수량 (최대 100)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('100 (Pack)'),
              selected: qty == 100,
              onSelected: (_) => setState(() => qty = 100),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            ChoiceChip(
              label: Text(qty == 100 ? '100 미만 선택' : '선택됨: ${qty.toString().padLeft(2, '0')}'),
              selected: qty != 100,
              onSelected: (_) async => _pickQtyTwoDial(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        ],
      ],
    );
  }

  // ✅ QR 패널(웹 우측 / 모바일 하단에 활용)
  Widget _buildQrPanel() {
    if (qrData == null) {
      return const Center(child: Text('아직 생성된 QR이 없습니다.'));
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('생성된 Batch: $batchId', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Center(
                child: QrImageView(
                  data: qrData!,
                  version: QrVersions.auto,
                  size: 260,
                ),
              ),
              const SizedBox(height: 10),
              const Text('QR 내부 데이터(JSON)', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              SelectableText(qrData!),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: printQr,
                icon: const Icon(Icons.print),
                label: const Text('QR 인쇄'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // ✅ 웹/모바일 UI 분기(한 파일에서)
  // =========================
  @override
  Widget build(BuildContext context) {
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;

          // ✅ WEB/DESKTOP: 좌(폼) / 우(QR) 2컬럼
          if (w >= 900) {
            return Row(
              children: [
                SizedBox(
                  width: 520,
                  child: _buildFormContent(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _buildQrPanel(),
                ),
              ],
            );
          }

          // ✅ MOBILE/TABLET: 폼 아래에 QR 패널
          return Column(
            children: [
              Expanded(child: _buildFormContent()),
              SizedBox(
                height: 360,
                child: _buildQrPanel(),
              ),
            ],
          );
        },
      ),
    );
  }
}
