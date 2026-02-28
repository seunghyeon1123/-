// lib/screens/location_qr_create_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationQrCreateScreen extends StatefulWidget {
  const LocationQrCreateScreen({super.key});
  @override
  State<LocationQrCreateScreen> createState() => _LocationQrCreateScreenState();
}

class _LocationQrCreateScreenState extends State<LocationQrCreateScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ✅ 한지 아이보리 & 스톤 섀도우(다크그린) 컬러 세팅
  final Color hanjiIvory = const Color(0xFFFDFBF7);
  final Color stoneShadow = const Color(0xFF586B54);
  final Color textDark = const Color(0xFF333333);

  final warehouseCtrl = TextEditingController();
  final zoneCtrl = TextEditingController();
  final rackCtrl = TextEditingController();
  final binCtrl = TextEditingController();

  String? locationCode;
  String? qrData;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    warehouseCtrl.addListener(() => _saveData('loc_wh', warehouseCtrl.text));
    zoneCtrl.addListener(() => _saveData('loc_zone', zoneCtrl.text));
    rackCtrl.addListener(() => _saveData('loc_rack', rackCtrl.text));
    binCtrl.addListener(() => _saveData('loc_bin', binCtrl.text));
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      warehouseCtrl.text = prefs.getString('loc_wh') ?? 'WH1';
      zoneCtrl.text = prefs.getString('loc_zone') ?? 'A';
      rackCtrl.text = prefs.getString('loc_rack') ?? '01';
      binCtrl.text = prefs.getString('loc_bin') ?? '01';
    });
  }

  Future<void> _saveData(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value);
  }

  @override
  void dispose() {
    warehouseCtrl.dispose(); zoneCtrl.dispose();
    rackCtrl.dispose(); binCtrl.dispose();
    super.dispose();
  }

  void generateLocationQr() {
    final wh = warehouseCtrl.text.trim();
    final zone = zoneCtrl.text.trim();
    final rack = rackCtrl.text.trim();
    final bin = binCtrl.text.trim();

    if (wh.isEmpty || zone.isEmpty || rack.isEmpty || bin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('모두 필수입니다.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: stoneShadow, // 에러 메시지도 스톤 섀도우 톤으로
      ));
      return;
    }
    final code = '$wh-$zone-$rack-$bin';
    final payload = { "type": "location", "warehouse": wh, "zone": zone, "rack": rack, "bin": bin, "locationCode": code, "version": 1 };
    setState(() { locationCode = code; qrData = jsonEncode(payload); });
  }

  void resetForm() {
    setState(() { warehouseCtrl.text = 'WH1'; zoneCtrl.text = 'A'; rackCtrl.text = '01'; binCtrl.text = '01'; locationCode = null; qrData = null; });
  }

  Future<void> printLocationQr() async {
    if (qrData == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('먼저 위치 QR을 생성하세요.'), backgroundColor: stoneShadow));
      return;
    }
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, 60 * PdfPageFormat.mm),
      build: (pw.Context context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('위치 라벨', style: pw.TextStyle(fontSize: 10)), pw.SizedBox(height: 6),
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: qrData!, width: 120, height: 120),
              pw.SizedBox(height: 6), pw.Text('LOC: ${locationCode ?? "-"}', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
        );
      },
    ));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  // ✅ 공통 텍스트 필드 스타일 디자인 (코드 중복 방지)
  InputDecoration _customInputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: stoneShadow),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: stoneShadow, width: 2), borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildInputForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('위치 정보 입력', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: stoneShadow)), const SizedBox(height: 12),
        TextField(controller: warehouseCtrl, decoration: _customInputDeco('창고 코드 (예: WH1) *')), const SizedBox(height: 12),
        TextField(controller: zoneCtrl, decoration: _customInputDeco('구역 (예: A) *')), const SizedBox(height: 12),
        TextField(controller: rackCtrl, decoration: _customInputDeco('랙 (예: 01) *')), const SizedBox(height: 12),
        TextField(controller: binCtrl, decoration: _customInputDeco('빈/칸 (예: 01) *')), const SizedBox(height: 20),

        FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: stoneShadow),
            onPressed: generateLocationQr,
            icon: const Icon(Icons.qr_code_2_outlined),
            label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('위치 QR 생성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
        ),

        if (MediaQuery.of(context).size.width < 800) ...[ const SizedBox(height: 24), _buildQrResult(), ]
      ],
    );
  }

  Widget _buildQrResult() {
    if (qrData == null) return Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('입력 후 [위치 QR 생성]을 누르세요.', style: TextStyle(color: stoneShadow.withOpacity(0.5)))));
    return Column(
      children: [
        Text('위치 코드: $locationCode', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: textDark)),
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
            child: QrImageView(data: qrData!, version: QrVersions.auto, size: 220)
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: stoneShadow),
            onPressed: printLocationQr,
            icon: const Icon(Icons.print),
            label: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('QR 인쇄', style: TextStyle(fontSize: 16)))
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      // ✅ 전체 배경 한지 아이보리
      backgroundColor: hanjiIvory,
      appBar: AppBar(
          backgroundColor: hanjiIvory,
          elevation: 0,
          iconTheme: IconThemeData(color: stoneShadow),
          titleTextStyle: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.bold),
          title: const Text('위치 QR 생성'),
          actions: [IconButton(onPressed: resetForm, icon: const Icon(Icons.refresh), tooltip: '초기화')]
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _buildInputForm()),
              VerticalDivider(width: 1, color: Colors.grey.shade300),
              Expanded(flex: 2, child: SingleChildScrollView(padding: const EdgeInsets.only(top: 24), child: _buildQrResult()))
            ]);
          } else return _buildInputForm();
        },
      ),
    );
  }
}