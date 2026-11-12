import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'extras.dart';
import 'state.dart';
import 'telas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
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
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(primary: kAzul, surface: kSuperf),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
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

class _ShellEstado extends State<Shell> {
  int i = 0;
  void _ir(int n) => setState(() => i = n);

  Widget _btn(int n, IconData icone, String rotulo) {
    final sel = i == n;
    return Semantics(
      label: rotulo,
      button: true,
      child: GestureDetector(
        onTap: () => _ir(n),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 54,
          height: 48,
          decoration: BoxDecoration(
            color: sel ? branco(.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(icone, color: sel ? Colors.white : kMudo),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: i,
            children: [
              InicioTela(irPara: _ir),
              const EvolucaoTela(),
              const BibliotecaTela(),
              MaisTela(irPara: _ir),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: SafeArea(
              child: Center(
                child: Vidro(
                  padding: const EdgeInsets.all(8),
                  raio: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _btn(0, Icons.home_rounded, 'Início'),
                      _btn(1, Icons.show_chart, 'Evolução'),
                      _btn(2, Icons.fitness_center, 'Biblioteca'),
                      _btn(3, Icons.more_horiz, 'Mais'),
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
