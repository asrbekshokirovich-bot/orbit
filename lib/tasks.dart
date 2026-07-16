import 'package:flutter/material.dart';
import 'theme.dart';
import 'api.dart';
import 'app_state.dart';

const _statuses = ['open', 'in_progress', 'done'];
const _statusUz = {
  'open': 'Ochiq',
  'in_progress': 'Jarayonda',
  'done': 'Bajarildi',
};
const _statusColor = {
  'open': OrbitColors.cyan,
  'in_progress': OrbitColors.violet,
  'done': OrbitColors.green,
};

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String? _slug; // null = all
  List<Map<String, dynamic>> _biz = [];
  late Future<List<Map>> _f;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<List<Map>> _load() async {
    _biz = await AppState.loadBusinesses();
    final r = await Api.instance
        .call('tasks', _slug != null ? {'slug': _slug} : {});
    return ((r['tasks'] as List?) ?? const []).whereType<Map>().toList();
  }

  void _reload() => setState(() => _f = _load());

  Future<void> _cycle(Map t) async {
    final cur = (t['status'] ?? 'open').toString();
    final next = _statuses[(_statuses.indexOf(cur) + 1) % _statuses.length];
    try {
      await Api.instance.call('task_set_status', {'id': t['id'], 'status': next});
      _reload();
    } catch (e) {
      _fail(e);
    }
  }

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
    final titleC = TextEditingController();
    DateTime? due;
    String? slug = _slug ?? (_biz.isNotEmpty ? _biz.first['slug'] : null);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: OrbitColors.surface,
          title: const Text('Yangi vazifa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleC,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Vazifa nomi'),
              ),
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
              Row(children: [
                Expanded(
                  child: Text(
                      due == null
                          ? 'Muddat: yoq'
                          : 'Muddat: ${due!.toString().substring(0, 10)}',
                      style: const TextStyle(color: OrbitColors.textDim)),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final p = await showDatePicker(
                      context: ctx,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365 * 2)),
                      initialDate: now,
                    );
                    if (p != null) setD(() => due = p);
                  },
                  child: const Text('Sana'),
                ),
              ]),
            ],
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
    if (ok == true && titleC.text.trim().isNotEmpty && slug != null) {
      try {
        await Api.instance.call('task_add', {
          'slug': slug,
          'title': titleC.text.trim(),
          if (due != null) 'due': due!.toIso8601String().substring(0, 10),
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
        title: const Text('Vazifalar',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDialog,
        backgroundColor: OrbitColors.cyan,
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
                  final tasks = snap.data!;
                  if (tasks.isEmpty) {
                    return _empty('Vazifa yoq');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _tile(tasks[i]),
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
        selectedColor: OrbitColors.cyan.withValues(alpha: 0.22),
        backgroundColor: OrbitColors.surface,
      ),
    );
  }

  Widget _tile(Map t) {
    final st = (t['status'] ?? 'open').toString();
    final c = _statusColor[st] ?? OrbitColors.textDim;
    final biz = (t['businesses'] is Map) ? t['businesses']['name'] : null;
    final due = t['due_at'];
    return Card(
      child: ListTile(
        onTap: () => _cycle(t),
        leading: GestureDetector(
          onTap: () => _cycle(t),
          child: Icon(
              st == 'done'
                  ? Icons.check_circle
                  : st == 'in_progress'
                      ? Icons.autorenew
                      : Icons.circle_outlined,
              color: c),
        ),
        title: Text((t['title'] ?? '').toString(),
            style: TextStyle(
                decoration: st == 'done' ? TextDecoration.lineThrough : null)),
        subtitle: Row(children: [
          if (biz != null)
            Text(biz.toString(),
                style: const TextStyle(color: OrbitColors.textDim, fontSize: 12)),
          if (due != null) ...[
            const Text('  •  ',
                style: TextStyle(color: OrbitColors.textDim, fontSize: 12)),
            Text(due.toString().substring(0, 10),
                style: const TextStyle(color: OrbitColors.coral, fontSize: 12)),
          ],
        ]),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: c.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20)),
          child: Text(_statusUz[st] ?? st,
              style: TextStyle(
                  color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _empty(String msg) => ListView(children: [
        const SizedBox(height: 140),
        Center(
            child: Text(msg,
                style: const TextStyle(color: OrbitColors.textDim))),
      ]);

  Widget _retry() => ListView(children: [
        const SizedBox(height: 140),
        Center(
            child: OutlinedButton(
                onPressed: _reload, child: const Text('Qayta urinish'))),
      ]);
}
