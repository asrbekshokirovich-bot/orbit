import 'package:flutter/material.dart';
import 'theme.dart';
import 'app_state.dart';
import 'gate.dart';
import 'home.dart';
import 'tasks.dart';
import 'finance.dart';
import 'ai.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.init();
  runApp(const OrbitApp());
}

class OrbitApp extends StatelessWidget {
  const OrbitApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      theme: orbitTheme(),
      home: ValueListenableBuilder<String?>(
        valueListenable: AppState.key,
        builder: (_, key, __) =>
            key == null ? const GateScreen() : const RootNav(),
      ),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});
  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _i = 0;
  final _pages = const [HomeScreen(), TasksScreen(), FinanceScreen(), AiScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Asosiy'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Vazifalar'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Moliya'),
          NavigationDestination(
              icon: Icon(Icons.graphic_eq),
              selectedIcon: Icon(Icons.graphic_eq),
              label: 'AI'),
        ],
      ),
    );
  }
}
