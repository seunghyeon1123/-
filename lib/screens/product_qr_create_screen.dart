// lib/screens/product_qr_create_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb; // 🟢 웹(Web) 감지용 추가
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
  String selectedCategory = '전체';
  final Set<String> selectedAttrs = <String>{};
  int qty = 100;
  double weightKg = 3.0;

  DateTime? producedAt;
  String? qrData;
  String? tempId;
  ProductItem? selectedItem;

  List<ProductItem> dynamicCatalog = [];

  @override
  void initState() {
    super.initState();
    producedAt = DateTime.now();
    dynamicCatalog = List.from(catalogItems);
    _loadSavedData();
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

  Future<void> _pickQtyDialUnder100() async {
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
                const SizedBox(height: 16),
                const Text('수량 선택 (1~99장)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: CupertinoPicker(scrollController: FixedExtentScrollController(initialItem: tens), itemExtent: 44, onSelectedItemChanged: (i) => tens = i, children: List.generate(10, (i) => Center(child: Text(i.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))))),
                      const Text('  ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      Expanded(child: CupertinoPicker(scrollController: FixedExtentScrollController(initialItem: ones), itemExtent: 44, onSelectedItemChanged: (i) => ones = i, children: List.generate(10, (i) => Center(child: Text(i.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)))))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소'))), const SizedBox(width: 12),
                      Expanded(child: FilledButton(onPressed: () { final v = tens * 10 + ones; setState(() => qty = (v <= 0) ? 1 : v); _saveData('prod_qty', qty); Navigator.pop(context); }, child: const Text('확정'))),
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

  Set<String> get _availableAttrsInCurrentCategory {
    final base = (selectedCategory == '전체') ? dynamicCatalog : dynamicCatalog.where((it) => it.category == selectedCategory);
    final s = <String>{};
    for (final it in base) s.addAll(it.attrs);
    return s;
  }

  List<ProductItem> get _filteredItems {
    Iterable<ProductItem> base = dynamicCatalog;
    if (selectedCategory != '전체') base = base.where((it) => it.category == selectedCategory);
    if (selectedAttrs.isNotEmpty) base = base.where((it) => selectedAttrs.every((a) => it.attrs.contains(a)));
    return base.toList();
  }

  void _toggleAttr(String a) {
    final next = <String>{...selectedAttrs};
    if (next.contains(a)) { next.remove(a); }
    else {
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
    setState(() => selectedCategory = c);
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
    setState(() { final next = weightKg + deltaKg; weightKg = (next < 0) ? 0 : next; });
    _saveData('prod_weight', weightKg);
  }

  String _newTempId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(900000) + 100000;
    return 'T$ms-$r';
  }

  void generateQr() {
    final producer = (selectedProducer ?? '').trim();
    if (producer.isEmpty) { _toast('생산자를 선택하세요.'); return; }
    if (selectedItem == null) { _toast('품목을 선택하세요.'); return; }

    final newTempId = _newTempId();
    final payload = <String, dynamic>{ "type": "product_pack", "tempId": newTempId, "producer": producer, "producedAt": producedAt!.toIso8601String().substring(0, 10), "sku": selectedItem!.sku, "name": selectedItem!.name, "qty": qty, "weightKg": weightKg, "perSheetG": 0, "category": selectedItem!.category, "attrs": selectedItem!.attrs.join(", "), "version": 1, };
    final jsonString = jsonEncode(payload); final base64Data = base64Encode(utf8.encode(jsonString));
    final smartQrUrl = 'https://andonghanji.com/board/index.php?app_data=$base64Data';
    setState(() { tempId = newTempId; qrData = smartQrUrl; });
  }

  PdfColor _getWeightColor(double w) {
    if (w >= 3.4) return PdfColor.fromHex('#3D5361'); if (w >= 3.1) return PdfColor.fromHex('#9C5D41'); if (w >= 2.8) return PdfColor.fromHex('#999B84'); if (w >= 2.5) return PdfColor.fromHex('#C0A290'); if (w >= 2.2) return PdfColor.fromHex('#B8C1C1'); return PdfColor.fromHex('#ECE4DD');
  }

  PdfColor _getTextColorForWeight(double w) {
    if (w >= 3.1) return PdfColors.white; return PdfColors.black;
  }

  Future<void> printQr() async {
    if (qrData == null || tempId == null) { _toast('먼저 QR을 생성하세요.'); return; }
    pw.Font fontBold; pw.Font fontMedium; pw.Font fontLight; pw.Font fallbackFont; pw.MemoryImage logoImage;
    try {
      fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Bold.ttf')); fontMedium = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Medium.ttf')); fontLight = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-ExtraLight.ttf')); fallbackFont = pw.Font.ttf(await rootBundle.load('assets/fonts/PretendardJP-Bold.ttf')); final imageBytes = await rootBundle.load('assets/images/logo.png'); logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (e) { _toast('폰트나 이미지 파일을 찾을 수 없습니다: $e'); return; }

    final doc = pw.Document(); final pageFormat = PdfPageFormat(100 * PdfPageFormat.mm, 100 * PdfPageFormat.mm); final productName = selectedItem?.name ?? '-'; final productSku = selectedItem?.sku ?? '-'; final dateStr = '${producedAt?.year}.${producedAt?.month.toString().padLeft(2, '0')}.${producedAt?.day.toString().padLeft(2, '0')}'; final prodName = selectedProducer ?? "-"; final bgColor = _getWeightColor(weightKg); final txtColor = _getTextColorForWeight(weightKg);

    pw.Widget buildInfoRow(String label, String value) { return pw.Column(children: [pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(label, style: pw.TextStyle(font: fontMedium, fontSize: 14, color: txtColor)), pw.Text(value, style: pw.TextStyle(font: fontMedium, fontSize: 14, color: txtColor, fontFallback: [fallbackFont]))]), pw.SizedBox(height: 1.5), pw.Container(height: 0.5, color: txtColor), pw.SizedBox(height: 2.5)]); }

    doc.addPage(pw.Page(pageFormat: pageFormat, margin: pw.EdgeInsets.all(3 * PdfPageFormat.mm), build: (pw.Context context) { return pw.Stack(fit: pw.StackFit.expand, children: [pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [pw.Expanded(child: pw.Container(padding: const pw.EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Container(constraints: pw.BoxConstraints(minHeight: 25 * PdfPageFormat.mm), alignment: pw.Alignment.topLeft, child: pw.Wrap(crossAxisAlignment: pw.WrapCrossAlignment.end, spacing: 8, runSpacing: 4, children: [pw.Text(productName, style: pw.TextStyle(font: fontBold, fontSize: 36, fontFallback: [fallbackFont])), pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Text(productSku, style: pw.TextStyle(font: fontLight, fontSize: 9)))])), pw.Spacer(), pw.Text(dateStr, style: pw.TextStyle(font: fontLight, fontSize: 18))]))), pw.Container(height: 1, color: PdfColors.black), pw.Container(height: 40 * PdfPageFormat.mm, child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [pw.Container(width: 40 * PdfPageFormat.mm, padding: const pw.EdgeInsets.all(3 * PdfPageFormat.mm), child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qrData!, color: PdfColors.black)), pw.Container(width: 0.5, color: PdfColors.black), pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [pw.Expanded(child: pw.Container(color: bgColor, padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [buildInfoRow('수량', '$qty EA'), buildInfoRow('중량', '${weightKg.toStringAsFixed(1)} kg'), buildInfoRow('생산', '$prodName 장인')]))), pw.Container(height: 0.5, color: PdfColors.black), pw.Container(height: 14 * PdfPageFormat.mm, color: PdfColors.white, alignment: pw.Alignment.center, child: pw.SizedBox(height: 14 * PdfPageFormat.mm * 0.64, child: pw.Image(logoImage, fit: pw.BoxFit.contain)))]))]))]), pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(width: 2, color: PdfColors.black)))]); }));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  // 🟢 [신규] 서버에 삭제(되돌리기) 요청을 보내고 리스트에서도 빼는 함수
  Future<void> _undoAddProduct(ProductItem item) async {
    _toast('🗑️ 삭제 처리 중...');
    try {
      var res = await http.post(
        Uri.parse(AppConfig.webAppUrl),
        headers: {'Content-Type': 'text/plain'},
        body: jsonEncode({"action": "undoAddProduct", "sku": item.sku}),
      );

      if (res.statusCode == 302 || res.statusCode == 303) {
        final redirectUrl = res.headers['location'] ?? res.headers['Location'];
        if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl));
      }

      setState(() {
        dynamicCatalog.removeWhere((x) => x.sku == item.sku); // 리스트에서 제거
        if (selectedItem?.sku == item.sku) selectedItem = null; // 선택된 항목 해제
      });
      _toast('✅ [${item.name}] 추가가 성공적으로 취소되었습니다.');
    } catch (e) {
      _toast('취소 실패: $e');
    }
  }

  Future<void> _showAddProductDialog() async {
    final newNameCtrl = TextEditingController();
    String newCategory = '기타';
    Set<String> newAttrs = {};
    bool isSubmitting = false;

    final availableCategories = productCategories.where((c) => c != '전체').toList();

    await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text('➕ 새 품목 간편 추가', style: TextStyle(fontWeight: FontWeight.bold, color: stoneShadow)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(controller: newNameCtrl, decoration: const InputDecoration(labelText: '품목명 (예: 무표백 순지 특대발)', border: OutlineInputBorder())),
                        const SizedBox(height: 16), const Text('분류 (카테고리)', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: availableCategories.map((c) {
                            final isSelected = newCategory == c;
                            return ChoiceChip(label: Text(c, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black)), selected: isSelected, selectedColor: stoneShadow, onSelected: (_) => setDialogState(() => newCategory = c));
                          }).toList(),
                        ),
                        const SizedBox(height: 16), const Text('속성 태그 (다중 선택)', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: allProductAttrs.map((attr) {
                            final isSelected = newAttrs.contains(attr);
                            return FilterChip(label: Text(attr, style: const TextStyle(fontSize: 12)), selected: isSelected, onSelected: (_) { setDialogState(() { if (isSelected) newAttrs.remove(attr); else newAttrs.add(attr); }); });
                          }).toList(),
                        ),
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
                          if (res.statusCode == 302 || res.statusCode == 303) {
                            final redirectUrl = res.headers['location'] ?? res.headers['Location'];
                            if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl));
                          }

                          final newItem = ProductItem(name: newNameCtrl.text.trim(), sku: newSku, category: newCategory, attrs: newAttrs);

                          setState(() {
                            dynamicCatalog.add(newItem);
                            selectedItem = newItem;
                            selectedCategory = newCategory;
                            selectedAttrs.clear();
                            selectedAttrs.addAll(newAttrs);
                          });

                          if (context.mounted) {
                            Navigator.pop(context);

                            // 🟢 알림창을 띄우면서 동시에 [되돌리기] 버튼을 제공합니다.
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ [${newItem.name}] 등록 완료!'),
                                  duration: const Duration(seconds: 8), // 되돌릴 시간을 충분히 8초 줍니다.
                                  action: SnackBarAction(
                                    label: '실수로 눌렀다면? (되돌리기)',
                                    textColor: Colors.yellow,
                                    onPressed: () => _undoAddProduct(newItem),
                                  ),
                                )
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          _toast('통신 오류: $e');
                        }
                      },
                      style: FilledButton.styleFrom(backgroundColor: stoneShadow),
                      child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('등록 및 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

        const Text('품목 카테고리', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Row(children: productCategories.sublist(0, 4).map((c) => _buildCategoryChip(c)).toList()), const SizedBox(height: 8),
        Row(children: [...productCategories.sublist(4, 7).map((c) => _buildCategoryChip(c)), const Spacer()]), const SizedBox(height: 20),

        const Text('품목 속성 (세부 필터)', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Row(children: allProductAttrs.sublist(0, 4).map((a) => _buildAttrChip(a)).toList()), const SizedBox(height: 8),
        Row(children: allProductAttrs.sublist(4, 8).map((a) => _buildAttrChip(a)).toList()), const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 5,
              child: InputDecorator(
                  decoration: InputDecoration(labelText: '품목 선택 *', helperText: '✅ 조건에 맞는 품목: 총 ${_filteredItems.length}개 대기중', helperStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13), border: const OutlineInputBorder()),
                  child: DropdownButtonHideUnderline(child: DropdownButton<ProductItem>(hint: const Text('여기를 눌러 품목을 선택하세요'), value: selectedItem, isExpanded: true, items: _filteredItems.map((it) => DropdownMenuItem(value: it, child: Text('${it.name}   (${it.sku})'))).toList(), onChanged: (v) => setState(() => selectedItem = v)))
              ),
            ),

            // 🟢 kIsWeb을 활용해 오직 웹(PC)에서만 이 '품목 추가' 버튼이 보이게 합니다!
            if (kIsWeb) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22.0),
                  child: FilledButton.icon(
                    onPressed: _showAddProductDialog,
                    style: FilledButton.styleFrom(backgroundColor: stoneShadow, padding: const EdgeInsets.symmetric(vertical: 18)),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('품목 추가', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
            ]
          ],
        ),

        const SizedBox(height: 16),
        const Text('수량', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Row(children: [ChoiceChip(showCheckmark: false, label: const Text('100장 (1 Pack)'), selected: qty == 100, selectedColor: Colors.blue.shade100, onSelected: (_) { setState(() => qty = 100); _saveData('prod_qty', 100); }), const SizedBox(width: 8), ChoiceChip(showCheckmark: false, label: Text(qty == 100 ? '100장 미만 직접입력' : '낱장: $qty장 (변경)'), selected: qty != 100, selectedColor: Colors.blue.shade100, onSelected: (_) async { await _pickQtyDialUnder100(); })]),
        const SizedBox(height: 16),

        const Text('무게', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8),
        Card(elevation: 0, color: Colors.blue.shade50.withOpacity(0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade100)), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('총중량: ${weightKg.toStringAsFixed(2)} kg', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 15)), const SizedBox(height: 12), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [ActionChip(label: const Text('-0.3'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(-0.3)), const SizedBox(width: 4), ActionChip(label: const Text('-0.2'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(-0.2)), const SizedBox(width: 4), ActionChip(label: const Text('-0.1'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(-0.1)), const SizedBox(width: 4), ActionChip(label: const Text('3.0', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, visualDensity: VisualDensity.compact, onPressed: () { setState(() => weightKg = 3.0); _saveData('prod_weight', 3.0); }), const SizedBox(width: 4), ActionChip(label: const Text('+0.1'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(0.1)), const SizedBox(width: 4), ActionChip(label: const Text('+0.2'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(0.2)), const SizedBox(width: 4), ActionChip(label: const Text('+0.3'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(0.3))]))]))),
        const SizedBox(height: 20),

        FilledButton.icon(onPressed: generateQr, icon: const Icon(Icons.qr_code_2_outlined), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('QR 생성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),

        if (MediaQuery.of(context).size.width < 800) ...[ const SizedBox(height: 24), _buildQrResult() ]
      ],
    );
  }

  Widget _buildQrResult() {
    if (qrData == null) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('입력 후 [QR 생성]을 누르세요.', style: TextStyle(color: Colors.grey))));
    return Column(children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)), child: QrImageView(data: qrData!, size: 200)), const SizedBox(height: 20), FilledButton.icon(onPressed: printQr, icon: const Icon(Icons.print), label: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('라벨 프린터로 인쇄', style: TextStyle(fontSize: 16)))), const SizedBox(height: 24)]);
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