// lib/screens/product_qr_create_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart'; // 🟢 QR 대신 바코드 위젯 사용!
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config.dart';
import '../models/product_catalog.dart';

class ProductQrCreateScreen extends StatefulWidget {
  const ProductQrCreateScreen({super.key});
  @override
  State<ProductQrCreateScreen> createState() => _ProductQrCreateScreenState();
}

class _ProductQrCreateScreenState extends State<ProductQrCreateScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final Color stoneShadow = const Color(0xFF586B54);

  final List<String> producers = ['안승탁', '박운서', '이병섭', '이응직'];
  String? selectedProducer;

  final List<String> hanjiCategories = ['전체', '외발', '소발', '대발', '배접', '2.7/3.6/120', '인쇄/나염', '기타'];
  String selectedCategory = '전체';

  final Set<String> selectedAttrs = <String>{};
  int qty = 100;
  double weightKg = 3.0;

  DateTime? producedAt;
  String? qrData;
  String? tempId;
  ProductItem? selectedItem;

  List<ProductItem> dynamicCatalog = [];

  String selectedLye = '미선택';
  int selectedPly = 1;
  String selectedThickness = '보통';
  double gsm = 0.0;
  String selectedDrying = '열판건조';
  String selectedDochim = '미도침';

  final variationCtrl = TextEditingController();

  final Map<String, double> paperArea = {
    '외발': 0.64 * 0.94, '소발': 0.40 * 0.60, '대발': 0.75 * 1.45,
    '배접': 0.80 * 1.50, '2.7/3.6/120': 0.70 * 1.40, '기타': 1.0,
  };

  @override
  void initState() {
    super.initState();
    producedAt = DateTime.now();
    dynamicCatalog = List.from(catalogItems);
    _loadSavedData();
  }

  @override
  void dispose() { variationCtrl.dispose(); super.dispose(); }

  void _calculateGsm() {
    double area = paperArea[selectedCategory] ?? 1.0;
    if (qty > 0) setState(() => gsm = (weightKg * 1000) / (area * qty));
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedProducer = prefs.getString('prod_producer');
      selectedCategory = prefs.getString('prod_category') ?? '전체';
      final savedAttrs = prefs.getStringList('prod_attrs');
      if (savedAttrs != null) selectedAttrs.addAll(savedAttrs);
      qty = prefs.getInt('prod_qty') ?? 100;
      weightKg = prefs.getDouble('prod_weight') ?? 3.0;
      _calculateGsm();
    });
  }

  Future<void> _saveData(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) prefs.setString(key, value);
    if (value is int) prefs.setInt(key, value);
    if (value is double) prefs.setDouble(key, value);
    if (value is List<String>) prefs.setStringList(key, value);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  String _getFinalDisplayName() {
    if (selectedItem == null) return '-';
    String name = '';
    if (selectedDochim == '도침') name += '도침 ';
    name += selectedItem!.name;
    if (variationCtrl.text.trim().isNotEmpty) name += ' No.${variationCtrl.text.trim()}';
    if (selectedThickness == '薄(얇게)') name += ' (薄)';
    if (selectedThickness == '厚(두껍게)') name += ' (厚)';
    if (selectedDrying == '일광(양건지)') name += ' (양건지)';
    if (selectedPly >= 2) name += ' ${selectedPly}합';
    return name;
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: producedAt ?? now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 2));
    if (picked != null) setState(() => producedAt = picked);
  }

  Future<void> _pickQtyDialUnder100() async {
    int temp = (qty >= 100) ? 99 : qty.clamp(1, 99);
    int tens = temp ~/ 10; int ones = temp % 10;
    await showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: Column(
              children: [
                const SizedBox(height: 16), const Text('수량 선택 (1~99장)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 10),
                Expanded(child: Row(children: [
                  Expanded(child: CupertinoPicker(scrollController: FixedExtentScrollController(initialItem: tens), itemExtent: 44, onSelectedItemChanged: (i) => tens = i, children: List.generate(10, (i) => Center(child: Text(i.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))))),
                  const Text('  ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  Expanded(child: CupertinoPicker(scrollController: FixedExtentScrollController(initialItem: ones), itemExtent: 44, onSelectedItemChanged: (i) => ones = i, children: List.generate(10, (i) => Center(child: Text(i.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))))),
                ])),
                Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소'))), const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: () { final v = tens * 10 + ones; setState(() { qty = (v <= 0) ? 1 : v; _calculateGsm(); }); _saveData('prod_qty', qty); Navigator.pop(context); }, child: const Text('확정'))),
                ])),
              ],
            ),
          ),
        );
      },
    );
  }

  Set<String> get _availableAttrsInCurrentCategory {
    final base = (selectedCategory == '전체') ? dynamicCatalog : dynamicCatalog.where((it) => it.category == selectedCategory);
    final s = <String>{}; for (final it in base) s.addAll(it.attrs); return s;
  }

  List<ProductItem> get _filteredItems {
    Iterable<ProductItem> base = dynamicCatalog;
    if (selectedCategory != '전체') base = base.where((it) => it.category == selectedCategory);
    if (selectedAttrs.isNotEmpty) base = base.where((it) => selectedAttrs.every((a) => it.attrs.contains(a)));
    return base.toList();
  }

  void _toggleAttr(String a) {
    final next = <String>{...selectedAttrs};
    if (next.contains(a)) { next.remove(a); } else {
      next.add(a);
      Iterable<ProductItem> test = dynamicCatalog;
      if (selectedCategory != '전체') test = test.where((it) => it.category == selectedCategory);
      test = test.where((it) => next.every((a) => it.attrs.contains(a)));
      if (test.isEmpty) { _toast('이 조합에 해당하는 품목이 없어요.'); return; }
    }
    setState(() { selectedAttrs.clear(); selectedAttrs.addAll(next); });
    _saveData('prod_attrs', selectedAttrs.toList());
  }

  void _setCategory(String c) {
    setState(() { selectedCategory = c; _calculateGsm(); });
    _saveData('prod_category', c);
    final avail = _availableAttrsInCurrentCategory;
    final cleaned = selectedAttrs.where(avail.contains).toSet();
    setState(() { selectedAttrs.clear(); selectedAttrs.addAll(cleaned); });
    _saveData('prod_attrs', selectedAttrs.toList());
  }

  void _syncSelectedItemWithFilteredList() {
    final list = _filteredItems;
    if (selectedItem != null && !list.contains(selectedItem)) selectedItem = null;
  }

  void _applyWeightDelta(double deltaKg) {
    setState(() { final next = weightKg + deltaKg; weightKg = (next < 0) ? 0 : next; _calculateGsm(); });
    _saveData('prod_weight', weightKg);
  }

  String _newTempId() { return 'T${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(900000) + 100000}'; }

  void generateQr() {
    final producer = (selectedProducer ?? '').trim();
    if (producer.isEmpty) { _toast('생산자를 선택하세요.'); return; }
    if (selectedItem == null) { _toast('품목을 선택하세요.'); return; }

    final newTempId = _newTempId();
    final payload = <String, dynamic>{
      "type": "product_pack",
      "tempId": newTempId,
      "producer": producer,
      "producedAt": producedAt!.toIso8601String().substring(0, 10),
      "sku": selectedItem!.sku,
      "name": _getFinalDisplayName(),
      "qty": qty,
      "weightKg": weightKg,
      "gsm": gsm.toStringAsFixed(1),
      "lye": selectedLye,
      "ply": selectedPly,
      "drying": selectedDrying,
      "dochim": selectedDochim,
      "thickness": selectedThickness,
      "variation": variationCtrl.text.trim(),
      "category": selectedCategory,
      "attrs": selectedItem!.attrs.join(", "),
      "version": 1,
    };
    final jsonString = jsonEncode(payload); final base64Data = base64Encode(utf8.encode(jsonString));
    setState(() { tempId = newTempId; qrData = 'https://andonghanji.com/board/index.php?app_data=$base64Data'; });
  }

  PdfColor _getWeightColor(double w) {
    if (w >= 3.4) return PdfColor.fromHex('#3D5361'); if (w >= 3.1) return PdfColor.fromHex('#9C5D41'); if (w >= 2.8) return PdfColor.fromHex('#999B84'); if (w >= 2.5) return PdfColor.fromHex('#C0A290'); if (w >= 2.2) return PdfColor.fromHex('#B8C1C1'); return PdfColor.fromHex('#ECE4DD');
  }
  PdfColor _getTextColorForWeight(double w) { if (w >= 3.1) return PdfColors.white; return PdfColors.black; }

