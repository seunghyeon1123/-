// lib/screens/location_qr_create_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ 상태 저장 플러그인

class LocationQrCreateScreen extends StatefulWidget {
  const LocationQrCreateScreen({super.key});

  @override
  State<LocationQrCreateScreen> createState() => _LocationQrCreateScreenState();
}

// ✅ 탭 간 이동 시 상태 유지를 위한 AutomaticKeepAliveClientMixin
class _LocationQrCreateScreenState extends State<LocationQrCreateScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final warehouseCtrl = TextEditingController();
  final zoneCtrl = TextEditingController();
  final rackCtrl = TextEditingController();
  final binCtrl = TextEditingController();

  String? locationCode;
  String? qrData;

  @override
  void initState() {
    super.initState();
    _loadSavedData(); // ✅ 앱 실행 시 저장된 값 불러오기

    // 입력값이 바뀔 때마다 자동 저장
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
    warehouseCtrl.dispose();
    zoneCtrl.dispose();
    rackCtrl.dispose();
    binCtrl.dispose();
    super.dispose();
  }

  void generateLocationQr() {
    final wh = warehouseCtrl.text.trim();
    final zone = zoneCtrl.text.trim();
    final rack = rackCtrl.text.trim();
    final bin = binCtrl.text.trim();

    if (wh.isEmpty || zone.isEmpty || rack.isEmpty || bin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('창고/구역/랙/빈은 모두 필수입니다.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final code = '$wh-$zone-$rack-$bin';

    final payload = <String, dynamic>{
      "type": "location",
      "warehouse": wh,
      "zone": zone,
      "rack": rack,
      "bin": bin,
      "locationCode": code,
      "version": 1,
    };

    setState(() {
      locationCode = code;
      qrData = jsonEncode(payload);
    });
  }

  void resetForm() {
    setState(() {
      warehouseCtrl.text = 'WH1';
      zoneCtrl.text = 'A';
      rackCtrl.text = '01';
      binCtrl.text = '01';
      locationCode = null;
      qrData = null;
    });
  }

  Future<void> printLocationQr() async {
    if (qrData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 위치 QR을 생성하세요.'), behavior: SnackBarBehavior.floating),
      );
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
                pw.Text('위치 라벨', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData!,
                  width: 120,
                  height: 120,
                ),
                pw.SizedBox(height: 6),
                pw.Text('LOC: ${locationCode ?? "-"}', style: pw.TextStyle(fontSize: 9)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  // ✅ 좌측: 입력 폼 영역
  Widget _buildInputForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('위치 정보 입력', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        TextField(
          controller: warehouseCtrl,
          decoration: const InputDecoration(labelText: '창고 코드 (예: WH1) *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: zoneCtrl,
          decoration: const InputDecoration(labelText: '구역 (예: A) *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: rackCtrl,
          decoration: const InputDecoration(labelText: '랙 (예: 01) *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: binCtrl,
          decoration: const InputDecoration(labelText: '빈/칸 (예: 01) *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: generateLocationQr,
          icon: const Icon(Icons.qr_code_2_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('위치 QR 생성', style: TextStyle(fontSize: 16)),
          ),
        ),

        // 좁은 스마트폰 화면에서는 입력폼 바로 밑에 QR 표시
        if (MediaQuery.of(context).size.width < 800) ...[
          const SizedBox(height: 24),
          _buildQrResult(),
        ]
      ],
    );
  }

  // ✅ 우측/하단: QR 결과 영역
  Widget _buildQrResult() {
    if (qrData == null) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(32), child: Text('입력 후 [위치 QR 생성]을 누르세요.')),
      );
    }

    return Column(
      children: [
        Text('위치 코드: $locationCode', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 16),
        Center(child: QrImageView(data: qrData!, version: QrVersions.auto, size: 220)),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: printLocationQr, icon: const Icon(Icons.print), label: const Text('QR 인쇄')),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // KeepAlive 필수 호출

    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 QR 생성'),
        actions: [
          IconButton(onPressed: resetForm, icon: const Icon(Icons.refresh), tooltip: '초기화'),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          if (isWide) {
            // 태블릿/PC: 좌우 분할
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildInputForm()),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: SingleChildScrollView(padding: const EdgeInsets.only(top: 24), child: _buildQrResult())),
              ],
            );
          } else {
            // 모바일: 스크롤
            return _buildInputForm();
          }
        },
      ),
    );
  }
}