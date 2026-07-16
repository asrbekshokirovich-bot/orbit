import 'package:flutter/material.dart';
import 'theme.dart';
import 'app_state.dart';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});
  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  final _c = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    setState(() => _busy = true);
    await AppState.setKey(v);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.blur_circular,
                  size: 72, color: OrbitColors.cyan),
              const SizedBox(height: 16),
              const Text('Orbit',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Kirish uchun maxsus kalitni kiriting',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: OrbitColors.textDim)),
              const SizedBox(height: 28),
              TextField(
                controller: _c,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: 'Orbit kaliti',
                  prefixIcon: Icon(Icons.key),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: OrbitColors.cyan,
                  foregroundColor: OrbitColors.bg,
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Kirish',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
