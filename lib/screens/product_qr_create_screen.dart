import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // 휠(다이얼)
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:math';

class ProductItem {
  final String name;
  final String sku;
  final String category; // 상위 카테고리
  final Set<String> attrs; // 하위 속성(복수)

  const ProductItem({
    required this.name,
    required this.sku,
    required this.category,
    required this.attrs,
  });
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

  // ✅ 상위 카테고리
  final List<String> categories = const ['전체', '대발', '배접', '2.7/3.6/120', '옻지', '인쇄/나염', '기타'];
  String selectedCategory = '전체';

  // ✅ 하위 속성(복수 선택)
  // 요청: [순지], [국내], [백닥], [무표백], [황촉규], [無] (+ 기존에 있던 색/옻 등)
  final List<String> allAttrs = const ['순지', '국내', '백닥', '무표백', '황촉규', '無', '색', '옻'];
  final Set<String> selectedAttrs = <String>{};

  // ✅ 수량 (기본 100)
  int qty = 100;

  // ✅ 무게(총중량 kg) — 어떤 수량이든 선택 가능, 1장당 g 자동 계산
  double weightKg = 3.0;

  DateTime? producedAt; // 기본 오늘
  String? batchId;
  String? qrData;
  int dailySerial = 1;

  // ✅ 품목 리스트 (49개) + category/attrs 메타데이터 포함
  // attrs 규칙(단순/실무용):
  // - "순지" 포함 → '순지'
  // - "국내" 포함 → '국내'
  // - "백닥" 포함 → '백닥'
  // - "무표백" 포함 → '무표백'
  // - "황촉규" 포함 → '황촉규'
  // - "(無)" 또는 "無" 포함 → '無'
  // - "(색)" 또는 "색" 포함(색한지/무표백 ... (색)) → '색'
  // - "옻지" 포함 → '옻'
  final List<ProductItem> items = const [
    ProductItem(name: '배접지(140*80)', sku: 'HJ-BJ-140x80', category: '배접', attrs: {}),
    ProductItem(name: '순지 배접지(140*80)', sku: 'HJ-BJ-SJ-140x80', category: '배접', attrs: {'순지'}),

    ProductItem(name: '대발지', sku: 'HJ-DB', category: '대발', attrs: {}),
    ProductItem(name: '순지 대발', sku: 'HJ-DB-SJ', category: '대발', attrs: {'순지'}),
    ProductItem(name: '무표백 순지 대발', sku: 'HJ-DB-NB-SJ', category: '대발', attrs: {'무표백', '순지'}),
    ProductItem(name: '국내 순지 대발', sku: 'HJ-DB-KR-SJ', category: '대발', attrs: {'국내', '순지'}),
    ProductItem(name: '무표백 국내 순지 대발', sku: 'HJ-DB-NB-KR-SJ', category: '대발', attrs: {'무표백', '국내', '순지'}),

    ProductItem(name: '무표백 국내 순지 대발 (황촉규)', sku: 'HJ-DB-NB-KR-SJ-HC', category: '대발', attrs: {'무표백', '국내', '순지', '황촉규'}),
    ProductItem(name: '무표백 국내 순지 대발 (無)', sku: 'HJ-DB-NB-KR-SJ-MU', category: '대발', attrs: {'무표백', '국내', '순지', '無'}),
    ProductItem(name: '무표백 국내 순지 대발 (황촉규,無)', sku: 'HJ-DB-NB-KR-SJ-HC-MU', category: '대발', attrs: {'무표백', '국내', '순지', '황촉규', '無'}),

    ProductItem(name: '국내 백닥 대발', sku: 'HJ-DB-KR-BD', category: '대발', attrs: {'국내', '백닥'}),
    ProductItem(name: '국내 백닥 대발 (無)', sku: 'HJ-DB-KR-BD-MU', category: '대발', attrs: {'국내', '백닥', '無'}),
    ProductItem(name: '국내 백닥 대발 (황촉규)', sku: 'HJ-DB-KR-BD-HC', category: '대발', attrs: {'국내', '백닥', '황촉규'}),
    ProductItem(name: '국내 백닥 대발 (황촉규,無)', sku: 'HJ-DB-KR-BD-HC-MU', category: '대발', attrs: {'국내', '백닥', '황촉규', '無'}),

    ProductItem(name: '무표백 국내 백닥 대발 (황촉규)', sku: 'HJ-DB-NB-KR-BD-HC', category: '대발', attrs: {'무표백', '국내', '백닥', '황촉규'}),
    ProductItem(name: '무표백 국내 백닥 대발 (황촉규,無)', sku: 'HJ-DB-NB-KR-BD-HC-MU', category: '대발', attrs: {'무표백', '국내', '백닥', '황촉규', '無'}),

    ProductItem(name: '무표백 순지 대발 (無)', sku: 'HJ-DB-NB-SJ-MU', category: '대발', attrs: {'무표백', '순지', '無'}),
    ProductItem(name: '무표백 순지 대발 (색)', sku: 'HJ-DB-NB-SJ-CL', category: '대발', attrs: {'무표백', '순지', '색'}),
    ProductItem(name: '무표백 순지 대발 (황촉규)', sku: 'HJ-DB-NB-SJ-HC', category: '대발', attrs: {'무표백', '순지', '황촉규'}),

    ProductItem(name: '호두지', sku: 'HJ-HDJ', category: '기타', attrs: {}),
    ProductItem(name: '백닥 소발(박)', sku: 'HJ-SB-BD-PK', category: '대발', attrs: {'백닥'}),
    ProductItem(name: '외발지', sku: 'HJ-WB', category: '기타', attrs: {}),

    ProductItem(name: '2.7지', sku: 'HJ-27', category: '2.7/3.6/120', attrs: {}),
    ProductItem(name: '순지 2.7지', sku: 'HJ-27-SJ', category: '2.7/3.6/120', attrs: {'순지'}),
    ProductItem(name: '국내 2.7지', sku: 'HJ-27-KR', category: '2.7/3.6/120', attrs: {'국내'}),
    ProductItem(name: '백닥 2.7지', sku: 'HJ-27-BD', category: '2.7/3.6/120', attrs: {'백닥'}),

    ProductItem(name: '무표백 3.6지', sku: 'HJ-36-NB', category: '2.7/3.6/120', attrs: {'무표백'}),
    ProductItem(name: '무표백 국내 3.6지', sku: 'HJ-36-NB-KR', category: '2.7/3.6/120', attrs: {'무표백', '국내'}),
    ProductItem(name: '백닥 3.6지', sku: 'HJ-36-BD', category: '2.7/3.6/120', attrs: {'백닥'}),

    ProductItem(name: '120호', sku: 'HJ-120', category: '2.7/3.6/120', attrs: {}),
    ProductItem(name: '120호 (황촉규)', sku: 'HJ-120-HC', category: '2.7/3.6/120', attrs: {'황촉규'}),

    ProductItem(name: '3.6 옻지', sku: 'HJ-36-OT', category: '옻지', attrs: {'옻'}),
    ProductItem(name: '2.7 옻지', sku: 'HJ-27-OT', category: '옻지', attrs: {'옻'}),
    ProductItem(name: '120호 옻지', sku: 'HJ-120-OT', category: '옻지', attrs: {'옻'}),

    ProductItem(name: '창호지', sku: 'HJ-CH', category: '기타', attrs: {}),
    ProductItem(name: '중지', sku: 'HJ-JZ', category: '기타', attrs: {}),
    ProductItem(name: '순지', sku: 'HJ-SJ', category: '기타', attrs: {'순지'}),
    ProductItem(name: '지방지', sku: 'HJ-JB', category: '기타', attrs: {}),
    ProductItem(name: '색한지', sku: 'HJ-CLHJ', category: '기타', attrs: {'색'}),

    ProductItem(name: '피지 1합', sku: 'HJ-PI-1H', category: '기타', attrs: {}),
    ProductItem(name: '피지 2합', sku: 'HJ-PI-2H', category: '기타', attrs: {}),
    ProductItem(name: '낙수지', sku: 'HJ-LSJ', category: '기타', attrs: {}),

    ProductItem(name: '꽃나염지', sku: 'HJ-FPR', category: '인쇄/나염', attrs: {}),
    ProductItem(name: '나염지', sku: 'HJ-PR', category: '인쇄/나염', attrs: {}),
    ProductItem(name: '글지', sku: 'HJ-GJ', category: '인쇄/나염', attrs: {}),
    ProductItem(name: '색인쇄지', sku: 'HJ-CPR', category: '인쇄/나염', attrs: {}),
    ProductItem(name: '실크 스크린지', sku: 'HJ-SS', category: '인쇄/나염', attrs: {}),

    ProductItem(name: '옻지 40*60', sku: 'HJ-OT-40x60', category: '옻지', attrs: {'옻'}),
    ProductItem(name: '옻지 50*70', sku: 'HJ-OT-50x70', category: '옻지', attrs: {'옻'}),
  ];

