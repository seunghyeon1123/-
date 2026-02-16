import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
  // ====== 생산자(단일선택) ======
  final List<String> producers = ['안승탁', '박운서', '이병섭', '이응직'];
  String? selectedProducer;

  // ====== 카테고리(단일선택) ======
  final List<String> categories = ['전체', '대발', '배접', '2.7/3.6/120', '옻지', '인쇄/나염', '기타'];
  String selectedCategory = '전체';

  // ====== 속성태그(복수선택) ======
  final List<String> attributeTags = ['순지', '국내', '백닥', '무표백', '황촉규', '無'];
  final Set<String> selectedAttributes = {};

  // ====== 수량: 기본 100(Pack) + 1~99 다이얼 ======
  int qty = 100; // ✅ 기본 100
  DateTime producedAt = DateTime.now();

  String? batchId;
  String? qrData;
  int dailySerial = 1;

  // ====== 품목(49개) ======
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

  // ====== 카테고리 분류 ======
  String _categoryOf(ProductItem it) {
    final n = it.name;
    if (n.contains('대발') || n.contains('소발')) return '대발';
    if (n.contains('배접')) return '배접';
    if (n.contains('2.7') || n.contains('3.6') || n.contains('120호')) return '2.7/3.6/120';
    if (n.contains('옻지')) return '옻지';
    if (n.contains('나염') || n.contains('인쇄') || n.contains('실크')) return '인쇄/나염';
    return '기타';
  }

  // ====== 현재 카테고리에서 "가능한 속성태그" 계산 ======
  // (selectedCategory 반영 + 태그가 실제 품목명에 존재하는지)
  Set<String> _availableAttributesForCategory() {
    final base = items.where((it) {
      return selectedCategory == '전체' || _categoryOf(it) == selectedCategory;
    }).toList();

    final avail = <String>{};
    for (final tag in attributeTags) {
      if (base.any((it) => it.name.contains(tag))) {
        avail.add(tag);
      }
    }
    return avail;
  }

  // ====== 필터 적용: 카테고리 + 선택된 속성(모두 포함) ======
  List<ProductItem> _applyFilters({Set<String>? attrsOverride}) {
    final attrs = attrsOverride ?? selectedAttributes;
    return items.where((it) {
      final categoryMatch = selectedCategory == '전체' || _categoryOf(it) == selectedCategory;
      if (!categoryMatch) return false;

      for (final tag in attrs) {
        if (!it.name.contains(tag)) return false;
      }
      return true;
    }).toList();
  }

  List<ProductItem> get _filteredItems => _applyFilters();

  // ====== "필터로 인해 품목 0개" 방지 안전장치 ======
  // - 카테고리 변경/태그 변경 시 호출
  void _normalizeFiltersAfterChange() {
    // 1) 현재 카테고리에서 불가능한 속성은 자동 해제
    final avail = _availableAttributesForCategory();
    selectedAttributes.removeWhere((t) => !avail.contains(t));

    // 2) 그래도 0개면, 선택된 속성들을 하나씩 풀어서 복구
    var list = _applyFilters();
    if (list.isEmpty && selectedAttributes.isNotEmpty) {
      final tags = selectedAttributes.toList();
      // 마지막에 선택한 순서까지 알 수 없으니, 일단 뒤에서부터 제거
      for (int i = tags.length - 1; i >= 0; i--) {
        selectedAttributes.remove(tags[i]);
        list = _applyFilters();
        if (list.isNotEmpty) break;
      }
    }

    // 3) 선택 품목이 현재 리스트 밖이면 해제
    final current = _applyFilters();
    if (selectedItem != null && !current.contains(selectedItem)) {
      selectedItem = null;
    }
  }

  // ====== 날짜 ======
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

  String _yyyyMMdd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  String _yyyyMmDdText(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ====== 수량: 1~99 두 휠 ======
  Future<void> _pickQtyTwoWheel() async {
    int current = qty;
    if (current == 100) current = 99;
    current = current.clamp(1, 99);

    int tens = current ~/ 10;
    int ones = current % 10;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: 340,
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
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
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
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
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
                            if (v == 0) v = 1;
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

  // ====== QR 생성 ======
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
    if (!(qty == 100 || (qty >= 1 && qty <= 99))) {
      _toast('수량은 1~99 또는 100(Pack)만 가능합니다.');
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
      selectedAttributes.clear();
      selectedItem = null;
      producedAt = DateTime.now();
      batchId = null;
      qrData = null;
      dailySerial = 1;
      qty = 100; // ✅ 기본 100 복원
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

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  // ====== UI 빌더(입력폼 파트) ======
  Widget _buildFormContent(bool isWebWide) {
    final availAttrs = _availableAttributesForCategory();

    // 현재 필터 리스트 기준으로 드롭다운 구성
    final list = _filteredItems;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('필수 입력', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),

        // 생산자
        const Text('생산자 선택 *', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: producers.map((p) {
            final isSelected = selectedProducer == p;
            return ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(p, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => selectedProducer = p),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // 날짜
        OutlinedButton.icon(
          onPressed: pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text('생산일자: ${_yyyyMmDdText(producedAt)} (변경)'),
        ),

        const SizedBox(height: 12),

        // 카테고리: 2열
        const Text('품목 카테고리', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final itemW = (w - 6) / 2;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: categories.map((cat) {
                final selected = selectedCategory == cat;
                return SizedBox(
                  width: itemW,
                  child: ChoiceChip(
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        selectedCategory = cat;
                        _normalizeFiltersAfterChange();
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 12),

        // 속성 태그: 불가능한 것은 비활성/자동해제
        const Text('속성 필터', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: attributeTags.map((tag) {
            final enabled = availAttrs.contains(tag);
            final selected = selectedAttributes.contains(tag);

            // enabled=false면 선택도 못하게(그리고 이미 선택되어있으면 normalize에서 제거됨)
            return Opacity(
              opacity: enabled ? 1.0 : 0.35,
              child: FilterChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Text(tag, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                selected: selected,
                onSelected: enabled
                    ? (v) {
                  setState(() {
                    if (v) {
                      selectedAttributes.add(tag);
                    } else {
                      selectedAttributes.remove(tag);
                    }
                    _normalizeFiltersAfterChange();
                  });
                }
                    : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // 품목 선택
        DropdownButtonFormField<ProductItem>(
          value: selectedItem,
          decoration: InputDecoration(
            labelText: '품목 선택 *',
            border: const OutlineInputBorder(),
            helperText: list.isEmpty ? '필터 조합으로 선택 가능한 품목이 없습니다. (필터가 자동 조정됩니다)' : null,
          ),
          isExpanded: true,
          items: list.map((it) {
            return DropdownMenuItem<ProductItem>(
              value: it,
              child: Text('${it.name}   (${it.sku})'),
            );
          }).toList(),
          onChanged: (v) => setState(() => selectedItem = v),
        ),

        const SizedBox(height: 12),

        // 수량: 100 기본 + 1~99 다이얼
        const Text('수량', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text('100 (Pack)', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              selected: qty == 100,
              onSelected: (_) => setState(() => qty = 100),
            ),
            ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(
                  qty == 100 ? '1~99 선택' : '선택됨: ${qty.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              selected: qty != 100,
              onSelected: (_) async => _pickQtyTwoWheel(),
            ),
          ],
        ),

        const SizedBox(height: 14),

        FilledButton.icon(
          onPressed: generateQr,
          icon: const Icon(Icons.qr_code_2_outlined),
          label: const Text('QR 생성'),
        ),

        if (!isWebWide) ...[
          const SizedBox(height: 18),
          const Divider(),
          _buildPreviewBlock(),
        ],
      ],
    );
  }

  // ====== UI 빌더(미리보기 파트) ======
  Widget _buildPreviewBlock() {
    if (qrData == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(child: Text('선택 후 [QR 생성]을 누르면 QR이 표시됩니다.')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // 빌드마다 필터/선택 정합성 유지 (카테고리/태그 변경 누락 방지)
    _normalizeFiltersAfterChange();

    return LayoutBuilder(
      builder: (context, c) {
        final isWebWide = c.maxWidth >= 900;

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
          body: SafeArea(
            child: isWebWide
                ? Row(
              children: [
                // 좌: 입력
                Expanded(
                  flex: 6,
                  child: _buildFormContent(true),
                ),
                const VerticalDivider(width: 1),
                // 우: 미리보기(고정)
                Expanded(
                  flex: 5,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('미리보기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _buildPreviewBlock(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
                : _buildFormContent(false),
          ),
        );
      },
    );
  }
}
