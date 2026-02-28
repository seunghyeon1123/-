// lib/screens/inventory_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/product_catalog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const String WEBAPP_URL = AppConfig.webAppUrl;
  bool loading = false; String? error;
  List<Map<String, dynamic>> items = []; String q = '';
  List<String> warehouses = ['전체']; String selectedWarehouse = '전체'; String selectedCategory = '전체'; Set<String> selectedAttrs = {};
  int? sortColumnIndex; bool sortAscending = true; int rowsPerPage = 20; DateTime? lastFetchedAt;
  late final _InventoryDataSource dataSource; late final Map<String, ProductItem> _catalogMap;

  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    dataSource = _InventoryDataSource([]);
    _catalogMap = {for (var item in catalogItems) item.sku: item};
    load();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  String s(Map<String, dynamic> it, String key, [String fallback = '-']) { final v = it[key]; if (v == null) return fallback; final str = v.toString().trim(); return str.isEmpty ? fallback : str; }
  num? _tryNum(Map<String, dynamic> it, String key) { final v = it[key]; if (v == null) return null; if (v is num) return v; final str = v.toString().replaceAll(',', '').trim(); return str.isEmpty ? null : num.tryParse(str); }
  num pickNum(Map<String, dynamic> it, List<String> keys) { for (final k in keys) { final parsed = _tryNum(it, k); if (parsed != null) return parsed; } return 0; }

  List<Map<String, dynamic>> _filteredBase() {
    var view = items;
    final t = q.trim().toLowerCase();
    if (t.isNotEmpty) view = view.where((it) { return s(it, 'sku', '').toLowerCase().contains(t) || s(it, 'name', '').toLowerCase().contains(t) || s(it, 'locationCode', '').toLowerCase().contains(t); }).toList();
    if (selectedWarehouse != '전체') view = view.where((it) => s(it, 'warehouse', '') == selectedWarehouse).toList();
    if (selectedCategory != '전체' || selectedAttrs.isNotEmpty) {
      view = view.where((it) {
        final meta = _catalogMap[s(it, 'sku', '')];
        if (meta == null) return false;
        if (selectedCategory != '전체' && meta.category != selectedCategory) return false;
        if (selectedAttrs.isNotEmpty && !selectedAttrs.every((a) => meta.attrs.contains(a))) return false;
        return true;
      }).toList();
    }
    return view;
  }

  void _applyFilterAndSort() {
    final view = _filteredBase();
    if (sortColumnIndex != null) {
      // ✅ SKU, 창고, 생산자가 빠졌으므로 인덱스를 새로 맞췄습니다.
      switch (sortColumnIndex) {
        case 0: view.sort((a, b) => sortAscending ? s(a, 'name', '').compareTo(s(b, 'name', '')) : s(b, 'name', '').compareTo(s(a, 'name', ''))); break;
        case 1: view.sort((a, b) => sortAscending ? s(a, 'locationCode', '').compareTo(s(b, 'locationCode', '')) : s(b, 'locationCode', '').compareTo(s(a, 'locationCode', ''))); break;
        case 2: view.sort((a, b) => sortAscending ? pickNum(a, ['qty', 'qtyTotal']).compareTo(pickNum(b, ['qty', 'qtyTotal'])) : pickNum(b, ['qty', 'qtyTotal']).compareTo(pickNum(a, ['qty', 'qtyTotal']))); break;
        case 3: view.sort((a, b) => sortAscending ? pickNum(a, ['weightKg']).compareTo(pickNum(b, ['weightKg'])) : pickNum(b, ['weightKg']).compareTo(pickNum(a, ['weightKg']))); break;
        case 4: view.sort((a, b) { final av = s(a, 'updatedAt', ''); final bv = s(b, 'updatedAt', ''); return sortAscending ? av.compareTo(bv) : bv.compareTo(av); }); break;
      }
    }
    dataSource.update(view);
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final payload = {
        "action": "inventory",
        "ts": DateTime.now().millisecondsSinceEpoch
      };
      var res = await http.post(
          Uri.parse(WEBAPP_URL),
          headers: {'Content-Type': 'text/plain'},
          body: jsonEncode(payload)
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode == 302 || res.statusCode == 303) {
        final redirectUrl = res.headers['location'] ?? res.headers['Location'];
        if (redirectUrl != null) {
          res = await http.get(Uri.parse(redirectUrl)).timeout(const Duration(seconds: 45));
        }
      }

      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final decoded = jsonDecode(res.body);
      if (decoded['ok'] != true) throw Exception(decoded['error']?.toString() ?? 'unknown');

      final list = (decoded['items'] as List?) ?? [];
      final parsed = list.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();

      final whSet = {'전체'};
      for (var row in parsed) { final w = s(row, 'warehouse', ''); if (w.isNotEmpty && w != '-') whSet.add(w); }

      setState(() { items = parsed; warehouses = whSet.toList(); lastFetchedAt = DateTime.now(); });
      _applyFilterAndSort();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  void _onSort(int columnIndex, bool ascending) { setState(() { sortColumnIndex = columnIndex; sortAscending = ascending; }); _applyFilterAndSort(); }
  String _fmtTime(DateTime? t) { if (t == null) return '-'; return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}'; }
  void _toggleAttr(String a) { setState(() { if (selectedAttrs.contains(a)) { selectedAttrs.remove(a); } else { selectedAttrs.add(a); } }); _applyFilterAndSort(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('재고 현황(표)'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'SKU / 품목명 / 위치코드 검색', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 0)), onChanged: (v) { setState(() => q = v); _applyFilterAndSort(); })),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ExpansionTile(
                title: const Text('상세 필터 (창고 / 종류 / 태그)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: '창고', border: OutlineInputBorder(), isDense: true), value: selectedWarehouse, items: warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(), onChanged: (v) { setState(() => selectedWarehouse = v!); _applyFilterAndSort(); })), const SizedBox(width: 8),
                    Expanded(child: DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: '카테고리', border: OutlineInputBorder(), isDense: true), value: selectedCategory, items: productCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { setState(() => selectedCategory = v!); _applyFilterAndSort(); })),
                  ]), const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6, children: allProductAttrs.map((a) { final selected = selectedAttrs.contains(a); return FilterChip(label: Text(a), selected: selected, onSelected: (_) => _toggleAttr(a), visualDensity: VisualDensity.compact); }).toList()),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Text('마지막 갱신: ${_fmtTime(lastFetchedAt)}   |   표시: ${dataSource.rowCount}건', style: TextStyle(color: Colors.black.withOpacity(0.65)))),
            if (loading) const Center(child: CircularProgressIndicator())
            else if (error != null) Center(child: Text('불러오기 실패\n$error', textAlign: TextAlign.center))
            else Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // ✅ 테이블 너비를 1000에서 600으로 줄여서 열 간격을 좁히고 한눈에 들어오게 압축!
                        final double tableWidth = constraints.maxWidth < 600 ? 600 : constraints.maxWidth;
                        return Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: PaginatedDataTable(
                                columnSpacing: 24, // ✅ 열 사이 간격을 적당히 좁힘
                                horizontalMargin: 16,
                                rowsPerPage: rowsPerPage, availableRowsPerPage: const [10, 20, 50, 100], onRowsPerPageChanged: (v) { if (v != null) setState(() => rowsPerPage = v); }, sortColumnIndex: sortColumnIndex, sortAscending: sortAscending,
                                // ✅ 딱 필요한 5개 열만 남김
                                columns: [
                                  DataColumn(label: const Text('품목명', style: TextStyle(fontWeight: FontWeight.w800)), onSort: _onSort),
                                  DataColumn(label: const Text('위치코드', style: TextStyle(fontWeight: FontWeight.w800)), onSort: _onSort),
                                  DataColumn(numeric: true, label: const Text('수량', style: TextStyle(fontWeight: FontWeight.w800)), onSort: _onSort),
                                  DataColumn(numeric: true, label: const Text('무게(kg)', style: TextStyle(fontWeight: FontWeight.w800)), onSort: _onSort),
                                  DataColumn(label: const Text('변동일', style: TextStyle(fontWeight: FontWeight.w800)), onSort: _onSort),
                                ], source: dataSource,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InventoryDataSource extends DataTableSource {
  List<Map<String, dynamic>> _rows;
  _InventoryDataSource(this._rows);

  void update(List<Map<String, dynamic>> next) { _rows = next; notifyListeners(); }
  String _fmtKg(num v) => v.toDouble().toStringAsFixed(2);
  String _s(Map<String, dynamic> it, String key, [String fallback = '-']) { final v = it[key]; if (v == null) return fallback; final str = v.toString().trim(); return str.isEmpty ? fallback : str; }
  num? _tryNum(Map<String, dynamic> it, String key) { final v = it[key]; if (v == null) return null; if (v is num) return v; final str = v.toString().replaceAll(',', '').trim(); return str.isEmpty ? null : num.tryParse(str); }
  num _pickNum(Map<String, dynamic> it, List<String> keys) { for (final k in keys) { final parsed = _tryNum(it, k); if (parsed != null) return parsed; } return 0; }
  String _formatDate(String isoStr) { if (isoStr.isEmpty || isoStr == '-') return '-'; if (isoStr.length >= 10) return isoStr.substring(0, 10); return isoStr; }

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= _rows.length) return null;
    final it = _rows[index];
    return DataRow.byIndex(
      index: index,
      // ✅ 요청하신 순서대로 딱 5개 열만 매칭! 무게는 합산(weightKgTotal)을 버리고 고유 무게(weightKg)만 표시합니다.
      cells: [
        DataCell(SelectableText(_s(it, 'name', '-'))),
        DataCell(SelectableText(_s(it, 'locationCode', '-'))),
        DataCell(Text(_pickNum(it, ['qty', 'qtyTotal']).toString())),
        DataCell(Text(_fmtKg(_pickNum(it, ['weightKg'])))),
        DataCell(Text(_formatDate(_s(it, 'updatedAt', '-')))),
      ],
    );
  }

  @override bool get isRowCountApproximate => false;
  @override int get rowCount => _rows.length;
  @override int get selectedRowCount => 0;
}