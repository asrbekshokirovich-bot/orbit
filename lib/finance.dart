import 'package:flutter/material.dart';
import 'theme.dart';
import 'api.dart';
import 'app_state.dart';

const _currencies = ['UZS', 'USD', 'KRW'];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String? _slug;
  List<Map<String, dynamic>> _biz = [];
  late Future<List<Map>> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<List<Map>> _load() async {
    _biz = await AppState.loadBusinesses();
    final r =
        await Api.instance.call('trx', _slug != null ? {'slug': _slug} : {});
    return ((r['trx'] as List?) ?? const []).whereType<Map>().toList();
  }

  void _reload() => setState(() => _f = _load());

  void _fail(Object e) {
    if (e is ApiException && e.code == 'key') {
      AppState.expire();
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Xatolik')));
    }
  }

  Future<void> _addDialog() async {
    final amtC = TextEditingController();
    final descC = TextEditingController();
    String dir = 'income';
    String cur = 'UZS';
    String? slug = _slug ?? (_biz.isNotEmpty ? _biz.first['slug'] : null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: OrbitColors.surface,
          title: const Text('Yangi tranzaksiya'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'income', label: Text('Kirim')),
                    ButtonSegment(value: 'expense', label: Text('Chiqim')),
                  ],
                  selected: {dir},
                  onSelectionChanged: (s) => setD(() => dir = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amtC,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Summa'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: cur,
                      items: _currencies
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => cur = v ?? 'UZS',
                      decoration: const InputDecoration(labelText: 'Valyuta'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: slug,
                  isExpanded: true,
                  items: _biz
                      .map((b) => DropdownMenuItem(
                          value: b['slug'] as String?,
                          child: Text((b['name'] ?? '').toString())))
                      .toList(),
                  onChanged: (v) => slug = v,
                  decoration: const InputDecoration(labelText: 'Biznes'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descC,
                  decoration: const InputDecoration(hintText: 'Izoh'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Bekor')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Qoshish')),
          ],
        ),
      ),
    );
    final amt = double.tryParse(amtC.text.trim().replaceAll(' ', ''));
    if (ok == true && amt != null && amt > 0 && slug != null) {
      try {
        await Api.instance.call('trx_add', {
          'slug': slug,
          'direction': dir,
          'amount': amt,
          'currency': cur,
          'description': descC.text.trim(),
        });
        _reload();
      } catch (e) {
        _fail(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moliya',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDialog,
        backgroundColor: OrbitColors.green,
        foregroundColor: OrbitColors.bg,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _bizFilter(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<Map>>(
                future: _f,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _fail(snap.error!));
                    return _retry();
                  }
                  final trx = snap.data!;
                  final byCur = <String, double>{};
                  for (final x in trx) {
                    final cur = (x['currency'] ?? 'UZS').toString();
                    final amt = (x['amount'] as num?)?.toDouble() ?? 0;
                    final sign = x['direction'] == 'expense' ? -1 : 1;
                    byCur[cur] = (byCur[cur] ?? 0) + sign * amt;
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      if (byCur.isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Wrap(
                              spacing: 18,
                              runSpacing: 8,
                              children: byCur.entries
                                  .map((e) => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(e.key,
                                              style: const TextStyle(
                                                  color: OrbitColors.textDim,
                                                  fontSize: 12)),
                                          Text(fmtAmount(e.value),
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: e.value < 0
                                                      ? OrbitColors.coral
                                                      : OrbitColors.green)),
                                        ],
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (trx.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 120),
                          child: Center(
                              child: Text('Tranzaksiya yoq',
                                  style:
                                      TextStyle(color: OrbitColors.textDim))),
                        )
                      else
                        ...trx.map(_tile),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bizFilter() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip('Hammasi', _slug == null, () {
            _slug = null;
            _reload();
          }),
          ..._biz.map((b) => _chip((b['name'] ?? '').toString(),
              _slug == b['slug'], () {
            _slug = b['slug'] as String?;
            _reload();
          })),
        ],
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => onTap(),
        selectedColor: OrbitColors.green.withValues(alpha: 0.22),
        backgroundColor: OrbitColors.surface,
      ),
    );
  }

  Widget _tile(Map x) {
    final inc = x['direction'] != 'expense';
    final c = inc ? OrbitColors.green : OrbitColors.coral;
    final biz = (x['businesses'] is Map) ? x['businesses']['name'] : null;
    final date = x['occurred_at'];
    final amt = (x['amount'] as num?)?.toDouble() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c.withValues(alpha: 0.16),
          child: Icon(inc ? Icons.south_west : Icons.north_east,
              color: c, size: 20),
        ),
        title: Text(
            (x['description'] ?? (inc ? 'Kirim' : 'Chiqim')).toString()),
        subtitle: Text([
          if (biz != null) biz.toString(),
          if (date != null) date.toString().substring(0, 10),
        ].join('  •  '),
            style: const TextStyle(color: OrbitColors.textDim, fontSize: 12)),
        trailing: Text('${inc ? '+' : '-'}${fmtAmount(amt)} ${x['currency'] ?? ''}',
            style: TextStyle(
                color: c, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  Widget _retry() => ListView(children: [
        const SizedBox(height: 140),
        Center(
            child: OutlinedButton(
                onPressed: _reload, child: const Text('Qayta urinish'))),
      ]);
}
