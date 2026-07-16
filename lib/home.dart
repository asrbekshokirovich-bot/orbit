import 'package:flutter/material.dart';
import 'theme.dart';
import 'api.dart';
import 'app_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_Overview> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<_Overview> _load() async {
    final biz = await AppState.loadBusinesses(force: true);
    final t = await Api.instance.call('tasks', {});
    final x = await Api.instance.call('trx', {});
    final tasks = ((t['tasks'] as List?) ?? const []).whereType<Map>().toList();
    final trx = ((x['trx'] as List?) ?? const []).whereType<Map>().toList();
    return _Overview(biz, tasks, trx);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _f = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orbit',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        actions: [
          IconButton(
            tooltip: 'Chiqish',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => AppState.expire(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_Overview>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorView(err: snap.error, onRetry: _refresh);
            }
            final o = snap.data!;
            final open =
                o.tasks.where((t) => t['status'] == 'open').length;
            final inprog =
                o.tasks.where((t) => t['status'] == 'in_progress').length;
            final today = o.tasks.where((t) {
              final d = t['due_at'];
              if (d == null) return false;
              final due = DateTime.tryParse(d.toString());
              if (due == null) return false;
              final n = DateTime.now();
              return due.year == n.year &&
                  due.month == n.month &&
                  due.day == n.day;
            }).length;
            final byCur = <String, double>{};
            for (final x in o.trx) {
              final cur = (x['currency'] ?? 'UZS').toString();
              final amt = (x['amount'] as num?)?.toDouble() ?? 0;
              final sign = x['direction'] == 'expense' ? -1 : 1;
              byCur[cur] = (byCur[cur] ?? 0) + sign * amt;
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                const Text('Assalomu alaykum, Asrbek',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_dateLine(),
                    style: const TextStyle(color: OrbitColors.textDim)),
                const SizedBox(height: 18),
                Row(children: [
                  _stat('Ochiq', '$open', OrbitColors.cyan, Icons.circle_outlined),
                  const SizedBox(width: 12),
                  _stat('Jarayonda', '$inprog', OrbitColors.violet,
                      Icons.autorenew),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _stat('Bugun', '$today', OrbitColors.coral, Icons.today),
                  const SizedBox(width: 12),
                  _stat('Bizneslar', '${o.biz.length}', OrbitColors.green,
                      Icons.apartment),
                ]),
                const SizedBox(height: 22),
                const Text('Balans',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 10),
                if (byCur.isEmpty)
                  const Text('Maʼlumot yoq',
                      style: TextStyle(color: OrbitColors.textDim))
                else
                  ...byCur.entries.map((e) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.savings_outlined,
                              color: OrbitColors.green),
                          title: Text(e.key),
                          trailing: Text(fmtAmount(e.value),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: e.value < 0
                                      ? OrbitColors.coral
                                      : OrbitColors.green)),
                        ),
                      )),
                const SizedBox(height: 22),
                const Text('Bizneslar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 10),
                ...o.biz.map((b) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.workspaces_outline,
                            color: OrbitColors.cyan),
                        title: Text((b['name'] ?? '').toString()),
                        subtitle: Text((b['slug'] ?? '').toString(),
                            style: const TextStyle(color: OrbitColors.textDim)),
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stat(String label, String val, Color c, IconData ic) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ic, color: c, size: 22),
              const SizedBox(height: 10),
              Text(val,
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: c)),
              Text(label,
                  style: const TextStyle(
                      color: OrbitColors.textDim, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLine() {
    const months = [
      'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
      'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'
    ];
    final n = DateTime.now();
    return '${n.day}-${months[n.month - 1]}, ${n.year}';
  }
}

class _Overview {
  final List<Map<String, dynamic>> biz;
  final List<Map> tasks;
  final List<Map> trx;
  _Overview(this.biz, this.tasks, this.trx);
}

class _ErrorView extends StatelessWidget {
  final Object? err;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.err, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final isKey = err is ApiException && (err as ApiException).code == 'key';
    if (isKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) => AppState.expire());
    }
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off, size: 48, color: OrbitColors.textDim),
        const SizedBox(height: 12),
        Center(
          child: Text(isKey ? 'Kalit notogri' : 'Ulanishda xatolik',
              style: const TextStyle(color: OrbitColors.textDim)),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
              onPressed: onRetry, child: const Text('Qayta urinish')),
        ),
      ],
    );
  }
}
