// lib/screens/inventory_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode_widget/barcode_widget.dart'; // 바코드 패키지
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
  List<List<dynamic>> inboundData = [];
  List<List<dynamic>> storeData = [];

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => isLoading = true);
    try {
      var res = await http.post(Uri.parse(WEBAPP_URL), headers: {'Content-Type': 'text/plain'}, body: jsonEncode({"action": "getInventory"})).timeout(const Duration(seconds: 45));
      if (res.statusCode == 302 || res.statusCode == 303) {
        final redirectUrl = res.headers['location'] ?? res.headers['Location'];
        if (redirectUrl != null) res = await http.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 45));
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['ok'] == true) {
          setState(() {
            inboundData = List<List<dynamic>>.from(decoded['inbound'] ?? []);
            storeData = List<List<dynamic>>.from(decoded['store'] ?? []);
            isLoading = false;
          });
        } else { throw Exception('데이터 로드 실패'); }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('조회 실패: $e'), backgroundColor: Colors.red));
        setState(() => isLoading = false);
      }
    }
  }

  PdfColor _getWeightColor(double w) {
    if (w >= 3.4) return PdfColor.fromHex('#3D5361'); if (w >= 3.1) return PdfColor.fromHex('#9C5D41'); if (w >= 2.8) return PdfColor.fromHex('#999B84'); if (w >= 2.5) return PdfColor.fromHex('#C0A290'); if (w >= 2.2) return PdfColor.fromHex('#B8C1C1'); return PdfColor.fromHex('#ECE4DD');
  }
  PdfColor _getTextColorForWeight(double w) { if (w >= 3.1) return PdfColors.white; return PdfColors.black; }

  // 🟢 입고된 데이터를 바탕으로 라벨을 완벽하게 재구성하여 출력하는 함수
  Future<void> _reprintLabel(List<dynamic> row) async {
    try {
      // 1. 시트 데이터 파싱 (인덱스 구조에 맞게 매핑)
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

      // 2. 바코드에 담을 원본 데이터 복원
      final payload = {
        "type": "product_pack",
        "tempId": tempId, // 원래의 tempId를 써야 중복 방지가 유지됨!
        "sku": sku,
        "name": name,
        "producer": producer,
        "producedAt": producedAt,
        "qty": qty,
        "weightKg": weightKg,
        "gsm": gsm,
        "lye": lye,
        "drying": drying,
        "dochim": dochim
      };

      final jsonString = jsonEncode(payload);
      final base64Data = base64Encode(utf8.encode(jsonString));
      final qrData = 'https://andonghanji.com/board/index.php?app_data=$base64Data';
      final customerUrl = "https://andonghanji.com/product/$sku";

      // 3. 폰트 및 로고 불러오기
      pw.Font fontBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
      pw.Font fontMedium = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Medium.ttf'));
      pw.Font fontLight = pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-ExtraLight.ttf'));
      pw.Font fallbackFont = pw.Font.ttf(await rootBundle.load('assets/fonts/PretendardJP-Bold.ttf'));
      final imageBytes = await rootBundle.load('assets/images/logo.png');
      final logoImage = pw.MemoryImage(imageBytes.buffer.asUint8List());

      // 4. 날짜 포맷팅
      String dateStr = producedAt;
      if (producedAt.length >= 10) {
        try {
          DateTime dt = DateTime.parse(producedAt.substring(0, 10));
          dateStr = '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
        } catch (_) {}
      }

      final doc = pw.Document();
      final pageFormat = PdfPageFormat(100 * PdfPageFormat.mm, 100 * PdfPageFormat.mm);
      final bgColor = _getWeightColor(weightKg);
      final txtColor = _getTextColorForWeight(weightKg);

      // 5. PDF 그리기 (이전 화면의 디자인과 100% 동일)
      doc.addPage(pw.Page(pageFormat: pageFormat, margin: pw.EdgeInsets.all(4 * PdfPageFormat.mm), build: (pw.Context context) {
        return pw.Stack(fit: pw.StackFit.expand, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('ANDONG HANJI [REPRINT]', style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text(name, style: pw.TextStyle(font: fontBold, fontSize: 24, fontFallback: [fallbackFont])),
                pw.SizedBox(height: 4),
                pw.Text(dateStr, style: pw.TextStyle(font: fontLight, fontSize: 12)),
              ])),
              pw.Column(children: [
                pw.Container(width: 18 * PdfPageFormat.mm, height: 18 * PdfPageFormat.mm, child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: customerUrl)),
                pw.SizedBox(height: 2),
                pw.Text('제품 정보 확인', style: pw.TextStyle(font: fontMedium, fontSize: 7, fontFallback: [fallbackFont])),
              ])
            ]),
            pw.SizedBox(height: 10), pw.Container(height: 0.5, color: PdfColors.black), pw.SizedBox(height: 10),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('생산자: $producer 장인', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])),
                pw.Text('수량: $qty 장', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('중량: ${weightKg.toStringAsFixed(1)}kg', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])),
                pw.Text('평량: $gsm g/m²', style: pw.TextStyle(font: fontMedium, fontSize: 14, fontFallback: [fallbackFont])),
              ]),
            ]),
            pw.Spacer(),
            pw.Text('FOR INTERNAL MANAGEMENT (BATCH: $batchId)', style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Container(height: 18 * PdfPageFormat.mm, child: pw.BarcodeWidget(barcode: pw.Barcode.pdf417(), data: qrData, drawText: false)),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.SizedBox(height: 8 * PdfPageFormat.mm, child: pw.Image(logoImage))),
          ]),
          pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(width: 1, color: PdfColors.black))),
        ]);
      }));

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'reprint_$batchId');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('라벨 재출력 오류: $e')));
    }
  }

  Widget _buildInboundTab() {
    if (inboundData.length <= 1) return const Center(child: Text('창고 입고 내역이 없습니다.'));

    // 헤더(0번째 인덱스) 제외하고 데이터만 역순(최신순)으로 정렬
    final items = inboundData.sublist(1).reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final row = items[index];
        final time = row[0]?.toString() ?? '';
        final type = row[1]?.toString() ?? '';
        final batchId = row[2]?.toString() ?? '';
        final name = row[5]?.toString() ?? '알 수 없음';
        final qty = row[8]?.toString() ?? '0';
        final location = row[14]?.toString() ?? '창고 미정';

        // 'unpack' 처리되어 매장으로 나간 건은 회색 처리
        final isUnpacked = type == 'unpack';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          color: isUnpacked ? Colors.grey.shade100 : Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(batchId, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    Text(time.length > 16 ? time.substring(0, 16).replaceAll('T', ' ') : time, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, decoration: isUnpacked ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Text('$qty 장'),
                    const SizedBox(width: 16),
                    const Icon(Icons.place_outlined, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(location),
                    if (isUnpacked) ...[
                      const Spacer(),
                      const Text('매장 개봉됨', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))
                    ]
                  ],
                ),
                if (!isUnpacked) ...[
                  const Divider(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _reprintLabel(row),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('라벨 재출력'),
                      style: OutlinedButton.styleFrom(foregroundColor: stoneShadow, side: BorderSide(color: stoneShadow)),
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoreTab() {
    if (storeData.length <= 1) return const Center(child: Text('매장 개봉 내역이 없습니다.'));

    // 헤더 제외하고 최신순 정렬
    final items = storeData.sublist(1).reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final row = items[index];
        final time = row[0]?.toString() ?? '';
        final batchId = row[1]?.toString() ?? '';
        final name = row[3]?.toString() ?? '알 수 없음';
        final qty = row[4]?.toString() ?? '0';
        final weight = row[6]?.toString() ?? '';
        final gsm = row[7]?.toString() ?? '';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade200)),
          color: Colors.orange.shade50,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(batchId, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                    Text(time.length > 16 ? time.substring(0, 16).replaceAll('T', ' ') : time, style: TextStyle(color: Colors.orange.shade600, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 16, color: Colors.deepOrange), const SizedBox(width: 4),
                    Text('$qty 장 (진열됨)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Text('중량: ${weight}kg / 평량: $gsm', style: TextStyle(color: Colors.orange.shade800, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: hanjiIvory,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text('재고 현황', style: TextStyle(color: stoneShadow, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: Icon(Icons.refresh, color: stoneShadow), onPressed: _fetchInventory),
          ],
          bottom: TabBar(
            labelColor: stoneShadow,
            unselectedLabelColor: Colors.grey,
            indicatorColor: stoneShadow,
            tabs: const [
              Tab(icon: Icon(Icons.inventory_2), text: '창고 재고 (Pack)'),
              Tab(icon: Icon(Icons.storefront), text: '매장 재고 (낱장)'),
            ],
          ),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: stoneShadow))
            : TabBarView(
          children: [
            _buildInboundTab(),
            _buildStoreTab(),
          ],
        ),
      ),
    );
  }
}