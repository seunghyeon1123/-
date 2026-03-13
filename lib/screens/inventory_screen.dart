// lib/screens/inventory_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../config.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const String WEBAPP_URL = AppConfig.webAppUrl;

  final Color stoneShadow = const Color(0xFF586B54);
  final Color hanjiIvory = const Color(0xFFFDFBF7);

  bool isLoading = true;

  // 원본 데이터
  List<Map<String, dynamic>> warehouseTable = [];
  List<Map<String, dynamic>> storeTable = [];
  List<List<dynamic>> inboundLogsList = [];
  String? selectedBatchId;

  // 🟢 창고 재고 검색 및 정렬용 변수
  String searchQuery = '';
  String sortOption = '최신순';

  @override
  void initState() {
    super.initState();
    _fetchAndProcessData();
  }

// 🟢 데이터 불러오기 (50만장 대비 1초 컷 초고속 로딩)
  Future<void> _fetchAndProcessData() async {
    setState(() => isLoading = true);
    try {
      // 🚀 에러 원인 해결: 구글 보안(CORS) 통과용 마법의 코드(headers) 추가!
      var res = await http.post(
          Uri.parse(WEBAPP_URL),
          headers: {'Content-Type': 'text/plain'}, // 🔥 이 줄이 없어서 웹에서 에러가 났던 겁니다.
          body: jsonEncode({"action": "getInventoryScreenData"})
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 302 || res.statusCode == 303) {
        final redirectUrl = res.headers['location'] ?? res.headers['Location'];
        if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl));
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true) {
          final invData = data['items'] as List<dynamic>? ?? [];
          final inboundData = data['inbound'] as List<dynamic>? ?? [];
          final storeData = data['store'] as List<dynamic>? ?? [];

          Map<String, Map<String, dynamic>> whMap = {};
          Map<String, Map<String, dynamic>> stMap = {};

          // 1. 이미 서버에서 정리해준 창고 재고 담기
          for (var item in invData) {
            String key = "${item['sku']}_${item['weightKg']}";
            whMap[key] = {
              "sku": item['sku'], "name": item['name'],
              "weightKg": item['weightKg'], "qty": item['qty'],
              "producer": item['producer'] ?? '-',
              "updatedAt": item['updatedAt'] ?? ''
            };
          }

          // 2. 매장 재고 합산 처리
          for (int i = 1; i < storeData.length; i++) {
            var row = storeData[i];
            String batchId = row[1]?.toString() ?? '';
            String sku = row[2]?.toString() ?? '';
            String name = row[3]?.toString() ?? '';
            int qty = int.tryParse(row[4]?.toString() ?? '0') ?? 0;
            double weight = double.tryParse(row[6]?.toString() ?? '0') ?? 0.0;
            String key = "${sku}_${weight}";

            if (!stMap.containsKey(key)) stMap[key] = {"sku": sku, "name": name, "weightKg": weight, "qty": 0};
            stMap[key]!['qty'] += qty;

            if (!batchId.endsWith("-OUT") && whMap.containsKey(key)) {
              whMap[key]!['qty'] -= qty;
            }
          }

          // 3. 재출력용 최근 200건 로그 정리
          List<List<dynamic>> tempLogs = [];
          for (int i = 1; i < inboundData.length; i++) {
            if (inboundData[i][1] == 'inbound' || inboundData[i][1] == 'inbound_bgrade') {
              tempLogs.add(inboundData[i]);
            }
          }

          setState(() {
            warehouseTable = whMap.values.where((e) => e['qty'] > 0).toList();
            storeTable = stMap.values.where((e) => e['qty'] > 0).toList();
            inboundLogsList = tempLogs.reversed.toList();
            selectedBatchId = null;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('데이터 로드 실패: $e')));
        setState(() => isLoading = false);
      }
    }
  }
  // 🟢 창고 재고 정렬 및 검색 처리 로직
  List<Map<String, dynamic>> get processedWarehouseData {
    var list = warehouseTable.where((e) {
      if (searchQuery.isEmpty) return true;
      final name = e['name'].toString().toLowerCase();
      final producer = e['producer'].toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return name.contains(query) || producer.contains(query);
    }).toList();

    list.sort((a, b) {
      if (sortOption == '품명순') return a['name'].toString().compareTo(b['name'].toString());
      if (sortOption == '생산자순') return a['producer'].toString().compareTo(b['producer'].toString());
      // 기본은 최신순 (시간 역순)
      return b['updatedAt'].toString().compareTo(a['updatedAt'].toString());
    });
    return list;
  }

  // 소수점 1자리로 깔끔하게 포맷팅하는 함수
  String formatWeight(dynamic w) {
    double? parsed = double.tryParse(w.toString());
    if (parsed == null) return "0.0";
    return parsed.toStringAsFixed(1);
  }

  PdfColor _getWeightColor(double w) {
    if (w >= 3.4) return PdfColor.fromHex('#3D5361'); if (w >= 3.1) return PdfColor.fromHex('#9C5D41'); if (w >= 2.8) return PdfColor.fromHex('#999B84'); if (w >= 2.5) return PdfColor.fromHex('#C0A290'); if (w >= 2.2) return PdfColor.fromHex('#B8C1C1'); return PdfColor.fromHex('#ECE4DD');
  }
  PdfColor _getTextColorForWeight(double w) { if (w >= 3.1) return PdfColors.white; return PdfColors.black; }

  // 라벨 재출력 로직 (변경 없음)
  Future<void> _reprintLabel() async {
    if (selectedBatchId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('먼저 출력할 내역을 선택하세요.'))); return; }
    final row = inboundLogsList.firstWhere((element) => element[2].toString() == selectedBatchId, orElse: () => []);
    if (row.isEmpty) return;

    try {
      final batchId = row[2]?.toString() ?? '';
      final tempId = row[3]?.toString() ?? '';
      final sku = row[4]?.toString() ?? '';
      final name = row[5]?.toString() ?? '';
      final producer = row[6]?.toString() ?? '';
      final producedAt = row[7]?.toString() ?? '';
      final qty = int.tryParse(row[8]?.toString() ?? '100') ?? 100;
      final weightKg = double.tryParse(row[9]?.toString() ?? '3.0') ?? 3.0;
      final gsm = row[18]?.toString() ?? '';
      final lye = row[19]?.toString() ?? '';
      final drying = row[21]?.toString() ?? '열판건조';
      final dochim = row[22]?.toString() ?? '';

      final payload = { "type": "product_pack", "tempId": tempId, "sku": sku, "name": name, "producer": producer, "producedAt": producedAt, "qty": qty, "weightKg": weightKg, "gsm": gsm, "lye": lye, "drying": drying, "dochim": dochim };
      final jsonString = jsonEncode(payload);
      final base64Data = base64Encode(utf8.encode(jsonString));
      final qrData = 'https://andonghanji.com/board/index.php?app_data=$base64Data';
      final customerUrl = "https://andonghanji.com/product/$sku";

      pw.Font fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
      pw.Font fontMedium = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Medium.ttf'));
      pw.Font fontLight = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-ExtraLight.ttf'));
      pw.Font fallbackFont = pw.Font.ttf(await rootBundle.load('assets/fonts/PretendardJP-Bold.ttf'));
      final imageBytes = await rootBundle.load('assets/images/logo.png');
      final logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());

      String dateStr = producedAt;
      if (producedAt.length >= 10) {
        try { DateTime dt = DateTime.parse(producedAt.substring(0, 10)); dateStr = '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}'; } catch (_) {}
      }

      final doc = pw.Document();
      final pageFormat = PdfPageFormat(100 * PdfPageFormat.mm, 100 * PdfPageFormat.mm);

      doc.addPage(pw.Page(pageFormat: pageFormat, margin: pw.EdgeInsets.all(4 * PdfPageFormat.mm), build: (pw.Context context) {
        return pw.Stack(fit: pw.StackFit.expand, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [ pw.Text('ANDONG HANJI [REPRINT]', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)), pw.SizedBox(height: 4), pw.Text(name, style: pw.TextStyle(font: fontBold, fontSize: 24, fontFallback: [fallbackFont])), pw.SizedBox(height: 4), pw.Text(dateStr, style: pw.TextStyle(font: fontLight, fontSize: 12)), ])),
              pw.Column(children: [ pw.Container(width: 18 * PdfPageFormat.mm, height: 18 * PdfPageFormat.mm, child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: customerUrl)), pw.SizedBox(height: 2), pw.Text('제품 정보 확인', style: pw.TextStyle(font: fontMedium, fontSize: 7, fontFallback: [fallbackFont])), ])
            ]),
            pw.SizedBox(height: 10), pw.Container(height: 0.5, color: PdfColors.black), pw.SizedBox(height: 10),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [ pw.Text('생산자: $producer 장인', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])), pw.Text('수량: $qty 장', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])), ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [ pw.Text('중량: ${weightKg.toStringAsFixed(1)}kg', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])), pw.Text('평량: $gsm g/m²', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])), ]),
            ]),
            pw.Spacer(), pw.Text('FOR INTERNAL MANAGEMENT (BATCH: $batchId)', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey600)), pw.SizedBox(height: 2),
            pw.Container(height: 18 * PdfPageFormat.mm, child: pw.BarcodeWidget(barcode: pw.Barcode.pdf417(), data: qrData, drawText: false)), pw.SizedBox(height: 4),
            pw.Center(child: pw.SizedBox(height: 8 * PdfPageFormat.mm, child: pw.Image(logoImage))),
          ]),
          pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(width: 1, color: PdfColors.black))),
        ]);
      }));
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'reprint_$batchId');
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('라벨 재출력 오류: $e'))); }
  }

  // 🟢 창고 보관 재고 (스크롤 + 검색/정렬 UI)
  Widget _buildWarehouseSection() {
    final list = processedWarehouseData;

    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: stoneShadow.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              Icon(Icons.inventory_2, color: stoneShadow), const SizedBox(width: 8),
              Text('창고 보관 재고 (미개봉)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: stoneShadow)),
            ]),
          ),

          // 검색 및 정렬 컨트롤 컨트롤
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '품명 또는 생산자 검색...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true, contentPadding: const EdgeInsets.all(8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: sortOption,
                    decoration: InputDecoration(
                      isDense: true, contentPadding: const EdgeInsets.all(8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: ['최신순', '품명순', '생산자순'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
                    onChanged: (val) => setState(() => sortOption = val!),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 🟢 일정 높이에서 스크롤 되도록 박스 처리
          Container(
            height: 350, // 350픽셀 높이 안에서 스크롤
            color: Colors.grey.shade50,
            child: list.isEmpty
                ? const Center(child: Text('검색 결과가 없습니다.'))
                : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final e = list[index];
                final dateStr = e['updatedAt'].toString().length > 10 ? e['updatedAt'].toString().substring(0, 10) : '';
                return Card(
                  elevation: 1, color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('장인: ${e['producer']}  |  마지막 입고: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${formatWeight(e['weightKg'])} kg', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('${e['qty']} 장', style: TextStyle(fontWeight: FontWeight.w900, color: stoneShadow, fontSize: 18)),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 매장 낱장 진열 재고 (심플한 표, SKU 제거)
  Widget _buildStoreTable() {
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: Row(children: [
              Icon(Icons.storefront, color: Colors.orange.shade800), const SizedBox(width: 8),
              Text('매장 낱장 진열 재고', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange.shade800)),
            ]),
          ),
          if (storeTable.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('보유 중인 재고가 없습니다.')))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.white),
                columns: const [
                  DataColumn(label: Text('품명', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('중량', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('진열 수량', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: storeTable.map((e) => DataRow(cells: [
                  DataCell(Text(e['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('${formatWeight(e['weightKg'])} kg')),
                  DataCell(Text('${e['qty']} 장', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 15))),
                ])).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: hanjiIvory,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('재고 및 상태 현황', style: TextStyle(color: stoneShadow, fontWeight: FontWeight.bold)),
        actions: [ IconButton(icon: Icon(Icons.refresh, color: stoneShadow), onPressed: _fetchAndProcessData, tooltip: '새로고침') ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: stoneShadow))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // 1. 창고 보관 재고 (리스트 & 검색 방식)
            _buildWarehouseSection(),

            // 2. 매장 낱장 재고 (심플 표)
            _buildStoreTable(),

            const Divider(height: 48, thickness: 2),

            // 3. 라벨 재출력 (검색 드롭다운)
            const Text('🖨️ 분실/손상 라벨 재출력', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('생산자, 품명, 날짜 등을 검색하여 기존 라벨을 다시 인쇄합니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),

            LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownMenu<String>(
                    width: constraints.maxWidth,
                    menuHeight: 300, enableFilter: true, enableSearch: true,
                    hintText: '품명, 생산자, 날짜 입력...',
                    textStyle: const TextStyle(fontSize: 14),
                    onSelected: (value) => setState(() => selectedBatchId = value),
                    dropdownMenuEntries: inboundLogsList.map((row) {
                      final bId = row[2].toString();
                      final name = row[5].toString();
                      final producer = row[6].toString();
                      final date = row[0].toString().length > 10 ? row[0].toString().substring(0, 10) : row[0].toString();

                      return DropdownMenuEntry<String>(
                        value: bId,
                        label: '[$date] $name - $producer',
                      );
                    }).toList(),
                  );
                }
            ),
            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: selectedBatchId == null ? null : _reprintLabel,
              style: FilledButton.styleFrom(
                  backgroundColor: stoneShadow, padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey.shade300
              ),
              icon: const Icon(Icons.print),
              label: const Text('선택한 라벨 인쇄하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}