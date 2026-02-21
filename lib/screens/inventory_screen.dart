import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const String WEBAPP_URL =
      'https://script.google.com/macros/s/AKfycbzu-6JzH2GFpWFgrihJv89SVxesTo_MX7b9PPdeFM57jjAUPQ5DKmp4Zu4yTfoC-j8/exec';

  bool loading = false;
  String? error;

  List<Map<String, dynamic>> items = [];
  String q = '';

  // ✅ 정렬 상태
  int? sortColumnIndex;
  bool sortAscending = true;

  // ✅ 페이지 크기
  int rowsPerPage = 20;

  late final _InventoryDataSource dataSource;

  @override
  void initState() {
    super.initState();
    dataSource = _InventoryDataSource([]);
    load();
  }

  // ---------- Helpers ----------
  String s(Map<String, dynamic> it, String key, [String fallback = '-']) {
    final v = it[key];
    if (v == null) return fallback;
    final str = v.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  num n(Map<String, dynamic> it, String key) {
    final v = it[key];
    if (v is num) return v;
    if (v == null) return 0;
    return num.tryParse(v.toString()) ?? 0;
  }

  List<Map<String, dynamic>> _filteredBase() {
    final t = q.trim().toLowerCase();
    if (t.isEmpty) return [...items];

    return items.where((it) {
      return s(it, 'sku', '').toLowerCase().contains(t) ||
          s(it, 'name', '').toLowerCase().contains(t) ||
          s(it, 'locationCode', '').toLowerCase().contains(t) ||
          s(it, 'warehouse', '').toLowerCase().contains(t);
    }).toList();
  }

  void _applyFilterAndSort() {
    final view = _filteredBase();

    if (sortColumnIndex != null) {
      switch (sortColumnIndex) {
        case 0: // SKU
          view.sort((a, b) {
            final av = s(a, 'sku', '');
            final bv = s(b, 'sku', '');
            return sortAscending ? av.compareTo(bv) : bv.compareTo(av);
          });
          break;
        case 1: // 품목명
          view.sort((a, b) {
            final av = s(a, 'name', '');
            final bv = s(b, 'name', '');
            return sortAscending ? av.compareTo(bv) : bv.compareTo(av);
          });
          break;
        case 2: // 창고
          view.sort((a, b) {
            final av = s(a, 'warehouse', '');
            final bv = s(b, 'warehouse', '');
            return sortAscending ? av.compareTo(bv) : bv.compareTo(av);
          });
          break;
        case 3: // 위치코드
          view.sort((a, b) {
            final av = s(a, 'locationCode', '');
            final bv = s(b, 'locationCode', '');
            return sortAscending ? av.compareTo(bv) : bv.compareTo(av);
          });
          break;
        case 4: // 수량
          view.sort((a, b) {
            final av = n(a, 'qty');
            final bv = n(b, 'qty');
            return sortAscending ? av.compareTo(bv) : bv.compareTo(av);
          });
          break;
        case 5: // 총 무게(kg)
          view.sort((a, b) {
            final av = n(a, 'weightKgTotal');
            final bv = n(b, 'weightKgTotal');
            return sortAscending ? av.compareTo(bv) : bv.compareTo(av);
          });
          break;
      }
    }

    dataSource.update(view);
  }

  // ---------- Network ----------
  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final uri = Uri.parse('$WEBAPP_URL?action=inventory');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) throw Exception('JSON 형식 아님');

      if (decoded['ok'] != true) {
        throw Exception(decoded['error']?.toString() ?? 'unknown');
      }

      final list = (decoded['items'] as List?) ?? [];
      final parsed = list
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();

      items = parsed;
      _applyFilterAndSort();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      sortColumnIndex = columnIndex;
      sortAscending = ascending;
    });
    _applyFilterAndSort();
  }

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: const Text('재고현황(표)'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'SKU / 품목명 / 위치 검색',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() => q = v);
                _applyFilterAndSort();
              },
            ),
          ),

          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            Expanded(
              child: Center(
                child: Text('불러오기 실패\n$error', textAlign: TextAlign.center),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // ✅ 핵심: PaginatedDataTable에 '유한한 width'를 줌 (무한대 방지)
                        final double tableWidth =
                        constraints.maxWidth < 980 ? 980 : constraints.maxWidth;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableWidth,
                            child: PaginatedDataTable(

                              header: Text('표시 ${dataSource.rowCount}건'),
                              rowsPerPage: rowsPerPage,
                              availableRowsPerPage: const [10, 20, 50, 100],
                              onRowsPerPageChanged: (v) {
                                if (v == null) return;
                                setState(() => rowsPerPage = v);
                              },
                              showFirstLastButtons: true,
                              sortColumnIndex: sortColumnIndex,
                              sortAscending: sortAscending,
                              columns: [
                                DataColumn(
                                  label: const Text('SKU', style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  label: const Text('품목명', style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  label: const Text('창고', style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  label: const Text('위치코드', style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  numeric: true,
                                  label: const Text('수량', style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  numeric: true,
                                  label: const Text('총 무게(kg)', style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                              ],
                              source: dataSource,
                            ),
                          ),
                        );
                      },
                    )
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InventoryDataSource extends DataTableSource {
  List<Map<String, dynamic>> _rows;

  _InventoryDataSource(this._rows);

  void update(List<Map<String, dynamic>> next) {
    _rows = next;
    notifyListeners();
  }

  String _s(Map<String, dynamic> it, String key, [String fallback = '-']) {
    final v = it[key];
    if (v == null) return fallback;
    final str = v.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  num _n(Map<String, dynamic> it, String key) {
    final v = it[key];
    if (v is num) return v;
    if (v == null) return 0;
    return num.tryParse(v.toString()) ?? 0;
  }

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= _rows.length) return null;
    final it = _rows[index];

    final sku = _s(it, 'sku', '-');
    final name = _s(it, 'name', '-');
    final wh = _s(it, 'warehouse', '-');
    final loc = _s(it, 'locationCode', '-');
    final qty = _n(it, 'qty');
    final wkg = _n(it, 'weightKgTotal');

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(SelectableText(sku)),
        DataCell(SelectableText(name)),
        DataCell(Text(wh)),
        DataCell(SelectableText(loc)),
        DataCell(Text(qty.toString())),
        DataCell(Text(wkg.toString())),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _rows.length;

  @override
  int get selectedRowCount => 0;
}