// ... (앞부분 생략: 이전과 동일한 import 및 변수 설정)

  // 🟢 인쇄 로직: 미니 QR과 긴 바코드를 동시에 배치
  Future<void> printQr() async {
    if (qrData == null || tempId == null) { _toast('먼저 생성하세요.'); return; }
    pw.Font fontBold; pw.Font fontMedium; pw.Font fontLight; pw.Font fallbackFont; pw.MemoryImage logoImage;
    try {
      fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
      fontMedium = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Medium.ttf'));
      fontLight = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-ExtraLight.ttf'));
      fallbackFont = pw.Font.ttf(await rootBundle.load('assets/fonts/PretendardJP-Bold.ttf'));
      final imageBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (e) { _toast('폰트나 이미지를 찾을 수 없습니다.'); return; }

    final doc = pw.Document();
    final pageFormat = PdfPageFormat(100 * PdfPageFormat.mm, 100 * PdfPageFormat.mm);
    final productName = _getFinalDisplayName();
    final productSku = selectedItem?.sku ?? 'unknown'; // 제품 코드
    final dateStr = '${producedAt?.year}.${producedAt?.month.toString().padLeft(2, '0')}.${producedAt?.day.toString().padLeft(2, '0')}';

    // 🟢 고객용 홈페이지 주소 (제품별 상세페이지 예시)
    final customerUrl = "https://andonghanji.com/product/$productSku";

    doc.addPage(pw.Page(pageFormat: pageFormat, margin: pw.EdgeInsets.all(4 * PdfPageFormat.mm), build: (pw.Context context) {
      return pw.Stack(fit: pw.StackFit.expand, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          // [상단 영역] 품명과 고객용 미니 QR
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('ANDONG HANJI', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(productName, style: pw.TextStyle(font: fontBold, fontSize: 24, fontFallback: [fallbackFont])),
              pw.SizedBox(height: 4),
              pw.Text(dateStr, style: pw.TextStyle(font: fontLight, fontSize: 12)),
            ])),
            // 🟢 우측 상단 미니 QR (고객용 - 약 1.8cm)
            pw.Column(children: [
              pw.Container(
                width: 18 * PdfPageFormat.mm,
                height: 18 * PdfPageFormat.mm,
                child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: customerUrl),
              ),
              pw.SizedBox(height: 2),
              pw.Text('제품 정보 확인', style: pw.TextStyle(font: fontMedium, fontSize: 7, fontFallback: [fallbackFont])),
            ])
          ]),

          pw.SizedBox(height: 10),
          pw.Container(height: 0.5, color: PdfColors.black),
          pw.SizedBox(height: 10),

          // [중앙 영역] 상세 스펙
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('생산자: ${selectedProducer} 장인', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])),
              pw.Text('수량: $qty 장', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('중량: ${weightKg.toStringAsFixed(1)}kg', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])),
              pw.Text('평량: ${gsm.toStringAsFixed(1)}g/m²', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])),
            ]),
          ]),

          pw.Spacer(),

          // [하단 영역] 관리용 PDF417 바코드 (가로로 길게)
          pw.Text('FOR INTERNAL MANAGEMENT (LOGISTICS)', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Container(
            height: 18 * PdfPageFormat.mm,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.pdf417(), // 🟢 관리용 특수 바코드
              data: qrData!,
              drawText: false,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.SizedBox(height: 8 * PdfPageFormat.mm, child: pw.Image(logoImage))),
        ]),
        // 외곽 테두리
        pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(width: 1, color: PdfColors.black))),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

