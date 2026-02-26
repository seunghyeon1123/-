import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const String WEBAPP_URL = AppConfig.webAppUrl;

  bool loading = false;
  String? error;

  List<Map<String, dynamic>> items = [];
  String q = '';

  // ✅ 정렬 상태
  int? sortColumnIndex;
  bool sortAscending = true;

  // ✅ 페이지 크기
  int rowsPerPage = 20;

  // ✅ 마지막 갱신 시간(“업데이트 안됨” 체감 확인용)
  DateTime? lastFetchedAt;

  late final _InventoryDataSource dataSource;

  @override
  void initState() {
    super.initState();
    dataSource = _InventoryDataSource([]);
    load();
  }

  // ---------- Helpers (State용) ----------
  String s(Map<String, dynamic> it, String key, [String fallback = '-']) {
    final v = it[key];
    if (v == null) return fallback;
    final str = v.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  num? _tryNum(Map<String, dynamic> it, String key) {
    final v = it[key];
    if (v == null) return null;
    if (v is num) return v;

    final str = v.toString().replaceAll(',', '').trim(); // ✅ "1,200" 방어
    if (str.isEmpty) return null;
    return num.tryParse(str);
  }

  num pickNum(Map<String, dynamic> it, List<String> keys) {
    for (final k in keys) {
      final parsed = _tryNum(it, k);
      if (parsed != null) return parsed;
    }
    return 0;
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
        case 4: // 수량 (qty / qtyTotal 자동 대응)
          view.sort((a, b) {
            final av = pickNum(a, ['qty', 'qtyTotal']);
            final bv = pickNum(b, ['qty', 'qtyTotal']);
            return sortAscending ? av.compareTo(bv) : bv.compareTo(av);
          });
          break;
        case 5: // 총 무게(kg) (weightKgTotal / weightKg 자동 대응)
          view.sort((a, b) {
            final av = pickNum(a, ['weightKgTotal', 'weightKg']);
            final bv = pickNum(b, ['weightKgTotal', 'weightKg']);
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
      // ✅ 캐시 방지: ts 파라미터만 사용(웹에서 가장 안전)
      final uri = Uri.parse(
        '$WEBAPP_URL?action=inventory&ts=${DateTime.now().millisecondsSinceEpoch}',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      debugPrint('CT=${res.headers['content-type']}');
      final previewLen = res.body.length < 80 ? res.body.length : 80;
      debugPrint(res.body.substring(0, previewLen));

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

      setState(() {
        items = parsed;
        lastFetchedAt = DateTime.now();
      });

      if (parsed.isNotEmpty) {
        debugPrint('INVENTORY keys: ${parsed.first.keys.toList()}');
        debugPrint('INVENTORY first row: ${parsed.first}');
      }

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

  String _fmtTime(DateTime? t) {
    if (t == null) return '-';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              '마지막 갱신: ${_fmtTime(lastFetchedAt)}   |   표시: ${dataSource.rowCount}건',
              style: TextStyle(color: Colors.black.withOpacity(0.65)),
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
                        final double tableWidth =
                        constraints.maxWidth < 980 ? 980 : constraints.maxWidth;

                        return SingleChildScrollView(
                            child: SingleChildScrollView(
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
                                  label: const Text('SKU',
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  label: const Text('품목명',
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  label: const Text('창고',
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  label: const Text('위치코드',
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  numeric: true,
                                  label: const Text('수량',
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                                DataColumn(
                                  numeric: true,
                                  label: const Text('총 무게(kg)',
                                      style: TextStyle(fontWeight: FontWeight.w800)),
                                  onSort: _onSort,
                                ),
                              ],
                              source: dataSource,
                            ),
                          ),
                            ),
                        );
                      },
                    ),
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
  String _fmtKg(num v) {
    return v.toDouble().toStringAsFixed(2);
  }
  String _s(Map<String, dynamic> it, String key, [String fallback = '-']) {
    final v = it[key];
    if (v == null) return fallback;
    final str = v.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  num? _tryNum(Map<String, dynamic> it, String key) {
    final v = it[key];
    if (v == null) return null;
    if (v is num) return v;

    final str = v.toString().replaceAll(',', '').trim();
    if (str.isEmpty) return null;
    return num.tryParse(str);
  }

  num _pickNum(Map<String, dynamic> it, List<String> keys) {
    for (final k in keys) {
      final parsed = _tryNum(it, k);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= _rows.length) return null;
    final it = _rows[index];

    final sku = _s(it, 'sku', '-');
    final name = _s(it, 'name', '-');
    final wh = _s(it, 'warehouse', '-');
    final loc = _s(it, 'locationCode', '-');

    // ✅ 서버 키가 뭐든 자동으로 잡음
    final qty = _pickNum(it, ['qty', 'qtyTotal']);
    final wkg = _pickNum(it, ['weightKgTotal', 'weightKg']);

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(SelectableText(sku)),
        DataCell(SelectableText(name)),
        DataCell(Text(wh)),
        DataCell(SelectableText(loc)),
        DataCell(Text(qty.toString())),
        DataCell(Text(_fmtKg(wkg))),
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