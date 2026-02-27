// lib/screens/product_qr_create_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_catalog.dart';

class ProductQrCreateScreen extends StatefulWidget {
  const ProductQrCreateScreen({super.key});
  @override
  State<ProductQrCreateScreen> createState() => _ProductQrCreateScreenState();
}

class _ProductQrCreateScreenState extends State<ProductQrCreateScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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

  @override
  void initState() {
    super.initState();
    producedAt = DateTime.now();
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
        lastDate: DateTime(now.year + 2)
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
                      Expanded(
                          child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(initialItem: tens),
                              itemExtent: 44,
                              onSelectedItemChanged: (i) => tens = i,
                              children: List.generate(10, (i) => Center(child: Text(i.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))))
                          )
                      ),
                      const Text('  ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      Expanded(
                          child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(initialItem: ones),
                              itemExtent: 44,
                              onSelectedItemChanged: (i) => ones = i,
                              children: List.generate(10, (i) => Center(child: Text(i.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))))
                          )
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('취소'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: FilledButton(
                              onPressed: () {
                                final v = tens * 10 + ones;
                                setState(() => qty = (v <= 0) ? 1 : v);
                                _saveData('prod_qty', qty);
                                Navigator.pop(context);
                              },
                              child: const Text('확정')
                          )
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

  Set<String> get _availableAttrsInCurrentCategory {
    final base = (selectedCategory == '전체') ? catalogItems : catalogItems.where((it) => it.category == selectedCategory);
    final s = <String>{};
    for (final it in base) s.addAll(it.attrs);
    return s;
  }

  List<ProductItem> get _filteredItems {
    Iterable<ProductItem> base = catalogItems;
    if (selectedCategory != '전체') base = base.where((it) => it.category == selectedCategory);
    if (selectedAttrs.isNotEmpty) base = base.where((it) => selectedAttrs.every((a) => it.attrs.contains(a)));
    return base.toList();
  }

  void _toggleAttr(String a) {
    final next = <String>{...selectedAttrs};
    if (next.contains(a)) {
      next.remove(a);
    } else {
      next.add(a);
      Iterable<ProductItem> test = catalogItems;
      if (selectedCategory != '전체') test = test.where((it) => it.category == selectedCategory);
      test = test.where((it) => next.every((a) => it.attrs.contains(a)));
      if (test.isEmpty) {
        _toast('이 조합에 해당하는 품목이 없어요.');
        return;
      }
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
    setState(() {
      final next = weightKg + deltaKg;
      weightKg = (next < 0) ? 0 : next;
    });
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
    final payload = <String, dynamic>{
      "type": "product_pack",
      "tempId": newTempId,
      "producer": producer,
      "producedAt": producedAt!.toIso8601String().substring(0, 10),
      "sku": selectedItem!.sku,
      "name": selectedItem!.name,
      "qty": qty,
      "weightKg": weightKg,
      "perSheetG": 0,
      "category": selectedItem!.category,
      "attrs": selectedItem!.attrs.join(", "),
      "version": 1,
    };

    // ✅ JSON 데이터를 안전한 문자열(Base64)로 변환
    final jsonString = jsonEncode(payload);
    final base64Data = base64Encode(utf8.encode(jsonString));

    // ✅ 안동한지 홈페이지 URL 뒤에 데이터를 꼬리표로 붙임!
    final finalQrData = 'https://andonghanji.com/board/index.php?app_data=$base64Data';
    setState(() {
      tempId = newTempId;
      qrData = jsonEncode(payload);
    });
  }

  // ✅ 인더스트리얼 감성 100x80 라벨 디자인
  Future<void> printQr() async {
    if (qrData == null || tempId == null) { _toast('먼저 QR을 생성하세요.'); return; }

    final fontRegular = await PdfGoogleFonts.nanumGothicRegular();
    final fontBold = await PdfGoogleFonts.nanumGothicBold();
    final doc = pw.Document();

    final pageFormat = PdfPageFormat(100 * PdfPageFormat.mm, 80 * PdfPageFormat.mm);
    final productName = selectedItem?.name ?? '-';
    final isLongName = productName.length >= 8;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 2, color: PdfColors.black)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.black))),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SKU: ${selectedItem?.sku ?? "-"}', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                      pw.Text('ID: $tempId', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Container(
                        width: 60,
                        decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 2, color: PdfColors.black))),
                        alignment: pw.Alignment.center,
                        child: isLongName
                            ? pw.Transform.rotateBox(
                          angle: pi / 2,
                          child: pw.Text(productName, style: pw.TextStyle(font: fontBold, fontSize: 24)),
                        )
                            : pw.Text(productName, style: pw.TextStyle(font: fontBold, fontSize: 24), textAlign: pw.TextAlign.center),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black))),
                              child: pw.Text('PRODUCER :  ${selectedProducer ?? "-"}', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black))),
                              child: pw.Text('DATE :  ${producedAt?.year}-${producedAt?.month.toString().padLeft(2, '0')}-${producedAt?.day.toString().padLeft(2, '0')}', style: pw.TextStyle(font: fontBold, fontSize: 13)),
                            ),
                            pw.Expanded(
                              child: pw.Row(
                                children: [
                                  pw.Expanded(
                                    child: pw.Container(
                                      padding: const pw.EdgeInsets.only(left: 8, top: 4),
                                      child: pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                        mainAxisAlignment: pw.MainAxisAlignment.center,
                                        children: [
                                          pw.Text('QTY', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                                          pw.Text('$qty EA', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                                          pw.SizedBox(height: 8),
                                          pw.Text('WEIGHT', style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                                          pw.Text('${weightKg.toStringAsFixed(2)} KG', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  pw.Container(
                                    width: 40 * PdfPageFormat.mm,
                                    height: 40 * PdfPageFormat.mm,
                                    padding: const pw.EdgeInsets.all(4),
                                    decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(width: 1, color: PdfColors.black))),
                                    child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qrData!, width: 38 * PdfPageFormat.mm, height: 38 * PdfPageFormat.mm),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Widget _buildCategoryChip(String c) {
    final isSelected = selectedCategory == c;
    return Expanded(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
                showCheckmark: false,
                label: Center(child: Text(c, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87))),
                selected: isSelected,
                selectedColor: Colors.blue.shade700,
                backgroundColor: Colors.white,
                side: BorderSide(color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (_) => _setCategory(c)
            )
        )
    );
  }

  Widget _buildAttrChip(String a) {
    final bool enabled = (selectedCategory == '전체') ? true : _availableAttrsInCurrentCategory.contains(a);
    final isSelected = selectedAttrs.contains(a);
    return Expanded(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: FilterChip(
                showCheckmark: false,
                label: Center(child: Text(a, style: TextStyle(fontSize: 13, color: isSelected ? Colors.blue.shade900 : (enabled ? Colors.black87 : Colors.grey.shade400)))),
                selected: isSelected,
                onSelected: enabled ? (_) => _toggleAttr(a) : null,
                selectedColor: Colors.blue.shade50,
                backgroundColor: Colors.white,
                shape: StadiumBorder(side: BorderSide(color: isSelected ? Colors.blue.shade400 : Colors.grey.shade200))
            )
        )
    );
  }

  Widget _buildInputForm() {
    final dateText = producedAt == null ? '생산일자 선택' : '${producedAt!.year}-${producedAt!.month.toString().padLeft(2, '0')}-${producedAt!.day.toString().padLeft(2, '0')}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('생산자 *', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
            children: producers.map((p) {
              final isSelected = selectedProducer == p;
              return Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Opacity(
                          opacity: isSelected ? 1.0 : 0.6,
                          child: ChoiceChip(
                              showCheckmark: false,
                              label: Center(child: Text(p, textAlign: TextAlign.center, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blue.shade900 : Colors.black87))),
                              selected: isSelected,
                              selectedColor: Colors.blue.shade100,
                              backgroundColor: Colors.grey.shade200,
                              side: BorderSide.none,
                              onSelected: (_) {
                                setState(() => selectedProducer = p);
                                _saveData('prod_producer', p);
                              }
                          )
                      )
                  )
              );
            }).toList()
        ),
        const SizedBox(height: 16),

        const Text('생산일자 *', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.calendar_month_outlined), label: Text(dateText, style: const TextStyle(fontSize: 15))),
        const SizedBox(height: 16),

        const Text('품목 카테고리', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: productCategories.sublist(0, 4).map((c) => _buildCategoryChip(c)).toList()),
        const SizedBox(height: 8),
        Row(children: [...productCategories.sublist(4, 7).map((c) => _buildCategoryChip(c)), const Spacer()]),
        const SizedBox(height: 20),

        const Text('품목 속성 (세부 필터)', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: allProductAttrs.sublist(0, 4).map((a) => _buildAttrChip(a)).toList()),
        const SizedBox(height: 8),
        Row(children: allProductAttrs.sublist(4, 8).map((a) => _buildAttrChip(a)).toList()),
        const SizedBox(height: 20),

        DropdownButtonFormField<ProductItem>(
            value: selectedItem,
            decoration: InputDecoration(labelText: '품목 선택 *', hintText: '필터링된 품목: 총 ${_filteredItems.length}개 대기중', border: const OutlineInputBorder()),
            isExpanded: true,
            items: _filteredItems.map((it) => DropdownMenuItem(value: it, child: Text('${it.name}   (${it.sku})'))).toList(),
            onChanged: (v) => setState(() => selectedItem = v)
        ),
        const SizedBox(height: 16),

        const Text('수량', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(
            children: [
              ChoiceChip(
                  showCheckmark: false,
                  label: const Text('100장 (1 Pack)'),
                  selected: qty == 100,
                  selectedColor: Colors.blue.shade100,
                  onSelected: (_) { setState(() => qty = 100); _saveData('prod_qty', 100); }
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                  showCheckmark: false,
                  label: Text(qty == 100 ? '100장 미만 직접입력' : '낱장: $qty장 (변경)'),
                  selected: qty != 100,
                  selectedColor: Colors.blue.shade100,
                  onSelected: (_) async { await _pickQtyDialUnder100(); }
              )
            ]
        ),
        const SizedBox(height: 16),

        const Text('무게', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Colors.blue.shade50.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade100)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('총중량: ${weightKg.toStringAsFixed(2)} kg', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 15)),
                const SizedBox(height: 12),
                // ✅ FittedBox와 Row를 결합하여 절대! 두 줄로 넘어가지 않도록 강제 고정
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ActionChip(label: const Text('-0.3'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(-0.3)),
                      const SizedBox(width: 4),
                      ActionChip(label: const Text('-0.2'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(-0.2)),
                      const SizedBox(width: 4),
                      ActionChip(label: const Text('-0.1'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(-0.1)),
                      const SizedBox(width: 4),
                      ActionChip(label: const Text('3.0', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.white, visualDensity: VisualDensity.compact, onPressed: () { setState(() => weightKg = 3.0); _saveData('prod_weight', 3.0); }),
                      const SizedBox(width: 4),
                      ActionChip(label: const Text('+0.1'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(0.1)),
                      const SizedBox(width: 4),
                      ActionChip(label: const Text('+0.2'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(0.2)),
                      const SizedBox(width: 4),
                      ActionChip(label: const Text('+0.3'), padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, onPressed: () => _applyWeightDelta(0.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        FilledButton.icon(
            onPressed: generateQr,
            icon: const Icon(Icons.qr_code_2_outlined),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('QR 생성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
        ),

        if (MediaQuery.of(context).size.width < 800) ...[
          const SizedBox(height: 24),
          _buildQrResult(),
        ]
      ],
    );
  }

  Widget _buildQrResult() {
    if (qrData == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('입력 후 [QR 생성]을 누르세요.', style: TextStyle(color: Colors.grey))));
    }
    return Column(
        children: [
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
              child: QrImageView(data: qrData!, size: 200)
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: printQr,
              icon: const Icon(Icons.print),
              label: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('라벨 프린터로 인쇄', style: TextStyle(fontSize: 16)))
          ),
          const SizedBox(height: 24)
        ]
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _syncSelectedItemWithFilteredList();
    return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              if (isWide) {
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildInputForm()),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 2, child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.only(top: 32), child: _buildQrResult())))
                    ]
                );
              } else {
                return _buildInputForm();
              }
            }
        )
    );
  }
}