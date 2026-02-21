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
      'https://script.google.com/macros/s/AKfycby2lGiA3IJegDC3FF5o7I-0udeTqTAikfgUDZBOPjl6mXKE48Ot3Jh1h6YO3fP0nhQ/exec';

  bool loading = false;
  String? error;
  List<Map<String, dynamic>> items = [];
  String q = '';

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

      setState(() {
        items = parsed;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = items.where((it) {
      if (q.trim().isEmpty) return true;
      final s = q.trim().toLowerCase();
      return (it['sku'] ?? '').toString().toLowerCase().contains(s) ||
          (it['name'] ?? '').toString().toLowerCase().contains(s) ||
          (it['locationCode'] ?? '').toString().toLowerCase().contains(s) ||
          (it['warehouse'] ?? '').toString().toLowerCase().contains(s);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('재고현황'),
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
              onChanged: (v) => setState(() => q = v),
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
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final it = filtered[i];
                  final sku = (it['sku'] ?? '-').toString();
                  final name = (it['name'] ?? '-').toString();
                  final wh = (it['warehouse'] ?? '').toString();
                  final loc = (it['locationCode'] ?? '').toString();
                  final qty = (it['qty'] ?? 0).toString();
                  final wkg = (it['weightKgTotal'] ?? 0).toString();

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$sku  •  $name', style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('위치: ${wh.isEmpty ? '-' : wh} ${loc.isEmpty ? '' : '/ $loc'}'),
                          const SizedBox(height: 4),
                          Text('수량: $qty'),
                          const SizedBox(height: 4),
                          Text('총 무게(kg): $wkg'),
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
}