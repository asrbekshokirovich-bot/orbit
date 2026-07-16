import 'package:flutter/material.dart';
import 'theme.dart';
import 'app_state.dart';
import 'voice.dart';
import 'orb.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final VoiceEngine _engine = VoiceEngine();

  @override
  void initState() {
    super.initState();
    _engine.onError = (code) {
      if (code == 'key') {
        AppState.expire();
      }
    };
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_engine.running) {
      await _engine.stop();
    } else {
      await _engine.start();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orbit AI',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
      ),
      body: AnimatedBuilder(
        animation: _engine,
        builder: (context, _) {
          final running = _engine.running;
          return Column(
            children: [
              const Spacer(),
              VoiceOrb(state: _engine.state, level: _engine.level),
              const SizedBox(height: 28),
              Text(_engine.status,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  running
                      ? 'Gapiring — men tinglayapman. Toxtatish uchun tugmani bosing.'
                      : 'Suhbatni boshlash uchun tugmani bosing. Ovozli, qol tegmasdan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: OrbitColors.textDim),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: running ? OrbitColors.coral : OrbitColors.cyan,
                      boxShadow: [
                        BoxShadow(
                          color: (running
                                  ? OrbitColors.coral
                                  : OrbitColors.cyan)
                              .withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(running ? Icons.stop : Icons.mic,
                        color: OrbitColors.bg, size: 38),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
