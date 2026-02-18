import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  // ===== 생산자 =====
  final List<String> producers = ['안승탁', '박운서', '이병섭', '이응직'];
  String? selectedProducer;

  // ===== 날짜(기본: 오늘) =====
  DateTime producedAt = DateTime.now();

  // ===== 수량(기본: 100) =====
  int qty = 100;

  // ===== 무게(계산기 방식 누적) =====
  final double baseWeightKg = 3.0; // 기준값(표시용 센터)
  double weightAdjustment = 0.0;   // +/- 누적

  double get currentWeightKg =>
      double.parse((baseWeightKg + weightAdjustment).toStringAsFixed(2));

  // 1장당 g: 소수점 둘째자리 반올림 → 소수 1자리 표시
  double get perSheetWeightG {
    final q = qty <= 0 ? 1 : qty;
    final g = (currentWeightKg * 1000) / q;
    return (g * 10).roundToDouble() / 10; // 소수 1자리
  }

  // ===== batch / qr =====
  String? batchId;
  String? qrData;
  int dailySerial = 1;

  // ===== 품목 리스트(사용자가 준 49개 버전 유지 가능) =====
  // 여기서는 네가 이미 쓰던 SKU 규칙을 최대한 유지해서 넣었고,
  // 필요하면 목록을 그대로 49개로 확장해도 필터 로직은 그대로 작동함.
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

  // ===== 카테고리 =====
  final List<String> categories = ['전체', '대발', '배접', '2.7/3.6/120', '옻지', '인쇄/나염', '기타'];
  String selectedCategory = '전체';

  // ===== 속성 태그(상위/하위) =====
  final List<String> upperTags = ['순지', '국내', '백닥', '무표백'];
  final List<String> lowerTags = ['황촉규', '無'];

  final Set<String> selectedUpper = {};
  final Set<String> selectedLower = {};

  // ====== 유틸 ======
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _yyyyMMdd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  // 카테고리 분류(이름 기반)
  String _categoryOf(ProductItem it) {
    final n = it.name;
    if (n.contains('대발') || n.contains('소발')) return '대발';
    if (n.contains('배접')) return '배접';
    if (n.contains('2.7') || n.contains('3.6') || n.contains('120호')) return '2.7/3.6/120';
    if (n.contains('옻지')) return '옻지';
    if (n.contains('나염') || n.contains('인쇄') || n.contains('실크')) return '인쇄/나염';
    return '기타';
  }

  // 아이템이 특정 속성 태그를 "가지고 있는지" (이름 기반)
  bool _hasTag(ProductItem it, String tag) {
    final n = it.name;
    switch (tag) {
      case '순지':
        return n.contains('순지');
      case '국내':
        return n.contains('국내');
      case '백닥':
        return n.contains('백닥');
      case '무표백':
        return n.contains('무표백');
      case '황촉규':
        return n.contains('황촉규');
      case '無':
        return n.contains('無');
      default:
        return false;
    }
  }

  // 현재 선택(카테고리 + 상위 + 하위)로 필터링된 리스트
  List<ProductItem> _applyFilter({
    String? category,
    Set<String>? upper,
    Set<String>? lower,
  }) {
    final cat = category ?? selectedCategory;
    final up = upper ?? selectedUpper;
    final lo = lower ?? selectedLower;

    return items.where((it) {
      if (cat != '전체' && _categoryOf(it) != cat) return false;

      for (final t in up) {
        if (!_hasTag(it, t)) return false;
      }
      for (final t in lo) {
        if (!_hasTag(it, t)) return false;
      }
      return true;
    }).toList();
  }

  // 특정 태그를 추가했을 때 "유효(=결과가 1개 이상)" 한지 검사
  bool _canAddUpper(String tag) {
    final nextUpper = {...selectedUpper, tag};
    return _applyFilter(upper: nextUpper).isNotEmpty;
  }

  bool _canAddLower(String tag) {
    final nextLower = {...selectedLower, tag};
    return _applyFilter(lower: nextLower).isNotEmpty;
  }

  // 카테고리를 바꿨을 때 유효한지(=결과가 1개 이상)
  bool _canSelectCategory(String cat) {
    return _applyFilter(category: cat).isNotEmpty;
  }

  // 필터 변경 후 드롭다운 선택이 유효하지 않으면 해제
  void _ensureSelectedItemValid() {
    final list = _applyFilter();
    if (selectedItem != null && !list.contains(selectedItem)) {
      selectedItem = null;
    }
  }

  // ===== 날짜 선택 =====
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

  // ===== 수량 다이얼 (1~99 두 자리) =====
  Future<void> _pickQtyDial() async {
    int temp = qty.clamp(1, 99);
    int tens = (temp ~/ 10);
    int ones = (temp % 10);

    await showModalBottomSheet(
      context: context,
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
                          itemExtent: 44,
                          scrollController: FixedExtentScrollController(initialItem: tens),
                          onSelectedItemChanged: (i) => tens = i,
                          children: List.generate(10, (i) {
                            return Center(
                              child: Text(
                                '$i',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                              ),
                            );
                          }),
                        ),
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          itemExtent: 44,
                          scrollController: FixedExtentScrollController(initialItem: ones),
                          onSelectedItemChanged: (i) => ones = i,
                          children: List.generate(10, (i) {
                            return Center(
                              child: Text(
                                '$i',
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
                            final v = tens * 10 + ones;
                            if (v <= 0) {
                              _toast('수량은 1 이상이어야 합니다.');
                              return;
                            }
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

  // ===== QR 생성 =====
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
    if (qty <= 0 || qty > 100) {
      _toast('수량은 1~100만 가능합니다.');
      return;
    }

    final dateStr = _yyyyMMdd(producedAt);
    final serialStr = dailySerial.toString().padLeft(3, '0');
    final newBatch = 'B$dateStr-$serialStr';

    final payload = <String, dynamic>{
      "type": "product_pack",
      "producer": producer,
      "producedAt": producedAt.toIso8601String().substring(0, 10),
      "sku": item.sku,
      "name": item.name,
      "batchId": newBatch,
      "qty": qty,
      "weightTotalKg": currentWeightKg,                    // 총무게(선택)
      "weightPerSheetG": double.parse(perSheetWeightG.toStringAsFixed(1)), // 1장당 g
      "tagsUpper": selectedUpper.toList(),
      "tagsLower": selectedLower.toList(),
      "version": 1,
    };

    setState(() {
      batchId = newBatch;
      qrData = jsonEncode(payload);
      dailySerial += 1;
    });
  }

  void resetForm() {
    setState(() {
      selectedProducer = null;
      producedAt = DateTime.now();
      qty = 100;
      weightAdjustment = 0.0;

      selectedCategory = '전체';
      selectedUpper.clear();
      selectedLower.clear();

      selectedItem = null;
      batchId = null;
      qrData = null;
      dailySerial = 1;
    });
  }

  // ===== 인쇄 =====
  Future<void> printQr() async {
    if (qrData == null) {
      _toast('먼저 QR을 생성하세요.');
      return;
    }

    final doc = pw.Document();
    final format = PdfPageFormat(58 * PdfPageFormat.mm, 60 * PdfPageFormat.mm);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) {
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
                pw.Text('W: ${currentWeightKg.toStringAsFixed(2)}kg', style: pw.TextStyle(fontSize: 9)),
                pw.Text('1ea: ${perSheetWeightG.toStringAsFixed(1)}g', style: pw.TextStyle(fontSize: 9)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  // ===== 무게 버튼(누를 때마다 누적) =====
  Widget _weightBtn(double delta) {
    final label = delta > 0 ? '+${delta.toStringAsFixed(1)}' : delta.toStringAsFixed(1);
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: () => setState(() => weightAdjustment += delta),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final isWide = kIsWeb || MediaQuery.of(context).size.width >= 900;

    // 필터 변경 시 드롭다운 값 유효성 유지
    _ensureSelectedItemValid();

    final filtered = _applyFilter();

    final dateText =
        '${producedAt.year}-${producedAt.month.toString().padLeft(2, '0')}-${producedAt.day.toString().padLeft(2, '0')}';

    Widget form = ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // ===== 필수 입력 =====
        const Text('필수 입력', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),

        // 생산자
        const Text('생산자 *', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: producers.map((p) {
            final sel = selectedProducer == p;
            return ChoiceChip(
              label: Text(p),
              selected: sel,
              onSelected: (_) => setState(() => selectedProducer = p),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // 생산일자
        const Text('생산일자 *', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(dateText),
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 10),

        // ===== 품목 필터 =====
        const Text('품목 선택', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),

        // 카테고리 (가로 2열 Grid)
        const Text('품목 카테고리', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3.2,
          children: categories.map((c) {
            final selected = selectedCategory == c;
            final enabled = _canSelectCategory(c);

            return ChoiceChip(
              label: Center(child: Text(c, overflow: TextOverflow.ellipsis)),
              selected: selected,
              onSelected: enabled
                  ? (_) {
                setState(() => selectedCategory = c);
              }
                  : null,
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // 상위 속성
        const Text('상위 속성', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: upperTags.map((t) {
            final isSelected = selectedUpper.contains(t);
            final canAdd = isSelected ? true : _canAddUpper(t);

            return ChoiceChip(
              label: Text(t),
              selected: isSelected,
              onSelected: canAdd
                  ? (v) {
                setState(() {
                  // 토글
                  if (isSelected) {
                    selectedUpper.remove(t);
                  } else {
                    // 결과 0개 되는 선택은 방지
                    if (!_canAddUpper(t)) return;
                    selectedUpper.add(t);
                  }
                  _ensureSelectedItemValid();
                });
              }
                  : null,
            );
          }).toList(),
        ),

        const SizedBox(height: 10),

        // 하위 속성
        const Text('하위 속성', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: lowerTags.map((t) {
            final isSelected = selectedLower.contains(t);
            final canAdd = isSelected ? true : _canAddLower(t);

            return ChoiceChip(
              label: Text(t),
              selected: isSelected,
              onSelected: canAdd
                  ? (v) {
                setState(() {
                  if (isSelected) {
                    selectedLower.remove(t);
                  } else {
                    if (!_canAddLower(t)) return;
                    selectedLower.add(t);
                  }
                  _ensureSelectedItemValid();
                });
              }
                  : null,
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // 드롭다운
        DropdownButtonFormField<ProductItem>(
          value: selectedItem,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: '품목 * (현재 ${filtered.length}개)',
            border: const OutlineInputBorder(),
          ),
          items: filtered.map((it) {
            return DropdownMenuItem<ProductItem>(
              value: it,
              child: Text('${it.name}   (${it.sku})'),
            );
          }).toList(),
          onChanged: filtered.isEmpty
              ? null
              : (v) => setState(() => selectedItem = v),
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 10),

        // ===== 수량 =====
        const Text('수량 (최대 100)', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('100 (Pack)'),
              selected: qty == 100,
              onSelected: (_) => setState(() => qty = 100),
            ),
            ChoiceChip(
              label: Text(qty == 100 ? '100미만 선택' : '선택됨: ${qty.toString().padLeft(2, '0')}'),
              selected: qty != 100,
              onSelected: (_) async {
                await _pickQtyDial();
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ===== 무게 =====
        const Text('무게 (kg)  |  1장당(g) 자동 계산', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),

        // 좌: -, 가운데: 3.0(표시), 우: +
        Row(
          children: [
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _weightBtn(-0.3),
                  _weightBtn(-0.2),
                  _weightBtn(-0.1),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: Column(
                children: [
                  Text(
                    currentWeightKg.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '1장: ${perSheetWeightG.toStringAsFixed(1)} g',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _weightBtn(0.1),
                  _weightBtn(0.2),
                  _weightBtn(0.3),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        FilledButton.icon(
          onPressed: () {
            if (selectedProducer == null) {
              _toast('생산자를 선택하세요.');
              return;
            }
            if (selectedItem == null) {
              _toast('품목을 선택하세요.');
              return;
            }
            generateQr();
          },
          icon: const Icon(Icons.qr_code_2_outlined),
          label: const Text('QR 생성'),
        ),

        const SizedBox(height: 16),
        const Divider(),

        if (qrData == null) ...[
          const SizedBox(height: 12),
          const Center(child: Text('선택 후 [QR 생성]을 누르면 QR이 표시됩니다.')),
        ] else ...[
          const SizedBox(height: 10),
          Text('생성된 Batch: $batchId', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Center(
            child: QrImageView(
              data: qrData!,
              version: QrVersions.auto,
              size: 240,
            ),
          ),
          const SizedBox(height: 12),
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
      ],
    );

    // 웹/와이드: 오른쪽에 QR 미리보기 분리(선택)
    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('제품 등록 → QR 생성'),
          actions: [
            IconButton(onPressed: resetForm, icon: const Icon(Icons.refresh), tooltip: '초기화'),
          ],
        ),
        body: Row(
          children: [
            Expanded(flex: 3, child: form),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: qrData == null
                        ? const Center(child: Text('QR 미리보기'))
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Batch: $batchId', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        QrImageView(data: qrData!, size: 320),
                        const SizedBox(height: 10),
                        Text('Qty: $qty | 1장: ${perSheetWeightG.toStringAsFixed(1)}g'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 모바일
    return Scaffold(
      appBar: AppBar(
        title: const Text('제품 등록 → QR 생성'),
        actions: [
          IconButton(onPressed: resetForm, icon: const Icon(Icons.refresh), tooltip: '초기화'),
        ],
      ),
      body: form,
    );
  }
}