  ProductItem? selectedItem;

  @override
  void initState() {
    super.initState();
    producedAt = DateTime.now(); // ✅ 기본 오늘
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  // ✅ 현재 상위카테고리에서 실제로 존재하는 속성만 추출 (없는 속성은 비활성)
  Set<String> get _availableAttrsInCurrentCategory {
    final base = (selectedCategory == '전체')
        ? items
        : items.where((it) => it.category == selectedCategory);
    final s = <String>{};
    for (final it in base) {
      s.addAll(it.attrs);
    }
    return s;
  }

  // ✅ 현재 선택(상위+하위)로 필터링된 품목 리스트
  List<ProductItem> get _filteredItems {
    Iterable<ProductItem> base = items;

    if (selectedCategory != '전체') {
      base = base.where((it) => it.category == selectedCategory);
    }

    if (selectedAttrs.isNotEmpty) {
      // 선택 속성은 모두 포함해야 함(AND)
      base = base.where((it) => selectedAttrs.every((a) => it.attrs.contains(a)));
    }

    return base.toList();
  }

  // ✅ 하위 속성 토글(불가능 조합이면 적용하지 않고 차단)
  void _toggleAttr(String a) {
    final next = <String>{...selectedAttrs};
    if (next.contains(a)) {
      next.remove(a);
      setState(() {
        selectedAttrs
          ..clear()
          ..addAll(next);
      });
      return;
    }

    next.add(a);

    // next 적용했을 때 품목이 0개면 차단
    final test = _filterWith(category: selectedCategory, attrs: next);
    if (test.isEmpty) {
      _toast('이 조합에 해당하는 품목이 없어요.');
      return;
    }

    setState(() {
      selectedAttrs
        ..clear()
        ..addAll(next);
    });
  }

  List<ProductItem> _filterWith({required String category, required Set<String> attrs}) {
    Iterable<ProductItem> base = items;

    if (category != '전체') {
      base = base.where((it) => it.category == category);
    }
    if (attrs.isNotEmpty) {
      base = base.where((it) => attrs.every((a) => it.attrs.contains(a)));
    }
    return base.toList();
  }

  // ✅ 카테고리 변경 시: 선택된 속성 중 "존재하지 않는 속성"은 자동 해제
  void _setCategory(String c) {
    setState(() {
      selectedCategory = c;
    });

    final avail = _availableAttrsInCurrentCategory;
    final cleaned = selectedAttrs.where(avail.contains).toSet();

    // cleaned로도 품목이 0개면 속성 전체 비움(드롭다운 막힘 방지)
    final test = _filterWith(category: selectedCategory, attrs: cleaned);
    if (test.isEmpty) {
      setState(() {
        selectedAttrs.clear();
      });
    } else {
      setState(() {
        selectedAttrs
          ..clear()
          ..addAll(cleaned);
      });
    }
  }

  // ✅ 선택된 품목이 필터 밖으로 나가면 자동 해제
  void _syncSelectedItemWithFilteredList() {
    final list = _filteredItems;
    if (selectedItem != null && !list.contains(selectedItem)) {
      selectedItem = null;
    }
  }

  // ✅ 수량: 1~99 두 자리 다이얼(십/일 라벨 없음)
  Future<void> _pickQtyDialUnder100() async {
    // 현재 qty가 100이면 임시 99로
    int temp = (qty >= 100) ? 99 : qty.clamp(1, 99);

    int tens = temp ~/ 10;
    int ones = temp % 10;

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
                      const Text(
                        '  ',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
                            final v = tens * 10 + ones;
                            setState(() => qty = (v <= 0) ? 1 : v); // 00 방지
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

  // ✅ 무게: 델타 버튼(계산기처럼 누를 때마다 누적)
  void _applyWeightDelta(double deltaKg) {
    setState(() {
      final next = weightKg + deltaKg;
      // 음수 방지
      weightKg = (next < 0) ? 0 : next;
    });
  }

  // ✅ 1장당 g 계산 (소수점 둘째자리 반올림)
  String get _perSheetGramText {
    if (qty <= 0) return '-';
    final per = (weightKg * 1000.0) / qty;
    final rounded = (per * 100).round() / 100; // 소수 둘째자리 반올림
    return rounded.toStringAsFixed(2);
  }

  String _newTempId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(900000) + 100000;
    return 'T$ms-$r';
  }

  void generateQr() {
    final producer = (selectedProducer ?? '').trim();
    final item = selectedItem;

    if (producer.isEmpty) { _toast('생산자를 선택하세요.'); return; }
    if (producedAt == null) { _toast('생산일자를 선택하세요.'); return; }
    if (item == null) { _toast('품목을 선택하세요.'); return; }
    if (qty <= 0 || qty > 100) { _toast('수량은 1~100만 가능합니다.'); return; }

    final tempId = _newTempId();

    final payload = <String, dynamic>{
      "type": "product_pack",
      "tempId": tempId, // ✅ 핵심
      "producer": producer,
      "producedAt": producedAt!.toIso8601String().substring(0, 10),
      "sku": item.sku,
      "name": item.name,
      "qty": qty,
      // 네가 쓰고 있던 무게/1장당g/카테고리/attrs가 있으면 그대로 포함
      "weightKg": weightKg,         // 너 코드에 있는 변수명대로
      //"perSheetG": perSheetG,       // 너 코드에 있는 변수명대로
      //"category": selectedCategory, // 또는 item.category
      //"attrs": selectedAttrs,       // 너 코드에 있는 변수명대로
      "version": 1,
    };

    setState(() {
      batchId = null;            // ✅ 이제 product 단계에서는 batchId 없음
      qrData = jsonEncode(payload);
    });
  }

  void resetForm() {
    setState(() {
      selectedProducer = null;
      selectedCategory = '전체';
      selectedAttrs.clear();
      selectedItem = null;

      producedAt = DateTime.now(); // ✅ 리셋도 오늘
      qty = 100; // ✅ 기본 100 유지
      weightKg = 3.0; // ✅ 기본 3.0

      batchId = null;
      qrData = null;
      dailySerial = 1;
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
                pw.Text('W: ${weightKg.toStringAsFixed(2)}kg', style: pw.TextStyle(fontSize: 9)),
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

    // 필터 바뀌었을 때 selectedItem 싱크
    _syncSelectedItemWithFilteredList();

    // UI 분기: 웹(넓음) / 모바일(좁음)
    final width = MediaQuery.of(context).size.width;
    final bool isWide = kIsWeb || width >= 720;

    // 카테고리 태그를 "가로 2열"로
    final int catColumns = isWide ? 3 : 2;

    // 태그 간격(너가 말한 “너무 떨어져” 해결)
    const double chipSpacing = 6;
    const double chipRunSpacing = 6;

    // 현재 카테고리에서 가능한 속성만 활성화
    final availAttrs = _availableAttrsInCurrentCategory;

    // 드롭다운 목록
    final filtered = _filteredItems;

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
          const SizedBox(height: 12),

          // ✅ 생산자
          const Text('생산자 *', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: chipSpacing,
            runSpacing: chipRunSpacing,
            children: producers.map((p) {
              final isSelected = selectedProducer == p;
              return ChoiceChip(
                label: Text(p),
                selected: isSelected,
                onSelected: (_) => setState(() => selectedProducer = p),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ✅ 생산일자 (요청: 볼드 타이틀을 위에)
          const Text('생산일자 *', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(dateText),
          ),

          const SizedBox(height: 14),

          // ✅ 품목 카테고리 (가로 2열 grid)
          const Text('품목 카테고리', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: catColumns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: isWide ? 3.4 : 3.0, // 박스가 너무 납작하지 않게
            children: categories.map((c) {
              final selected = selectedCategory == c;
              return ChoiceChip(
                label: Center(child: Text(c, overflow: TextOverflow.ellipsis)),
                selected: selected,
                onSelected: (_) => _setCategory(c),
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ✅ 하위 속성 태그(복수 선택) + 불가능 속성은 비활성
          const Text('품목 속성(필터)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: chipSpacing,
            runSpacing: chipRunSpacing,
            children: allAttrs.map((a) {
              final bool enabled = (selectedCategory == '전체') ? true : availAttrs.contains(a);

              final bool selected = selectedAttrs.contains(a);

              // enabled=false인데 selected=true면(카테고리 바뀌면서) 자동 해제 로직이 이미 돌지만
              // 혹시 남아있을 수 있으니 방어적으로 비활성 처리
              return FilterChip(
                label: Text(a),
                selected: selected,
                onSelected: enabled ? (_) => _toggleAttr(a) : null,
                disabledColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ✅ 품목 선택 드롭다운 (항상 유효 목록만)
          DropdownButtonFormField<ProductItem>(
            value: selectedItem,
            decoration: const InputDecoration(
              labelText: '품목 선택 *',
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            items: filtered.map((it) {
              return DropdownMenuItem<ProductItem>(
                value: it,
                child: Text('${it.name}   (${it.sku})'),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedItem = v),
          ),

          // 필터가 너무 빡세서 리스트가 0개일 때 안내(드롭다운 막힘 원인 즉시 파악)
          if (filtered.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '선택한 카테고리/속성 조합에 해당하는 품목이 없습니다. 속성을 줄이거나 카테고리를 바꿔주세요.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],

          const SizedBox(height: 14),

          // ✅ 수량 (100 기본 + 100 미만은 두 자리 다이얼)
          const Text('수량 (최대 100)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: chipSpacing,
            runSpacing: chipRunSpacing,
            children: [
              ChoiceChip(
                label: const Text('100 (Pack)'),
                selected: qty == 100,
                onSelected: (_) => setState(() => qty = 100),
                visualDensity: VisualDensity.compact,
              ),
              ChoiceChip(
                label: Text(qty == 100 ? '100 미만 선택' : '선택됨: ${qty.toString().padLeft(2, '0')}'),
                selected: qty != 100,
                onSelected: (_) async {
                  await _pickQtyDialUnder100();
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ✅ 무게 (계산기처럼 누를 때마다 누적) + 1장당 g 자동 계산
          const Text('무게', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '총중량: ${weightKg.toStringAsFixed(2)} kg   |   1장당: $_perSheetGramText g',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: chipSpacing,
                    runSpacing: chipRunSpacing,
                    children: [
                      // (-) 그룹
                      ActionChip(label: const Text('-0.3'), onPressed: () => _applyWeightDelta(-0.3)),
                      ActionChip(label: const Text('-0.2'), onPressed: () => _applyWeightDelta(-0.2)),
                      ActionChip(label: const Text('-0.1'), onPressed: () => _applyWeightDelta(-0.1)),

                      // 기준(리셋)
                      ActionChip(
                        label: const Text('3.0'),
                        onPressed: () => setState(() => weightKg = 3.0),
                      ),

                      // (+) 그룹  ✅ 여기서 +0.1 같은 “단항 +” 호출 금지 → 0.1로 호출
                      ActionChip(label: const Text('+0.1'), onPressed: () => _applyWeightDelta(0.1)),
                      ActionChip(label: const Text('+0.2'), onPressed: () => _applyWeightDelta(0.2)),
                      ActionChip(label: const Text('+0.3'), onPressed: () => _applyWeightDelta(0.3)),
                    ],
                  ),
                ],
              ),
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
            const Center(child: Text('선택 후 [QR 생성]을 누르면 QR이 표시됩니다.')),
          ] else ...[
            const SizedBox(height: 8),
            Text('생성된 Batch: $batchId', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: qrData!,
                version: QrVersions.auto,
                size: isWide ? 320 : 260,
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
      ),
    );
  }
}
