import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'extras.dart';
import 'evolucao.dart';
import 'state.dart';
import 'telas.dart';
import 'transicao.dart';
import 'nutricao.dart';
import 'passos.dart';
import 'sono_calendario.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  await app.aplicarManterTela();
  runApp(const TreinoApp());
}

class TreinoApp extends StatelessWidget {
  const TreinoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meu treino',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        pageTransitionsTheme: kTransicoes,
        chipTheme: ChipThemeData(
          side: BorderSide(color: branco(.14)),
          backgroundColor: branco(.07),
          selectedColor: kAzul.withOpacity(0.30),
          checkmarkColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(primary: kAzul, surface: kSuperf),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF171D29),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: branco(.16)),
          ),
          insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      builder: (context, child) => Fundo(child: child ?? const SizedBox()),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) => (app.logado || app.pulouLogin)
            ? const Shell()
            : const LoginTela(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellEstado();
}

class _ShellEstado extends State<Shell> with SingleTickerProviderStateMixin {
  int i = 0;
  bool _compacto = false;
  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();
    _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    app.xpAviso.addListener(_aoXp);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Treino em andamento? Volta direto para ele.
      if (await retomarTreinoSalvo(context)) return;
      if (!mounted) return;
      await pedirPermissoesInicial(context);
      if (!mounted) return;
      await pedirBateriaUmaVez(context);
    });
  }

  @override
  void dispose() {
    app.xpAviso.removeListener(_aoXp);
    _pulso.dispose();
    super.dispose();
  }

  /// Aviso rápido quando o app dá XP (e quando sobe de nível).
  void _aoXp() {
    final a = app.xpAviso.value;
    if (a == null || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      backgroundColor: kSuperf,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: branco(.14)),
      ),
      content: Row(
        children: [
          const Icon(Icons.bolt, color: kAzul),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.texto,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                if (a.extra != null)
                  Text(a.extra!,
                      style: const TextStyle(color: kMudo, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  void _ir(int n) => setState(() => i = n);

  bool _aoRolar(ScrollNotification n) {
    if (n is UserScrollNotification) {
      final reduzir = n.direction == ScrollDirection.reverse;
      if (reduzir != _compacto) setState(() => _compacto = reduzir);
    }
    return false;
  }

  Widget _btn(int n, IconData icone, String rotulo) {
    final sel = i == n;
    return Semantics(
      label: rotulo,
      button: true,
      child: GestureDetector(
        onTap: () => _ir(n),
        child: AnimatedBuilder(
          animation: _pulso,
          builder: (context, child) {
            final t = sel ? _pulso.value : 0.0;
            final escala = sel ? 1.0 + (0.055 * t) : 1.0;
            return Transform.scale(
              scale: escala,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: _compacto ? 40 : 48,
                height: _compacto ? 36 : 42,
                decoration: BoxDecoration(
                  color: sel ? branco(.18 + (.05 * t)) : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: sel
                      ? [BoxShadow(color: kAzul.withOpacity(.20 + (.25 * t)), blurRadius: 12 + (8 * t), spreadRadius: .5 + t)]
                      : const [],
                ),
                child: child,
              ),
            );
          },
          child: Icon(icone, size: _compacto ? 17 : 18, color: sel ? Colors.white : kMudo),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _aoRolar,
            child: IndexedStack(
              index: i,
              children: [
                InicioTela(irPara: _ir),
                const EvolucaoTela(),
                const BibliotecaTela(),
                const NutricaoTela(),
                const SonoCalendarioTela(),
                MaisTela(irPara: _ir),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: SafeArea(
              child: Center(
                child: Vidro(
                  padding: EdgeInsets.all(_compacto ? 5 : 8),
                  raio: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _btn(0, Icons.home_rounded, 'Início'),
                      _btn(1, Icons.show_chart, 'Evolução'),
                      _btn(2, Icons.fitness_center, 'Biblioteca'),
                      _btn(3, Icons.restaurant_menu, 'Nutrição'),
                      _btn(4, Icons.bedtime_rounded, 'Sono'),
                      _btn(5, Icons.more_horiz, 'Mais'),
                    ],
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