// ... (나머지 UI 부분 생략: 이전과 동일)

  Future<void> _undoAddProduct(ProductItem item) async {
    _toast('🗑️ 삭제 처리 중...');
    try {
      var res = await http.post(Uri.parse(AppConfig.webAppUrl), headers: {'Content-Type': 'text/plain'}, body: jsonEncode({"action": "undoAddProduct", "sku": item.sku}));
      if (res.statusCode == 302 || res.statusCode == 303) { final redirectUrl = res.headers['location'] ?? res.headers['Location']; if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl)); }
      setState(() { dynamicCatalog.removeWhere((x) => x.sku == item.sku); if (selectedItem?.sku == item.sku) selectedItem = null; });
      _toast('✅ [${item.name}] 추가가 취소되었습니다.');
    } catch (e) { _toast('취소 실패: $e'); }
  }

  Future<void> _showAddProductDialog() async {
    final newNameCtrl = TextEditingController(); String newCategory = '기타'; Set<String> newAttrs = {}; bool isSubmitting = false;
    final availableCategories = hanjiCategories.where((c) => c != '전체').toList();

    await showDialog(
        context: context, barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text('➕ 새 품목 간편 추가', style: TextStyle(fontWeight: FontWeight.bold, color: stoneShadow)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(controller: newNameCtrl, decoration: const InputDecoration(labelText: '품목명 (예: 무표백 순지 특대발)', border: OutlineInputBorder())),
                        const SizedBox(height: 16), const Text('분류 (카테고리)', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: availableCategories.map((c) { final isSelected = newCategory == c; return ChoiceChip(label: Text(c, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black)), selected: isSelected, selectedColor: stoneShadow, onSelected: (_) => setDialogState(() => newCategory = c)); }).toList()),
                        const SizedBox(height: 16), const Text('속성 태그 (다중 선택)', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: allProductAttrs.map((attr) { final isSelected = newAttrs.contains(attr); return FilterChip(label: Text(attr, style: const TextStyle(fontSize: 12)), selected: isSelected, onSelected: (_) { setDialogState(() { if (isSelected) newAttrs.remove(attr); else newAttrs.add(attr); }); }); }).toList()),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey, fontSize: 16))),
                    FilledButton(
                      onPressed: isSubmitting ? null : () async {
                        if (newNameCtrl.text.trim().isEmpty) { _toast('품목명을 입력해주세요.'); return; }
                        setDialogState(() => isSubmitting = true);
                        try {
                          final newSku = 'HJ-NEW-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                          final payload = { "action": "addProduct", "name": newNameCtrl.text.trim(), "sku": newSku, "category": newCategory, "attrs": newAttrs.toList().join(', ') };
                          var res = await http.post(Uri.parse(AppConfig.webAppUrl), headers: {'Content-Type': 'text/plain'}, body: jsonEncode(payload));
                          if (res.statusCode == 302 || res.statusCode == 303) { final redirectUrl = res.headers['location'] ?? res.headers['Location']; if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl)); }
                          final newItem = ProductItem(name: newNameCtrl.text.trim(), sku: newSku, category: newCategory, attrs: newAttrs);
                          setState(() { dynamicCatalog.add(newItem); selectedItem = newItem; selectedCategory = newCategory; selectedAttrs.clear(); selectedAttrs.addAll(newAttrs); });
                          if (context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).clearSnackBars(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ [${newItem.name}] 등록 완료!'), duration: const Duration(seconds: 8), action: SnackBarAction(label: '실수로 눌렀다면? (되돌리기)', textColor: Colors.yellow, onPressed: () => _undoAddProduct(newItem)))); }
                        } catch (e) { setDialogState(() => isSubmitting = false); _toast('통신 오류: $e'); }
                      },
                      style: FilledButton.styleFrom(backgroundColor: stoneShadow), child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('등록 및 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )
                  ],
                );
              }
          );
        }
    );
  }

  Widget _buildCategoryChip(String c) {
    final isSelected = selectedCategory == c;
    return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: ChoiceChip(showCheckmark: false, label: Center(child: Text(c, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87))), selected: isSelected, selectedColor: Colors.blue.shade700, backgroundColor: Colors.white, side: BorderSide(color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), onSelected: (_) => _setCategory(c))));
  }

  Widget _buildAttrChip(String a) {
    final bool enabled = (selectedCategory == '전체') ? true : _availableAttrsInCurrentCategory.contains(a);
    final isSelected = selectedAttrs.contains(a);
    return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3.0), child: FilterChip(showCheckmark: false, label: Center(child: Text(a, style: TextStyle(fontSize: 13, color: isSelected ? Colors.blue.shade900 : (enabled ? Colors.black87 : Colors.grey.shade400)))), selected: isSelected, onSelected: enabled ? (_) => _toggleAttr(a) : null, selectedColor: Colors.blue.shade50, backgroundColor: Colors.white, shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.blue.shade400 : Colors.grey.shade200)))));
  }

  Widget _buildInputForm() {
    final dateText = producedAt == null ? '생산일자 선택' : '${producedAt!.year}-${producedAt!.month.toString().padLeft(2, '0')}-${producedAt!.day.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('생산자 *', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Row(children: producers.map((p) { final isSelected = selectedProducer == p; return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: Opacity(opacity: isSelected ? 1.0 : 0.6, child: ChoiceChip(showCheckmark: false, label: Center(child: Text(p, textAlign: TextAlign.center, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blue.shade900 : Colors.black87))), selected: isSelected, selectedColor: Colors.blue.shade100, backgroundColor: Colors.grey.shade200, side: BorderSide.none, onSelected: (_) { setState(() => selectedProducer = p); _saveData('prod_producer', p); })))); }).toList()),
        const SizedBox(height: 16),

        const Text('생산일자 *', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.calendar_month_outlined), label: Text(dateText, style: const TextStyle(fontSize: 15))),
        const SizedBox(height: 16),

        const Text('품목 카테고리 (사이즈 분류)', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Row(children: hanjiCategories.sublist(0, 4).map((c) => _buildCategoryChip(c)).toList()), const SizedBox(height: 8),
        Row(children: hanjiCategories.sublist(4, 8).map((c) => _buildCategoryChip(c)).toList()), const SizedBox(height: 20),

        const Text('품목 속성 (세부 필터)', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Row(children: allProductAttrs.sublist(0, 4).map((a) => _buildAttrChip(a)).toList()), const SizedBox(height: 8),
        Row(children: allProductAttrs.sublist(4, 8).map((a) => _buildAttrChip(a)).toList()), const SizedBox(height: 20),

        const Text('전문 공정 설정', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Row(children: [
          const SizedBox(width: 50, child: Text('잿물: ', style: TextStyle(fontWeight: FontWeight.bold))),
          Wrap(spacing: 6, children: ['미선택', '육재', '기타'].map((lye) => ChoiceChip(label: Text(lye), selected: selectedLye == lye, selectedColor: stoneShadow.withOpacity(0.3), onSelected: (v) => setState(() => selectedLye = lye))).toList())
        ]), const SizedBox(height: 8),
        Row(children: [
          const SizedBox(width: 50, child: Text('건조: ', style: TextStyle(fontWeight: FontWeight.bold))),
          Wrap(spacing: 6, children: ['열판건조', '일광(양건지)'].map((d) => ChoiceChip(label: Text(d), selected: selectedDrying == d, selectedColor: Colors.orange.shade200, onSelected: (v) => setState(() => selectedDrying = d))).toList())
        ]), const SizedBox(height: 8),
        Row(children: [
          const SizedBox(width: 50, child: Text('도침: ', style: TextStyle(fontWeight: FontWeight.bold))),
          Wrap(spacing: 6, children: ['미도침', '도침'].map((d) => ChoiceChip(label: Text(d), selected: selectedDochim == d, selectedColor: Colors.blue.shade200, onSelected: (v) => setState(() => selectedDochim = d))).toList()),
        ]), const SizedBox(height: 8),
        Row(children: [
          const SizedBox(width: 50, child: Text('두께: ', style: TextStyle(fontWeight: FontWeight.bold))),
          Wrap(spacing: 6, children: ['보통', '薄(얇게)', '厚(두껍게)'].map((t) => ChoiceChip(label: Text(t), selected: selectedThickness == t, selectedColor: Colors.grey.shade300, onSelected: (v) => setState(() => selectedThickness = t))).toList()),
        ]), const SizedBox(height: 8),
        Row(children: [
          const SizedBox(width: 50, child: Text('합(Ply):', style: TextStyle(fontWeight: FontWeight.bold))),
          Wrap(spacing: 6, children: [1, 2, 3, 4].map((p) => ChoiceChip(label: Text('${p}합'), selected: selectedPly == p, onSelected: (v) => setState(() { selectedPly = p; setState((){}); }))).toList())
        ]), const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(flex: 5, child: InputDecorator(decoration: InputDecoration(labelText: '품목 선택 *', helperText: '✅ 조건에 맞는 품목: ${_filteredItems.length}개', helperStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13), border: const OutlineInputBorder()), child: DropdownButtonHideUnderline(child: DropdownButton<ProductItem>(hint: const Text('여기를 눌러 품목을 선택하세요'), value: selectedItem, isExpanded: true, items: _filteredItems.map((it) => DropdownMenuItem(value: it, child: Text('${it.name}   (${it.sku})'))).toList(), onChanged: (v) => setState(() { selectedItem = v; setState((){}); }))))),
            if (kIsWeb) ...[ const SizedBox(width: 8), Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(bottom: 22.0), child: FilledButton.icon(onPressed: _showAddProductDialog, style: FilledButton.styleFrom(backgroundColor: stoneShadow, padding: const EdgeInsets.symmetric(vertical: 18)), icon: const Icon(Icons.add_circle_outline, size: 20), label: const Text('품목 추가', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))))) ]
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.palette_outlined, color: Colors.grey), const SizedBox(width: 8),
            const Text('샘플번호 (선택):', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: variationCtrl,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(hintText: '예: 15 (입력시 품명에 합성됨)', isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                onChanged: (v) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text('수량', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Row(children: [ChoiceChip(showCheckmark: false, label: const Text('100장 (1 Pack)'), selected: qty == 100, selectedColor: Colors.blue.shade100, onSelected: (_) { setState(() {qty = 100; _calculateGsm();}); _saveData('prod_qty', 100); }), const SizedBox(width: 8), ChoiceChip(showCheckmark: false, label: Text(qty == 100 ? '100장 미만 직접입력' : '낱장: $qty장 (변경)'), selected: qty != 100, selectedColor: Colors.blue.shade100, onSelected: (_) async { await _pickQtyDialUnder100(); })]),
        const SizedBox(height: 16),

        const Text('무게', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Card(elevation: 0, color: Colors.blue.shade50.withOpacity(0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade100)), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('총중량: ${weightKg.toStringAsFixed(2)} kg', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 15)),
              Text('평량: ${gsm.toStringAsFixed(1)} g/m²', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [ActionChip(label: const Text('-0.3'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(-0.3)), const SizedBox(width: 4), ActionChip(label: const Text('-0.2'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(-0.2)), const SizedBox(width: 4), ActionChip(label: const Text('-0.1'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(-0.1)), const SizedBox(width: 4), ActionChip(label: const Text('3.0', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, visualDensity: VisualDensity.compact, onPressed: () { setState(() {weightKg = 3.0; _calculateGsm();}); _saveData('prod_weight', 3.0); }), const SizedBox(width: 4), ActionChip(label: const Text('+0.1'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(0.1)), const SizedBox(width: 4), ActionChip(label: const Text('+0.2'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(0.2)), const SizedBox(width: 4), ActionChip(label: const Text('+0.3'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(0.3))]))]))),
        const SizedBox(height: 20),

        FilledButton.icon(onPressed: generateQr, icon: const Icon(Icons.qr_code_2_outlined), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('QR 생성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),

        if (MediaQuery.of(context).size.width < 800) ...[ const SizedBox(height: 24), _buildQrResult() ]
      ],
    );
  }

  // 🟢 화면에 그릴 때도 네모난 QR이 아니라 직사각형 특수 바코드(PDF417)를 보여줍니다!
  Widget _buildQrResult() {
    if (qrData == null) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('입력 후 [QR 생성]을 누르세요.', style: TextStyle(color: Colors.grey))));
    return Column(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(8)), child: Text('최종 품명: ${_getFinalDisplayName()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent))),
      const SizedBox(height: 12),

      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
          // 🟢 여기서 직사각형 특수 바코드를 그립니다!
          child: BarcodeWidget(
            barcode: Barcode.pdf417(),
            data: qrData!,
            width: 250,
            height: 80,
            errorBuilder: (context, error) => Center(child: Text(error)),
          )
      ),

      const SizedBox(height: 20),
      FilledButton.icon(onPressed: printQr, icon: const Icon(Icons.print), label: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('라벨 프린터로 인쇄', style: TextStyle(fontSize: 16)))),
      const SizedBox(height: 24)
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _syncSelectedItemWithFilteredList();

    return Scaffold(
        body: Container(
          child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 800) {
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _buildInputForm()), const VerticalDivider(width: 1), Expanded(flex: 2, child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.only(top: 32), child: _buildQrResult())))]);
                } else {
                  return _buildInputForm();
                }
              }
          ),
        )
    );
  }
}