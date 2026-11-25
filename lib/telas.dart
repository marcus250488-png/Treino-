import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'state.dart';
import 'extras.dart' show MeuPlanoTela, fmtNum, fmtTempo;
import 'edicao.dart';
import 'fotos.dart';
import 'cardio.dart';
import 'ex_edit.dart';
import 'passos.dart';
import 'xp.dart';
import 'video_ex.dart';
import 'desempenho.dart' show DesempenhoTela;
import 'sessao_detalhe.dart';
import 'compartilhar.dart';
import 'anatomia.dart';

const kAzul = Color(0xFF0050E6);
const kSuperf = Color(0xFF1C1C1E);
const kMudo = Color(0xFFA1A1A6);
Color branco(double o) => Color.fromRGBO(255, 255, 255, o);

TextStyle titulo(double s) => GoogleFonts.barlowCondensed(
    fontSize: s, fontWeight: FontWeight.w700, color: Colors.white);

final estiloPrimario = FilledButton.styleFrom(
  backgroundColor: kAzul,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(56),
  shape: const StadiumBorder(),
  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
);
/// Contorno bem fino e branco, igual à borda dos cartões.
final estiloContornoFino = OutlinedButton.styleFrom(
  foregroundColor: Colors.white,
  side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1),
  shape: const StadiumBorder(),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
);

/// Contorno leve, menor e com fonte pequena (botões secundários discretos).
final estiloContornoMini = OutlinedButton.styleFrom(
  foregroundColor: Colors.white.withOpacity(0.9),
  side: BorderSide(color: Colors.white.withOpacity(0.28), width: 1),
  shape: const StadiumBorder(),
  minimumSize: const Size(0, 34),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
);

final estiloContorno = OutlinedButton.styleFrom(
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(56),
  shape: const StadiumBorder(),
  side: const BorderSide(color: kAzul, width: 0.9),
  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
);

const _sem = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

/// Anel fino com um brilho que gira em volta do dia selecionado.
class AnelBrilho extends StatefulWidget {
  final Widget child;
  const AnelBrilho({required this.child});
  @override
  State<AnelBrilho> createState() => AnelBrilhoEstado();
}

class AnelBrilhoEstado extends State<AnelBrilho>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => CustomPaint(
        foregroundPainter: AnelBrilhoPainter(_c.value),
        child: child,
      ),
    );
  }
}

class AnelBrilhoPainter extends CustomPainter {
  final double t;
  AnelBrilhoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr =
        RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(16));
    final shader = SweepGradient(
      colors: [
        kAzul.withOpacity(0),
        kAzul,
        Colors.white,
        kAzul,
        kAzul.withOpacity(0),
      ],
      stops: const [0.0, 0.3, 0.42, 0.54, 1.0],
      transform: GradientRotation(t * 6.283185307),
    ).createShader(rect);
    // brilho suave por baixo
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // linha fina e nítida
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
  }

  @override
  bool shouldRepaint(covariant AnelBrilhoPainter old) => old.t != t;
}

Widget _envolveSel(bool sel, Widget child) =>
    sel ? AnelBrilho(child: child) : child;
String _dois(int n) => n.toString().padLeft(2, '0');
String _fmt(int s) => '${_dois(s ~/ 60)}:${_dois(s % 60)}';

/// Cor e ícone de cada grupo muscular (usados no lugar do número azul).
class EstiloGrupo {
  final Color cor;
  final IconData icone;
  const EstiloGrupo(this.cor, this.icone);
}

EstiloGrupo estiloGrupo(String grupo) {
  final g = norm(grupo);
  if (g.contains('peit')) {
    return const EstiloGrupo(Color(0xFFE53935), Icons.fitness_center);
  }
  if (g.contains('costa') || g.contains('dorsal') || g.contains('lombar')) {
    return const EstiloGrupo(Color(0xFF1E88E5), Icons.accessibility_new);
  }
  if (g.contains('perna') ||
      g.contains('quadr') ||
      g.contains('posterior') ||
      g.contains('gluteo') ||
      g.contains('panturr')) {
    return const EstiloGrupo(Color(0xFF43A047), Icons.directions_walk);
  }
  if (g.contains('ombro')) {
    return const EstiloGrupo(Color(0xFFFB8C00), Icons.pan_tool);
  }
  if (g.contains('triceps')) {
    return const EstiloGrupo(Color(0xFFD81B60), Icons.bolt);
  }
  if (g.contains('biceps') || g.contains('bicep')) {
    return const EstiloGrupo(Color(0xFF8E24AA), Icons.whatshot);
  }
  if (g.contains('antebraco')) {
    return const EstiloGrupo(Color(0xFF6D4C41), Icons.back_hand);
  }
  if (g.contains('abdom') || g.contains('core')) {
    return const EstiloGrupo(Color(0xFFFDD835), Icons.self_improvement);
  }
  if (g.contains('cardio')) {
    return const EstiloGrupo(Color(0xFF00ACC1), Icons.directions_run);
  }
  return const EstiloGrupo(kAzul, Icons.fitness_center);
}

// ---------- Componentes visuais ----------
class Fundo extends StatelessWidget {
  final Widget child;
  const Fundo({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.9, -0.9),
              radius: 1.1,
              colors: [Color.fromRGBO(0, 80, 230, .5), Colors.transparent],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(1, 0.3),
              radius: 0.9,
              colors: [Color.fromRGBO(214, 51, 108, .28), Colors.transparent],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class Vidro extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double raio;
  final VoidCallback? onTap;
  const Vidro({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.raio = 28,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final w = ClipRRect(
      borderRadius: BorderRadius.circular(raio),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: branco(.07),
            borderRadius: BorderRadius.circular(raio),
            border: Border.all(color: branco(.14)),
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return w;
    return GestureDetector(
        behavior: HitTestBehavior.opaque, onTap: onTap, child: w);
  }
}

// ---------- Login ----------
class LoginTela extends StatefulWidget {
  const LoginTela({super.key});
  @override
  State<LoginTela> createState() => _LoginEstado();
}

class _LoginEstado extends State<LoginTela> {
  bool carregando = false;
  String? erro;

  Future<void> _entrar() async {
    setState(() {
      carregando = true;
      erro = null;
    });
    final e = await app.entrar();
    if (!mounted) return;
    setState(() {
      carregando = false;
      erro = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kAzul, width: 4),
                ),
                child: const Icon(Icons.fitness_center, size: 52),
              ),
              const SizedBox(height: 24),
              Text('Meu treino', style: titulo(46)),
              const SizedBox(height: 8),
              const Text(
                'Entre com sua conta Google. Seus treinos e registros ficam salvos na nuvem, separados por conta.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kMudo),
              ),
              const Spacer(),
              if (erro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(erro!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              FilledButton.icon(
                style: estiloPrimario,
                onPressed: carregando ? null : _entrar,
                icon: carregando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: const Text('Entrar com Google'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: carregando ? null : app.pularLogin,
                child: const Text('Agora não',
                    style: TextStyle(color: kMudo, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Início ----------
class InicioTela extends StatefulWidget {
  final void Function(int) irPara;
  const InicioTela({super.key, required this.irPara});
  @override
  State<InicioTela> createState() => _InicioEstado();
}

class _InicioEstado extends State<InicioTela> {
  late final PageController _pc;
  late int _sel; // 0 = Dom ... 6 = Sáb
  int _semOff = 0; // semanas à frente (+) ou atrás (-)

  @override
  void initState() {
    super.initState();
    _sel = 3; // hoje fica no meio da barra (índice 3 de 0..6)
    _pc = PageController(initialPage: _sel, viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _escolherDia(int i) {
    setState(() => _sel = i);
    _pc.animateToPage(i,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Widget _avatar() {
    final f = app.foto;
    return GestureDetector(
      onTap: _conta,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: kAzul, width: 3),
        ),
        child: ClipOval(
          child: f == null
              ? const Icon(Icons.person)
              : Image.network(
                  f,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person),
                ),
        ),
      ),
    );
  }

  void _conta() {
    final msg = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: kSuperf,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (app.logado) ...[
                Text(app.nome ?? 'Conta Google', style: titulo(30)),
                const SizedBox(height: 4),
                Text(app.email ?? '', style: const TextStyle(color: kMudo)),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: estiloContorno,
                  onPressed: () async {
                    Navigator.pop(c);
                    await app.sair();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair da conta'),
                ),
              ] else ...[
                Text('Conta Google', style: titulo(30)),
                const SizedBox(height: 4),
                const Text('Entre para mostrar sua foto e seu nome.',
                    style: TextStyle(color: kMudo)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: estiloPrimario,
                  onPressed: () async {
                    Navigator.pop(c);
                    final e = await app.entrar();
                    if (e != null) {
                      msg.showSnackBar(SnackBar(content: Text(e)));
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar com Google'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final hoje = DateTime.now();
        final hojeZero = DateTime(hoje.year, hoje.month, hoje.day);
        // Barra centrada em hoje: 3 dias antes, hoje, 3 dias depois.
        final semana = List.generate(
            7, (i) => hojeZero.add(Duration(days: i - 3 + 7 * _semOff)));
        // Progresso continua sendo da semana do calendário (domingo a sábado).
        final domingo = hojeZero
            .subtract(Duration(days: hoje.weekday % 7))
            .add(Duration(days: 7 * _semOff));
        final semanaCal =
            List.generate(7, (i) => domingo.add(Duration(days: i)));
        final nFeitos =
            semanaCal.where((d) => app.feitos.contains(chaveData(d))).length;
        final total = app.plano.length;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Row(
                children: [
                  _avatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            app.primeiroNome.isEmpty
                                ? 'Olá!'
                                : 'Olá, ${app.primeiroNome}!',
                            style: titulo(30)),
                        const Text('Seu progresso na semana',
                            style: TextStyle(color: kMudo)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _semOff--),
                    icon: const Icon(Icons.chevron_left, color: kMudo),
                  ),
                  GestureDetector(
                    onTap: _semOff == 0 ? null : () => setState(() => _semOff = 0),
                    child: Text(
                      _semOff == 0
                          ? 'Hoje'
                          : '${semana.first.day}/${semana.first.month} a ${semana.last.day}/${semana.last.month}  •  voltar para hoje',
                      style: const TextStyle(color: kMudo, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _semOff++),
                    icon: const Icon(Icons.chevron_right, color: kMudo),
                  ),
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -200) {
                    setState(() => _semOff++);
                  } else if (v > 200) {
                    setState(() => _semOff--);
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) =>
                      FadeTransition(opacity: a, child: c),
                  child: Row(
                    key: ValueKey(_semOff),
                    children: [
                      for (var i = 0; i < 7; i++) _diaBtn(i, semana[i], hoje),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (app.plano.isEmpty)
                _vazio()
              else ...[
                SizedBox(
                  height: 420,
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: 7,
                    onPageChanged: (i) => setState(() => _sel = i),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _hero(context, semana[i], hoje),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _sel ? kAzul : branco(.25),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Vidro(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progresso da semana', style: titulo(26)),
                    const SizedBox(height: 10),
                    Text('$nFeitos de $total treinos',
                        style: const TextStyle(color: kMudo)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: total == 0
                            ? 0.0
                            : (nFeitos / total).clamp(0.0, 1.0).toDouble(),
                        minHeight: 10,
                        color: kAzul,
                        backgroundColor: branco(.1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const PassosCard(),
              const SizedBox(height: 14),
              const XpCard(),
              const SizedBox(height: 14),
              Material(
                color: branco(.07),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TreinoLivreTela()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: branco(.14)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: kAzul.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.add_circle_outline,
                              color: kAzul),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Treino livre',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              SizedBox(height: 3),
                              Text(
                                'Musculação ou cardio, fora do plano',
                                style: TextStyle(color: kMudo, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: kMudo),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Card Detalhes do plano de treino
              Material(
                color: branco(.07),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MeuPlanoTela()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: branco(.14)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: kAzul.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.description_outlined, color: kAzul),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Detalhes do plano de treino',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 16)),
                              SizedBox(height: 3),
                              Text(
                                'Veja seus dias treinados, objetivos e toda sua jornada de progresso',
                                style: TextStyle(color: kMudo, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: kMudo),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Card Seu desempenho
              Material(
                color: branco(.07),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DesempenhoTela()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: branco(.14)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: kAzul.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.bar_chart_rounded, color: kAzul),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Seu desempenho',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 16)),
                              SizedBox(height: 3),
                              Text(
                                'Veja quais grupos musculares você mais trabalhou',
                                style: TextStyle(color: kMudo, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: kMudo),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _diaBtn(int i, DateTime d, DateTime hoje) {
    final feito = app.feitos.contains(chaveData(d)) || app.fezAtividade(d);
    final sel = i == _sel;
    final temTreino = app.treinoNo(d) != null;
    // Quanto mais longe de hoje (posição 3), menor o retângulo.
    final dist = (i - 3).abs();
    return Expanded(
      flex: 15 - dist * 2,
      child: GestureDetector(
        onTap: () => _escolherDia(i),
        child: _envolveSel(sel, AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.symmetric(vertical: 10 - dist * 1.0),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF0A1F4D) : branco(.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: sel ? kAzul : branco(.12), width: 1),
          ),
          child: Column(
            children: [
              Text('${d.day}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16 - dist * 1.0,
                      color: chaveData(d) == chaveData(hoje)
                          ? kAzul
                          : Colors.white)),
              Text(_sem[d.weekday % 7],
                  style: TextStyle(color: kMudo, fontSize: 13 - dist * 0.5)),
              const SizedBox(height: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: feito ? kAzul : Colors.transparent,
                  border: Border.all(
                      color: feito || temTreino ? kAzul : branco(.25),
                      width: 2),
                ),
                child: feito
                    ? const Icon(Icons.check, size: 15)
                    : temTreino
                        ? Icon(Icons.check, size: 15, color: branco(.55))
                        : null,
              ),
            ],
          ),
        )),
      ),
    );
  }

  Widget _vazio() {
    return Vidro(
      child: Column(
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 48, color: kMudo),
          const SizedBox(height: 10),
          Text('Nenhum treino ainda', style: titulo(28)),
          const SizedBox(height: 6),
          const Text('Importe o PDF do seu treino para começar.',
              textAlign: TextAlign.center, style: TextStyle(color: kMudo)),
          const SizedBox(height: 16),
          FilledButton(
            style: estiloPrimario,
            onPressed: () => abrirImportar(context, widget.irPara),
            child: const Text('Importar PDF'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String g) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: branco(.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(g, style: const TextStyle(fontSize: 13)),
      );

  BoxDecoration get _decCard => BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: branco(.14)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF16233F), Color(0xFF0B0B0D), Colors.black],
        ),
      );

  Widget _linhaCardio(BuildContext context, DateTime data) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: estiloContornoFino,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CardioTela(dia: data)),
            ),
            icon: const Icon(Icons.directions_run, size: 18),
            label: const FittedBox(
                fit: BoxFit.scaleDown, child: Text('Fazer cardio')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: estiloContornoFino,
            onPressed: () => registrarCardioManual(context, data),
            icon: const Icon(Icons.add, size: 18),
            label: const FittedBox(
                fit: BoxFit.scaleDown, child: Text('Já fiz cardio')),
          ),
        ),
      ],
    );
  }

  Widget _conteudoDescanso(BuildContext context, DateTime data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Descanso', style: titulo(46)),
        const SizedBox(height: 6),
        Text('Sem treino na ${_nomeDia(data)}.',
            style: const TextStyle(color: kMudo)),
        for (final f in app.sessoesDoDia(data))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              f.cardio
                  ? '${f.rotulo} • ${f.resumoCardio}'
                  : '${f.rotulo} • ${(f.seg / 60).round()} min',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kAzul),
            ),
          ),
        if (app.ajustes[chaveData(data)] == 'R' &&
            !DateUtils.dateOnly(data).isBefore(DateUtils.dateOnly(DateTime.now())))
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: OutlinedButton.icon(
              style: estiloContornoMini,
              onPressed: () => app.desfazerAjustesDesde(data),
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Voltar o treino para este dia'),
            ),
          ),
        const SizedBox(height: 18),
        _linhaCardio(context, data),
      ],
    );
  }

  Widget _hero(BuildContext context, DateTime data, DateTime hoje) {
    final eHoje = chaveData(data) == chaveData(hoje);
    final feito = app.feitos.contains(chaveData(data));
    final dia = app.treinoNo(data);

    if (dia == null) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: _decCard,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                app.fotosFemininas
                    ? 'assets/fotos/f_descanso.jpg'
                    : 'assets/fotos/descanso.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.35),
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/fotos/descanso.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.35),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.35, 0.65, 1.0],
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                      Color(0xF5000000),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _conteudoDescanso(context, data),
              ),
            ),
          ],
        ),
      );
    }

    final grupos = dia.itens.map((e) => e.grupo).toSet().toList();
    final series = dia.itens.fold<int>(0, (s, e) => s + e.series);
    final ultima = app.ultimaSessaoDoDia(dia);
    final min = ultima != null
        ? (ultima.seg / 60).round().clamp(1, 600).toInt()
        : (series * (40 + app.descanso) / 60).round();
    final kcal = (min * 6.5).round();
    final dUlt = ultima == null ? null : DateTime.tryParse(ultima.data);
    final rotulo = feito ? 'Concluído' : (eHoje ? 'Treino do dia' : 'Programado');
    final foto = fotoDoDia(dia);
    final conteudo = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: kAzul,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(rotulo),
        ),
        const SizedBox(height: 10),
        Text(_nomeDia(data), style: titulo(46), textAlign: TextAlign.center),
        if (dia.foco.isNotEmpty)
          Text(dia.foco,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMudo)),
        const SizedBox(height: 14),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: grupos.take(4).map(_chip).toList(),
          ),
        const SizedBox(height: 14),
        Text(
            '${dia.itens.length} exercícios • $series séries • ${ultima != null ? '$min min' : '~$min min'} • ~$kcal kcal',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMudo)),
        if (ultima != null && dUlt != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Último treino: ${dUlt.day.toString().padLeft(2, '0')}/${dUlt.month.toString().padLeft(2, '0')} • ${fmtTempo(ultima.seg)} • ${ultima.volume.round()} kg',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kAzul, fontSize: 13),
            ),
          ),
        const SizedBox(height: 14),
        FilledButton(
          style: estiloPrimario,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TreinoTela(dia: dia, data: data)),
          ),
          child: Text(eHoje ? 'Iniciar treino' : 'Ver treino'),
        ),
        const SizedBox(height: 10),
        _linhaCardio(context, data),
      ],
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _decCard,
      child: Stack(
        children: [
          if (foto != null) ...[
            Positioned.fill(
              child: Image.asset(
                fotoAsset(foto),
                fit: BoxFit.cover,
                alignment: Alignment(foto.ax, foto.ay),
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.30, 0.58, 1.0],
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                      Color(0xF5000000),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            const Positioned(
              top: 30,
              left: 0,
              right: 0,
              child: Icon(Icons.fitness_center,
                  size: 150, color: Color.fromRGBO(0, 80, 230, .25)),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, cons) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(width: cons.maxWidth, child: conteudo),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _diasLongos = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado'
];
String _nomeDia(DateTime d) => _diasLongos[d.weekday % 7];

// ---------- Detalhe do treino ----------
class TreinoTela extends StatelessWidget {
  final Dia dia;
  /// Data em que este treino cai (com os ajustes de "não fui treinar").
  final DateTime? data;
  const TreinoTela({super.key, required this.dia, this.data});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => _corpo(context),
    );
  }

  /// Última sessão completa de hoje deste dia do plano (para o resumo).
  Sessao? _sessaoDeHoje() {
    Sessao? r;
    final k = chaveData(DateTime.now());
    for (final s in app.sessoes) {
      final dt = DateTime.tryParse(s.data);
      if (dt == null || s.cardio || s.dia != dia.nome || chaveData(dt) != k) {
        continue;
      }
      if (r == null || s.data.compareTo(r!.data) > 0) r = s;
    }
    return r;
  }

  Widget _corpo(BuildContext context) {
    final hoje = DateTime.now();
    final eHoje = data != null
        ? DateUtils.isSameDay(data, hoje)
        : app.eTreinoDeHoje(dia);
    final feitoHoje = app.feitos.contains(chaveData(hoje));
    final series = dia.itens.fold<int>(0, (s, e) => s + e.series);
    final ultima = app.ultimaSessaoDoDia(dia);
    final min = ultima != null
        ? (ultima.seg / 60).round().clamp(1, 600).toInt()
        : (series * (40 + app.descanso) / 60).round();
    final kcal = ultima == null
        ? (min * 6.5).round()
        : (ultima.kcal ?? (ultima.seg / 60 * 6.5).round());
    final resumo = ultima != null
        ? 'Último treino: ${fmtTempo(ultima.seg)} • ${ultima.series} séries • $kcal kcal'
        : 'Estimado: ~$min min • $series séries • ~$kcal kcal';
    final sessaoHoje = _sessaoDeHoje();
    // Quantos exercícios ainda faltam hoje (treino parcial salvo).
    final faltam = dia.itens
        .where((i) =>
            !app.resolvidoHojeEx(app.ex(i.exId)?.nome ?? i.nome, dia.nome))
        .length;
    final retomando = !feitoHoje && faltam > 0 && faltam < dia.itens.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(data != null ? _nomeDia(data!) : dia.nome, style: titulo(28)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          _cabecalho(resumo),
          const SizedBox(height: 12),
          _blocoAquecimento(),
          if (dia.itens.any((i) => !app.resolvidoHojeEx(
              app.ex(i.exId)?.nome ?? i.nome, dia.nome)))
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'Segure e arraste para reordenar. Use ⋮ para trocar ou excluir.',
                style: TextStyle(color: kMudo, fontSize: 12),
              ),
            ),
          _listaExercicios(context),
          const SizedBox(height: 2),
          OutlinedButton.icon(
            style: estiloContornoFino,
            onPressed: () => adicionarExercicioA(
                context, dia.itens, () => app.atualizarPlano()),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar exercício'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: feitoHoje
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      style: estiloPrimario,
                      onPressed: sessaoHoje == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SessaoDetalheTela(sessao: sessaoHoje),
                                ),
                              ),
                      icon: const Icon(Icons.assessment_outlined),
                      label: const Text('Ver resumo de hoje'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: estiloContornoFino,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CardioTela(dia: hoje)),
                            ),
                            icon: const Icon(Icons.directions_run, size: 18),
                            label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Fazer cardio')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: estiloContornoFino,
                            onPressed: () => registrarCardioManual(context, hoje),
                            icon: const Icon(Icons.add, size: 18),
                            label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Já fiz cardio')),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (eHoje && app.eTreinoDeHoje(dia)) ...[
                      OutlinedButton.icon(
                        style: estiloContornoMini,
                        onPressed: () => _naoFui(context),
                        icon: const Icon(Icons.bedtime_outlined, size: 16),
                        label: const Text('Não fui treinar hoje'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                  style: estiloPrimario,
                  onPressed: dia.itens.isEmpty
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => RunTela(dia: dia)),
                          ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(retomando
                      ? 'Continuar • faltam $faltam'
                      : eHoje
                          ? 'Começar'
                          : 'Começar • ~$min min'),
                ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Confirma, empurra o treino (e os próximos) um dia para frente e avisa.
  Future<void> _naoFui(BuildContext context) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hoje = DateTime.now();
    final amanha = DateTime(hoje.year, hoje.month, hoje.day + 1);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Não foi treinar hoje?'),
        content: Text(
            'Hoje vira dia de descanso e o treino de hoje vai para ${_nomeDia(amanha).toLowerCase()}. Os treinos seguintes também avançam um dia, até cair num dia livre.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    final antes = await app.naoFuiTreinar(hoje);
    nav.pop();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('Hoje é descanso. Treino movido para ${_nomeDia(amanha).toLowerCase()}.'),
      action: SnackBarAction(
        label: 'Desfazer',
        onPressed: () => app.restaurarAjustes(antes),
      ),
    ));
  }

  /// Topo com a foto do dia (mesma do card da tela inicial) e o resumo.
  Widget _cabecalho(String resumo) {
    final foto = fotoDoDia(dia);
    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0D),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: branco(.14)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (foto != null)
            Image.asset(
              fotoAsset(foto),
              fit: BoxFit.cover,
              alignment: Alignment(foto.ax, -0.7), // desce a foto: cabeça visível
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 1.0],
                colors: [
                  Color(0x33000000),
                  Color(0x99000000),
                  Color(0xF5000000),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dia.foco.isEmpty ? dia.nome : dia.foco,
                    style: titulo(30)),
                const SizedBox(height: 4),
                Text(resumo,
                    style: const TextStyle(color: kMudo, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bloco de aquecimento opcional: liga ou desliga no topo da lista.
  Widget _blocoAquecimento() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Vidro(
        raio: 22,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.whatshot, color: kAzul),
                const SizedBox(width: 10),
                Expanded(child: Text('Aquecimento', style: titulo(22))),
                Switch(
                  value: app.aquecimento,
                  onChanged: (v) => app.setAquecimento(v),
                ),
              ],
            ),
            if (app.aquecimento) ...[
              const SizedBox(height: 4),
              const Text('• 5 min de esteira ou bicicleta leve',
                  style: TextStyle(color: kMudo)),
              const Text('• Mobilidade de ombros e quadril, 1 min',
                  style: TextStyle(color: kMudo)),
              const Text('• 1 série leve do primeiro exercício, sem contar',
                  style: TextStyle(color: kMudo)),
            ],
          ],
        ),
      ),
    );
  }

  String _textoUltima(List<double> u) {
    final n = u.length;
    final s = n == 1 ? 'série' : 'séries';
    if (u.every((c) => c <= 0)) return 'Última vez: $n $s';
    if (u.every((c) => c == u.first)) {
      return 'Última vez: ${fmtNum(u.first)} kg • $n $s';
    }
    return 'Última vez: ${u.map(fmtNum).join(' / ')} kg';
  }

  /// Lista com arrastar para reordenar (segurar o cartão). Exercício já feito
  /// ou excluído hoje fica travado: não arrasta e não tem menu.
  Widget _listaExercicios(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, child: child),
      onReorder: (a, b) {
        if (b > a) b--;
        final item = dia.itens.removeAt(a);
        dia.itens.insert(b, item);
        app.atualizarPlano();
      },
      children: [
        for (var i = 0; i < dia.itens.length; i++)
          KeyedSubtree(
            key: ObjectKey(dia.itens[i]),
            child: _cartaoExercicio(context, i),
          ),
      ],
    );
  }

  Future<void> _acaoExercicio(BuildContext context, int i, String v) async {
    if (i < 0 || i >= dia.itens.length) return;
    final it = dia.itens[i];
    if (v == 'trocar') {
      if (await trocarExercicio(context, it)) app.atualizarPlano();
    } else if (v == 'series') {
      if (await editarSeriesReps(context, it)) app.atualizarPlano();
    } else if (v == 'excluir') {
      final nome = app.ex(it.exId)?.nome ?? it.nome;
      final messenger = ScaffoldMessenger.of(context);
      dia.itens.removeAt(i);
      app.atualizarPlano();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text('$nome removido do plano'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () {
            dia.itens.insert(i.clamp(0, dia.itens.length).toInt(), it);
            app.atualizarPlano();
          },
        ),
      ));
    }
  }

  Widget _cartaoExercicio(BuildContext context, int i) {
    final it = dia.itens[i];
    final ex = app.ex(it.exId);
    final nome = ex?.nome ?? it.nome;
    final equip = ex?.equip ?? '';
    final feito = app.feitoHojeEx(nome, dia.nome);
    final pulado = !feito && app.excluidoHojeEx(nome, dia.nome);
    final travado = feito || pulado;
    final estilo = estiloGrupo(it.grupo);
    final ultimas = app.ultimasCargas(nome);
    final sugerida = travado ? null : app.sugestaoCarga(nome, it.series);
    final cartao = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: travado ? .45 : 1,
        child: Vidro(
          padding: EdgeInsets.fromLTRB(14, 14, travado ? 14 : 2, 14),
          raio: 22,
          onTap: () => detalheExercicio(context, it),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: estilo.cor.withOpacity(.22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: estilo.cor, width: 1.5),
                ),
                child: Icon(
                    feito
                        ? Icons.check
                        : pulado
                            ? Icons.block
                            : estilo.icone,
                    color: travado ? Colors.white : estilo.cor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: titulo(22)),
                    Text(equip.isEmpty ? it.grupo : '${it.grupo} • $equip',
                        style: TextStyle(color: estilo.cor, fontSize: 13)),
                    if (pulado)
                      const Text('Excluído do treino de hoje',
                          style: TextStyle(color: kMudo, fontSize: 12))
                    else if (ultimas != null && ultimas.isNotEmpty)
                      Text(_textoUltima(ultimas),
                          style: const TextStyle(color: kMudo, fontSize: 12)),
                    if (sugerida != null)
                      Text(
                          sugerida.subir
                              ? 'Tente ${fmtNum(sugerida.carga)} kg hoje'
                              : 'Mantenha ${fmtNum(sugerida.carga)} kg hoje',
                          style: const TextStyle(color: kAzul, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${it.series} × ${it.reps}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (!travado)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: 'Opções',
                  icon: const Icon(Icons.more_vert, color: kMudo),
                  onSelected: (v) => _acaoExercicio(context, i, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'trocar', child: Text('Trocar exercício')),
                    PopupMenuItem(
                        value: 'series', child: Text('Séries e repetições')),
                    PopupMenuItem(value: 'excluir', child: Text('Excluir do plano')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    if (travado) return cartao;
    return ReorderableDelayedDragStartListener(index: i, child: cartao);
  }
}

void abrirImportar(BuildContext context, void Function(int) irPara) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (c) => Scaffold(
        appBar: AppBar(),
        body: ImportarTela(
          irPara: (n) {
            Navigator.pop(c);
            irPara(n);
          },
        ),
      ),
    ),
  );
}

void detalheExercicio(BuildContext context, Item it) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSuperf,
    builder: (c) => _DetalheEx(it: it),
  );
}

class _DetalheEx extends StatefulWidget {
  final Item it;
  const _DetalheEx({required this.it});
  @override
  State<_DetalheEx> createState() => _DetalheExEstado();
}

class _DetalheExEstado extends State<_DetalheEx> {
  late final TextEditingController _obs;
  @override
  void initState() {
    super.initState();
    _obs = TextEditingController(text: app.obs[widget.it.exId] ?? '');
  }

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Widget _info(String valor, String rotulo) => Expanded(
        child: Column(
          children: [
            Text(valor, style: titulo(32)),
            Text(rotulo, style: const TextStyle(color: kMudo)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final it = widget.it;
    final ex = app.ex(it.exId);
    final equip = ex?.equip ?? '';
    final carga = app.cargas[it.exId] ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoExercicio(
                exId: it.exId,
                nome: ex?.nome ?? it.nome,
                abaixo: 16),
            Text(ex?.nome ?? it.nome, style: titulo(30)),
            const SizedBox(height: 6),
            Text(equip.isEmpty ? it.grupo : '${it.grupo} • $equip',
                style: const TextStyle(color: kMudo)),
            const SizedBox(height: 16),
            Row(
              children: [
                _info('${it.series}', 'séries'),
                _info(it.reps, 'repetições'),
                _info('${app.descanso}s', 'descanso'),
              ],
            ),
            if (carga.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Última carga: $carga kg',
                    style: const TextStyle(color: kMudo)),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _obs,
              maxLines: 3,
              onChanged: (v) => app.setObs(it.exId, v),
              decoration: InputDecoration(
                labelText: 'Minhas observações',
                filled: true,
                fillColor: branco(.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (app.ex(widget.it.exId) != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: estiloContornoFino,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AnatomiaTela(ex: app.ex(widget.it.exId)!)),
                ),
                icon: const Icon(Icons.accessibility_new, size: 18),
                label: const Text('Ver anatomia'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- Execução do treino ----------
class _ResumoEx {
  final String nome, grupo, reps;
  final List<double> cargas;
  final bool cresc; // última série foi "crescente" (3-4-5-6-7 = 25 reps)
  _ResumoEx(this.nome, this.grupo, this.reps, this.cargas, {this.cresc = false});

  Map<String, dynamic> toJson() =>
      {'nome': nome, 'grupo': grupo, 'reps': reps, 'cargas': cargas, 'cresc': cresc};
  factory _ResumoEx.fromJson(Map<String, dynamic> j) => _ResumoEx(
        j['nome'] as String,
        j['grupo'] as String,
        j['reps'] as String,
        [for (final c in (j['cargas'] as List)) (c as num).toDouble()],
        cresc: (j['cresc'] ?? false) as bool,
      );

  String get texto =>
      cresc ? '$_base • última crescente (25 reps)' : _base;

  String get _base {
    final n = cargas.length;
    final s = n == 1 ? 'série' : 'séries';
    final usadas = cargas.where((c) => c > 0).toList();
    if (usadas.isEmpty) return '$n $s • $reps reps';
    if (usadas.every((c) => c == usadas.first) && usadas.length == n) {
      return '$n × $reps • ${fmtNum(usadas.first)} kg';
    }
    return '$n $s • ${cargas.map(fmtNum).join(' / ')} kg';
  }
}

class _ProgEx {
  final int si;
  final List<double> cargas;
  final List<int> reps;
  _ProgEx(this.si, this.cargas, [this.reps = const <int>[]]);
  Map<String, dynamic> toJson() => {'si': si, 'cargas': cargas, 'reps': reps};
  factory _ProgEx.fromJson(Map<String, dynamic> j) => _ProgEx(
        j['si'] as int,
        [for (final c in (j['cargas'] as List)) (c as num).toDouble()],
        [for (final r in (j['reps'] as List? ?? const [])) (r as num).toInt()],
      );
}

/// Treino em andamento que sobrevive a sair da tela de execução.
class _RunSalvo {
  static _RunSalvo? atual;
  final String dia, data;
  final bool livre, pausado;
  final List<int> fila;
  final int si, seg, descanso, feitasSeries;
  final Map<String, String> rpe;
  final Map<int, int> extra;
  final Map<int, bool> crescTodas;
  final bool cresc;
  final int crescEtapa, crescPausa;
  final double volume;
  final List<_ResumoEx> resumo;
  final List<double> cargasEx;
  final List<int> repsEx;
  final Set<String> recordes;
  final Map<int, _ProgEx> prog;
  final DateTime saiuEm;
  final List<String> ids; // exId de cada posição do plano quando foi salvo
  final Set<String> excl; // exercícios excluídos só deste treino (exId)
  _RunSalvo({
    required this.dia,
    required this.data,
    required this.livre,
    required this.pausado,
    required this.fila,
    required this.si,
    required this.seg,
    required this.descanso,
    required this.feitasSeries,
    required this.rpe,
    required this.extra,
    required this.crescTodas,
    required this.cresc,
    required this.crescEtapa,
    required this.crescPausa,
    required this.volume,
    required this.resumo,
    required this.cargasEx,
    required this.repsEx,
    required this.recordes,
    required this.prog,
    required this.saiuEm,
    this.ids = const [],
    this.excl = const {},
  });

  Map<String, dynamic> toJson() => {
        'dia': dia,
        'data': data,
        'livre': livre,
        'pausado': pausado,
        'fila': fila,
        'si': si,
        'seg': seg,
        'descanso': descanso,
        'feitasSeries': feitasSeries,
        'rpe': rpe,
        'extra': extra.map((k, v) => MapEntry('$k', v)),
        'crescTodas': crescTodas.map((k, v) => MapEntry('$k', v)),
        'cresc': cresc,
        'crescEtapa': crescEtapa,
        'crescPausa': crescPausa,
        'volume': volume,
        'resumo': [for (final r in resumo) r.toJson()],
        'cargasEx': cargasEx,
        'repsEx': repsEx,
        'recordes': recordes.toList(),
        'prog': prog.map((k, v) => MapEntry('$k', v.toJson())),
        'saiuEm': saiuEm.toIso8601String(),
        'ids': ids,
        'excl': excl.toList(),
      };

  factory _RunSalvo.fromJson(Map<String, dynamic> j) => _RunSalvo(
        dia: j['dia'] as String,
        data: j['data'] as String,
        livre: (j['livre'] ?? false) as bool,
        pausado: (j['pausado'] ?? false) as bool,
        fila: [for (final x in (j['fila'] as List)) x as int],
        si: j['si'] as int,
        seg: j['seg'] as int,
        descanso: j['descanso'] as int,
        feitasSeries: j['feitasSeries'] as int,
        rpe: Map<String, String>.from(j['rpe'] as Map),
        extra: {
          for (final e in (j['extra'] as Map).entries)
            int.parse(e.key as String): e.value as int
        },
        crescTodas: {
          for (final e in ((j['crescTodas'] as Map?) ?? const {}).entries)
            int.parse(e.key as String): e.value as bool
        },
        cresc: (j['cresc'] ?? false) as bool,
        crescEtapa: (j['crescEtapa'] ?? 0) as int,
        crescPausa: (j['crescPausa'] ?? 0) as int,
        volume: (j['volume'] as num).toDouble(),
        resumo: [
          for (final r in (j['resumo'] as List))
            _ResumoEx.fromJson(Map<String, dynamic>.from(r as Map))
        ],
        cargasEx: [for (final c in (j['cargasEx'] as List)) (c as num).toDouble()],
        repsEx: [for (final r in (j['repsEx'] as List? ?? const [])) (r as num).toInt()],
        recordes: {for (final r in (j['recordes'] as List)) r as String},
        prog: {
          for (final e in (j['prog'] as Map).entries)
            int.parse(e.key as String):
                _ProgEx.fromJson(Map<String, dynamic>.from(e.value as Map))
        },
        saiuEm: DateTime.parse(j['saiuEm'] as String),
        ids: [for (final x in (j['ids'] as List? ?? const [])) x as String],
        excl: {for (final x in (j['excl'] as List? ?? const [])) x as String},
      );
}

/// Ao abrir o app: se havia um treino em andamento (o Android pode ter fechado o
/// app com a tela apagada), volta direto para ele, de onde parou.
Future<bool> retomarTreinoSalvo(BuildContext context) async {
  final raw = app.lerRunSalvo();
  if (raw == null) return false;
  try {
    final sv = _RunSalvo.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    Dia? dia;
    for (final d in app.plano) {
      if (d.nome == sv.dia) dia = d;
    }
    final velho = DateTime.now().difference(sv.saiuEm).inHours >= 8;
    // Treino salvo por versão antiga (sem ids) depende dos índices do plano.
    final foraDeIndice = dia == null ||
        (sv.ids.isEmpty &&
            (sv.fila.any((k) => k < 0 || k >= dia!.itens.length) ||
                sv.prog.keys.any((k) => k < 0 || k >= dia!.itens.length)));
    if (sv.livre || velho || foraDeIndice || sv.data != chaveData(DateTime.now())) {
      await app.gravarRunSalvo(null);
      return false;
    }
    _RunSalvo.atual = sv;
    if (!context.mounted) return false;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RunTela(dia: dia!)));
    return true;
  } catch (_) {
    await app.gravarRunSalvo(null);
    return false;
  }
}

class RunTela extends StatefulWidget {
  final Dia dia;
  final bool livre;
  const RunTela({
    super.key,
    required this.dia,
    this.livre = false,
  });
  @override
  State<RunTela> createState() => _RunEstado();
}

class _RunEstado extends State<RunTela> with WidgetsBindingObserver {
  late List<int> _fila; // ordem dos exercícios; "Pular" manda o atual para o fim
  int get ei => _fila.first;
  int si = 0, seg = 0, descanso = 0, feitasSeries = 0;
  final Map<String, String> _rpeNome = {}; // nome do exercício -> Fácil/Ok/Pesado
  final Map<int, int> _extra = {}; // séries a mais por exercício (só nesta execução)
  final Map<int, bool> _crescTodas = {}; // 3/7 em todas as séries deste exercício
  int get seriesAtual => it.series + (_extra[ei] ?? 0);
  bool pausado = false;
  bool _terminou = false;
  bool _semPendentes = false;
  late DateTime _ultimoTick;
  int _acumPersist = 0;
  final Map<int, _ProgEx> _prog = {}; // progresso de exercícios deixados pela metade
  double volume = 0;
  // Série crescente: 3-4-5-6-7 reps com 15 s de pausa (total 25), só na última série.
  static const _crescReps = [3, 4, 5, 6, 7];
  bool _cresc = false;
  int _crescEtapa = 0, _crescPausa = 0;
  bool get _elegivelCresc {
    final g = norm(app.ex(it.exId)?.grupo ?? it.grupo);
    final n = norm(app.ex(it.exId)?.nome ?? it.nome);
    return g.contains('biceps') ||
        g.contains('triceps') ||
        g.contains('ombro') ||
        g.contains('antebraco') ||
        n.contains('antebraco');
  }

  late Timer _t;
  final _carga = TextEditingController();
  final _repeticoes = TextEditingController();
  final List<int> _repsEx = [];
  final List<_ResumoEx> resumo = [];
  final List<double> _cargasEx = [];
  final Set<String> _recordes = {}; // exercícios que bateram o recorde nesta sessão
  final Set<String> _exclIds = {}; // exercícios excluídos só deste treino (exId)
  Item get it => widget.dia.itens[ei];

  /// Já feito ou excluído hoje: não volta para a fila.
  bool _resolvido(int k) {
    if (widget.livre) return false;
    final item = widget.dia.itens[k];
    final nome = app.ex(item.exId)?.nome ?? item.nome;
    return _exclIds.contains(item.exId) ||
        app.resolvidoHojeEx(nome, widget.dia.nome);
  }

  @override
  void initState() {
    super.initState();
    final salvo = _RunSalvo.atual;
    final continua = salvo != null &&
        salvo.dia == widget.dia.nome &&
        salvo.data == chaveData(DateTime.now()) &&
        salvo.livre == widget.livre;
    if (continua) {
      _restaurar(salvo!);
    } else {
      // Fila: só os exercícios que ainda faltam hoje (feitos e excluídos ficam de fora).
      final n = widget.dia.itens.length;
      final todos = [for (var k = 0; k < n; k++) k];
      final pend = [
        for (final k in todos)
          if (!_resolvido(k)) k
      ];
      final base = widget.livre ? todos : pend;
      _semPendentes = !widget.livre && base.isEmpty;
      _fila = _semPendentes ? [0] : List<int>.of(base);
    }
    if (_fila.isEmpty) {
      // O plano mudou e não sobrou nada para fazer.
      if (feitasSeries > 0 || resumo.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fim();
        });
      } else {
        _semPendentes = true;
        _fila = [0];
      }
    }
    if (!_semPendentes && _fila.isNotEmpty) _carregar();
    WidgetsBinding.instance.addObserver(this);
    _ultimoTick = DateTime.now();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      // Relógio real: se o app ficou em segundo plano, recupera o tempo perdido.
      final agora = DateTime.now();
      final dt = agora.difference(_ultimoTick).inSeconds;
      if (dt <= 0) return;
      _ultimoTick = _ultimoTick.add(Duration(seconds: dt));
      if (pausado) return;
      setState(() {
        seg += dt;
        descanso = descanso > dt ? descanso - dt : 0;
        if (_crescPausa > 0) {
          _crescPausa = _crescPausa > dt ? _crescPausa - dt : 0;
          if (_crescPausa == 0) HapticFeedback.heavyImpact();
        }
      });
      _acumPersist += dt;
      if (_acumPersist >= 5) {
        _acumPersist = 0;
        _persistir();
      }
    });
  }

  void _restaurar(_RunSalvo s) {
    final atuais = [for (final i in widget.dia.itens) i.exId];
    final igual = s.ids.isEmpty ||
        (s.ids.length == atuais.length &&
            Iterable<int>.generate(atuais.length)
                .every((k) => s.ids[k] == atuais[k]));
    // Posição antiga -> posição nova (o plano pode ter sido reordenado,
    // trocado ou ter exercícios excluídos/adicionados com o treino em andamento).
    final mapa = <int, int>{};
    if (igual) {
      for (var k = 0; k < atuais.length; k++) {
        mapa[k] = k;
      }
    } else {
      final usados = <int>{};
      for (var o = 0; o < s.ids.length; o++) {
        for (var n = 0; n < atuais.length; n++) {
          if (!usados.contains(n) && atuais[n] == s.ids[o]) {
            mapa[o] = n;
            usados.add(n);
            break;
          }
        }
      }
    }
    final cabecaAntiga = s.fila.isNotEmpty ? s.fila.first : null;
    final cabecaNova = cabecaAntiga == null ? null : mapa[cabecaAntiga];
    _fila = [
      for (final k in s.fila)
        if (mapa[k] != null) mapa[k]!
    ];
    for (final e in s.prog.entries) {
      final n = mapa[e.key];
      if (n != null) _prog[n] = e.value;
    }
    for (final e in s.extra.entries) {
      final n = mapa[e.key];
      if (n != null) _extra[n] = e.value;
    }
    for (final e in s.crescTodas.entries) {
      final n = mapa[e.key];
      if (n != null) _crescTodas[n] = e.value;
    }
    _exclIds.addAll(s.excl);
    si = s.si;
    feitasSeries = s.feitasSeries;
    volume = s.volume;
    pausado = s.pausado;
    _rpeNome.addAll(s.rpe);
    _cresc = s.cresc;
    _crescEtapa = s.crescEtapa;
    resumo.addAll(s.resumo);
    _cargasEx.addAll(s.cargasEx);
    _repsEx.addAll(s.repsEx);
    _recordes.addAll(s.recordes);
    // O cronômetro segue contando enquanto a tela esteve fechada.
    final dec = DateTime.now().difference(s.saiuEm).inSeconds;
    seg = s.seg + (s.pausado ? 0 : dec);
    descanso = s.pausado ? s.descanso : (s.descanso > dec ? s.descanso - dec : 0);
    _crescPausa = s.pausado ? s.crescPausa : (s.crescPausa > dec ? s.crescPausa - dec : 0);

    // O exercício em andamento saiu do plano (trocado ou excluído): descarta as
    // séries dele para o resumo não ficar com séries que não existem.
    if (cabecaAntiga != null && cabecaNova == null) {
      _descartarEmCurso();
      descanso = 0;
    }
    if (!igual && !widget.livre) _alinharComPlano(cabecaNova);

    // Mantém a lista de exercícios travados (feitos/excluídos) em dia com o app.
    if (!widget.livre) {
      app.definirRun(
        widget.dia.nome,
        [for (final r in resumo) r.nome],
        [
          for (final i in widget.dia.itens)
            if (_exclIds.contains(i.exId)) app.ex(i.exId)?.nome ?? i.nome
        ],
      );
    }
  }

  /// Joga fora as séries já feitas do exercício atual (ele saiu do treino).
  void _descartarEmCurso() {
    for (var i = 0; i < _cargasEx.length; i++) {
      volume -= _cargasEx[i] * (i < _repsEx.length ? _repsEx[i] : 0);
    }
    feitasSeries -= _cargasEx.length;
    if (feitasSeries < 0) feitasSeries = 0;
    if (volume < 0) volume = 0;
    _cargasEx.clear();
    _repsEx.clear();
    si = 0;
    _cresc = false;
    _crescEtapa = 0;
    _crescPausa = 0;
  }

  /// O plano foi reordenado/editado com o treino em andamento: os exercícios que
  /// faltam seguem a ordem nova. Feitos e excluídos nunca voltam.
  void _alinharComPlano(int? cabeca) {
    final emCurso = cabeca != null && (si > 0 || _cargasEx.isNotEmpty);
    final desejada = [
      for (var k = 0; k < widget.dia.itens.length; k++)
        if (!_resolvido(k)) k
    ];
    var mantem = false;
    if (emCurso) {
      mantem = desejada.remove(cabeca);
      if (mantem) {
        desejada.insert(0, cabeca!);
      } else {
        _descartarEmCurso();
      }
    }
    final mudouCabeca = desejada.isEmpty || desejada.first != cabeca;
    _fila = desejada;
    if (_fila.isEmpty) return;
    if (mudouCabeca) {
      si = 0;
      descanso = 0;
      _cresc = false;
      _crescEtapa = 0;
      _crescPausa = 0;
      _restaurarProgresso();
    }
  }

  void _salvarProgresso() {
    if (si > 0 || _cargasEx.isNotEmpty) {
      _prog[ei] = _ProgEx(si, List<double>.of(_cargasEx), List<int>.of(_repsEx));
    }
    _cargasEx.clear();
    _repsEx.clear();
  }

  void _restaurarProgresso() {
    final p = _prog.remove(ei);
    si = p?.si ?? 0;
    _cargasEx
      ..clear()
      ..addAll(p?.cargas ?? const <double>[]);
    _repsEx
      ..clear()
      ..addAll(p?.reps ?? const <int>[]);
  }

  _RunSalvo _instantaneo() => _RunSalvo(
        dia: widget.dia.nome,
        data: chaveData(DateTime.now()),
        livre: widget.livre,
        pausado: pausado,
        fila: List<int>.of(_fila),
        si: si,
        seg: seg,
        descanso: descanso,
        feitasSeries: feitasSeries,
        rpe: Map<String, String>.of(_rpeNome),
        extra: Map<int, int>.of(_extra),
        crescTodas: Map<int, bool>.of(_crescTodas),
        cresc: _cresc,
        crescEtapa: _crescEtapa,
        crescPausa: _crescPausa,
        volume: volume,
        resumo: List<_ResumoEx>.of(resumo),
        cargasEx: List<double>.of(_cargasEx),
        repsEx: List<int>.of(_repsEx),
        recordes: Set<String>.of(_recordes),
        prog: Map<int, _ProgEx>.of(_prog),
        saiuEm: DateTime.now(),
        ids: [for (final i in widget.dia.itens) i.exId],
        excl: Set<String>.of(_exclIds),
      );

  /// Guarda o treino em andamento no celular (sobrevive ao app ser fechado).
  void _persistir() {
    if (_terminou || widget.livre) return;
    try {
      app.gravarRunSalvo(jsonEncode(_instantaneo().toJson()));
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed) _persistir();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_terminou && !_semPendentes) {
      _RunSalvo.atual = _instantaneo();
      _persistir();
    }
    _t.cancel();
    _carga.dispose();
    _repeticoes.dispose();
    super.dispose();
  }

  void _carregar() {
    _carga.text = app.cargas[it.exId] ?? '';
    final padrao = int.tryParse(it.reps.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;
    _repeticoes.text = '$padrao';
  }

  Future<void> _concluir() async {
    app.setCarga(it.exId, _carga.text.trim());
    final cg = double.tryParse(_carga.text.trim().replaceAll(',', '.')) ?? 0;
    final recAtual = app.recorde(app.ex(it.exId)?.nome ?? it.nome);
    if (cg > 0 && recAtual != null && cg > recAtual) _recordes.add(it.exId);
    final usouCresc = _cresc;
    final repsFeitas = usouCresc
        ? 25
        : (int.tryParse(_repeticoes.text.trim()) ?? repsMedio(it.reps).round());
    volume += cg * repsFeitas;
    _repsEx.add(repsFeitas);
    feitasSeries++;
    _cargasEx.add(cg);
    _cresc = false;
    _crescEtapa = 0;
    _crescPausa = 0;
    if (si + 1 >= seriesAtual) {
      resumo.add(_ResumoEx(app.ex(it.exId)?.nome ?? it.nome, it.grupo,
          _repsEx.join(' / '), List<double>.from(_cargasEx),
          cresc: usouCresc));
      _cargasEx.clear();
      _repsEx.clear();
      // Exercício finalizado: trava na tela do treino (não dá para refazer hoje).
      if (!widget.livre) {
        app.marcarRunFeito(app.ex(it.exId)?.nome ?? it.nome, widget.dia.nome);
      }
      await _perguntarRpe();
      if (!mounted) return;
    }
    if (si + 1 < seriesAtual) {
      setState(() {
        si++;
        descanso = app.descanso;
      });
    } else if (_fila.length > 1) {
      setState(() {
        _fila.removeAt(0);
        si = 0;
        descanso = app.descanso;
        _restaurarProgresso();
        _carregar();
      });
    } else {
      _fim();
    }
    _persistir();
  }

  /// Pula para o próximo; este volta ao fim da fila (só se ainda não há série feita).
  void _pular() {
    setState(() {
      _fila.add(_fila.removeAt(0));
      si = 0;
      descanso = 0;
      _restaurarProgresso();
      _carregar();
    });
  }

  /// RPE: como foi o exercício que acabou de terminar. Ajusta a sugestão da próxima vez.
  Future<void> _perguntarRpe() async {
    final nome = app.ex(it.exId)?.nome ?? it.nome;
    final escolha = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Como foi $nome?'),
        content: const Text('Isso ajusta a sugestão de carga da próxima vez.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, 'Fácil'),
              child: const Text('Fácil')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'Ok'),
              child: const Text('Ok')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'Pesado'),
              child: const Text('Pesado')),
        ],
      ),
    );
    if (escolha != null) _rpeNome[nome] = escolha;
  }

  Future<void> _fim({bool parcial = false}) async {
    _terminou = true;
    _RunSalvo.atual = null;
    await app.gravarRunSalvo(null);
    _t.cancel();
    final total = widget.dia.itens
            .where((e) => !_exclIds.contains(e.exId))
            .fold<int>(0, (s, e) => s + e.series) +
        _extra.values.fold<int>(0, (s, e) => s + e);
    // Exercício que ficou pela metade entra no resumo como parcial.
    if (_cargasEx.isNotEmpty) {
      resumo.add(_ResumoEx(app.ex(it.exId)?.nome ?? it.nome, it.grupo,
          _repsEx.isEmpty ? it.reps : _repsEx.join(' / '), List<double>.from(_cargasEx)));
      _cargasEx.clear();
      _repsEx.clear();
    }
    // Exercícios deixados pela metade (ao trocar de exercício) entram como parciais.
    for (final e in _prog.entries) {
      if (e.value.cargas.isEmpty) continue;
      final item = widget.dia.itens[e.key];
      resumo.add(_ResumoEx(app.ex(item.exId)?.nome ?? item.nome, item.grupo,
          e.value.reps.isEmpty ? item.reps : e.value.reps.join(' / '), List<double>.of(e.value.cargas)));
    }
    _prog.clear();
    if (parcial && feitasSeries == 0) {
      if (!widget.livre) app.limparRun(widget.dia.nome);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    final sessao = Sessao(
      data: DateTime.now().toIso8601String(),
      dia: widget.dia.nome,
      seg: seg,
      series: feitasSeries,
      seriesTotal: total,
      volume: volume,
      completo: !parcial,
      livre: widget.livre,
      detalhes: [
        for (final r in resumo)
          {
            'nome': r.nome,
            'grupo': r.grupo,
            'reps': r.reps,
            'cargas': r.cargas,
            'rpe': _rpeNome[r.nome] ?? '',
            if (r.cresc) 'cresc': true,
          },
      ],
    );
    await app.addSessao(sessao);
    if (!parcial && !widget.livre) await app.concluirDia(DateTime.now());
    if (!widget.livre) app.limparRun(widget.dia.nome);
    if (!mounted) return;
    final nav = Navigator.of(context);
    final acao = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(parcial ? 'Treino parcial salvo' : 'Treino concluído'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Duração: ${_fmt(seg)}\nSéries: $feitasSeries de $total\nVolume: ${volume.round()} kg'),
              const SizedBox(height: 12),
              for (final r in resumo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ${r.nome}\n   ${r.texto}',
                      style: const TextStyle(color: kMudo, fontSize: 13)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, 'cardio'),
              child: const Text('Fazer cardio')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'share'),
              child: const Text('Compartilhar')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'ok'),
              child: const Text('OK')),
        ],
      ),
    );
    nav.popUntil((r) => r.isFirst);
    if (acao == 'share') {
      nav.push(MaterialPageRoute(
          builder: (_) => CompartilharTela(sessao: sessao)));
    }
    if (acao == 'cardio') {
      nav.push(MaterialPageRoute(builder: (_) => const CardioTela()));
    }
  }

  /// Termina o treino agora: salva o que foi feito e marca o dia como concluído.
  Future<void> _finalizar() async {
    final emCurso = si > 0 || _cargasEx.isNotEmpty;
    final faltam = _fila.length - (emCurso ? 1 : 0);
    final nada = feitasSeries == 0;
    final texto = nada
        ? 'Nenhuma série foi concluída, então nada será salvo.'
        : faltam > 0
            ? 'Ainda ${faltam == 1 ? 'falta 1 exercício' : 'faltam $faltam exercícios'}. O treino de hoje será salvo como concluído, com o que você fez.'
            : 'O treino de hoje será salvo como concluído.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Finalizar treino?'),
        content: Text(texto),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Continuar treinando')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Finalizar')),
        ],
      ),
    );
    if (ok == true) await _fim(parcial: nada);
  }

  /// Tira o exercício atual só do treino de hoje (o plano não muda).
  Future<void> _excluirExercicio() async {
    final nome = app.ex(it.exId)?.nome ?? it.nome;
    final fez = _cargasEx.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Excluir $nome de hoje?'),
        content: Text(fez > 0
            ? 'As $fez série(s) já feitas deste exercício não serão salvas. A rotina do plano continua igual.'
            : 'Ele sai só do treino de hoje. A rotina do plano continua igual.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final idx = ei;
    final exId = it.exId;
    _descartarEmCurso();
    _exclIds.add(exId);
    _extra.remove(idx);
    _crescTodas.remove(idx);
    if (!widget.livre) app.marcarRunExcluido(nome, widget.dia.nome);
    if (_fila.length > 1) {
      setState(() {
        _fila.removeAt(0);
        si = 0;
        descanso = 0;
        _restaurarProgresso();
        _carregar();
      });
      _persistir();
      return;
    }
    // Era o último exercício que faltava.
    _fila.removeAt(0);
    if (feitasSeries > 0 || resumo.isNotEmpty) {
      await _fim();
    } else {
      _terminou = true;
      _RunSalvo.atual = null;
      await app.gravarRunSalvo(null);
      if (!widget.livre) app.limparRun(widget.dia.nome);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fila.isEmpty) return const Scaffold(body: SizedBox.expand());
    if (_semPendentes) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.dia.nome, style: titulo(26))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: kAzul, size: 52),
                const SizedBox(height: 14),
                Text('Treino de hoje concluído', style: titulo(24)),
                const SizedBox(height: 8),
                const Text('Todos os exercícios deste treino já foram registrados hoje.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMudo)),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final nome = app.ex(it.exId)?.nome ?? it.nome;
    final prox = _fila.length > 1 ? widget.dia.itens[_fila[1]] : null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                ),
                const Spacer(),
                Vidro(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  raio: 30,
                  onTap: () => setState(() => pausado = !pausado),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_fmt(seg), style: titulo(26)),
                      const SizedBox(width: 10),
                      Icon(pausado
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 16),
            Vidro(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome, style: titulo(30)),
                  Text(
                      '${it.grupo} • exercício ${ei + 1} de ${widget.dia.itens.length}',
                      style: const TextStyle(color: kMudo)),
                  if (_recordes.contains(it.exId))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('Recorde! Maior carga',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if ((app.obs[it.exId] ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Obs: ${app.obs[it.exId]}',
                          style: const TextStyle(color: Colors.amberAccent)),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: branco(.045),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: branco(.10)),
                    ),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: kAzul,
                      title: const Text('Método 3/7 em todas as séries',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('3, 4, 5, 6 e 7 repetições com 15 s de pausa',
                          style: TextStyle(color: kMudo, fontSize: 11)),
                      value: _crescTodas[ei] ?? false,
                      onChanged: (v) => setState(() {
                        _crescTodas[ei] = v;
                        _persistir();
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(
                      seriesAtual,
                      (i) => Expanded(
                        child: Container(
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i < si ? kAzul : branco(.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _cresc
                      ? _crescW()
                      : (descanso > 0 ? _descansoW() : _serieW()),
                ],
              ),
            ),
            if (prox != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Próximo: ${prox.nome}',
                    style: const TextStyle(color: kMudo)),
              ),
            if (si == 0 && _fila.length > 1 && !_cresc)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  style: estiloContornoFino,
                  onPressed: _pular,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text('Pular para o próximo'),
                ),
              ),
            if (!_cresc)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                style: estiloContornoFino,
                onPressed: () => setState(() => _extra[ei] = (_extra[ei] ?? 0) + 1),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar 1 série'),
              ),
            ),
            if (!_cresc)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  style: estiloContornoFino.merge(OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                        color: Colors.redAccent.withOpacity(.7), width: 1),
                  )),
                  onPressed: _excluirExercicio,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Excluir exercício de hoje'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                style: estiloContornoFino,
                onPressed: _finalizar,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Finalizar treino'),
              ),
            ),
            if (resumo.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Resumo do treino', style: titulo(26)),
              const SizedBox(height: 8),
              for (final r in resumo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Vidro(
                    padding: const EdgeInsets.all(14),
                    raio: 20,
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: kAzul),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.nome,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${r.grupo} • ${r.texto}',
                                  style: const TextStyle(
                                      color: kMudo, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _serieW() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Série ${si + 1} de $seriesAtual', style: titulo(26)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _repeticoes,
                      keyboardType: TextInputType.number,
                      style: titulo(54),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: '15',
                      ),
                    ),
                  ),
                  const Text('Repetições • toque para editar',
                      style: TextStyle(color: kMudo, fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _carga,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Carga (kg)',
                  filled: true,
                  fillColor: branco(.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: BotaoVerExecucao(
              exId: it.exId, nome: app.ex(it.exId)?.nome ?? it.nome),
        ),
        const SizedBox(height: 14),
        if ((_crescTodas[ei] ?? false) || (si + 1 >= seriesAtual && _elegivelCresc)) ...[
          OutlinedButton.icon(
            style: estiloContornoFino.merge(
                OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48))),
            onPressed: () => setState(() {
              _cresc = true;
              _crescEtapa = 0;
              _crescPausa = 0;
            }),
            icon: const Icon(Icons.stacked_line_chart),
            label: Text((_crescTodas[ei] ?? false)
                ? 'Iniciar método 3/7 nesta série'
                : 'Série crescente (3-4-5-6-7)'),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          style: estiloPrimario,
          onPressed: _concluir,
          icon: const Icon(Icons.check),
          label: const Text('Concluir série'),
        ),
      ],
    );
  }

  void _crescAvanca() {
    if (_crescEtapa < _crescReps.length - 1) {
      setState(() {
        _crescEtapa++;
        _crescPausa = 15;
      });
    } else {
      _concluir();
    }
  }

  Widget _crescW() {
    final ultima = _crescEtapa == _crescReps.length - 1;
    if (_crescPausa > 0) {
      return Column(
        children: [
          const Center(
              child: Text('Pausa curta', style: TextStyle(color: kMudo))),
          Center(child: Text('$_crescPausa', style: titulo(96))),
          Center(
              child: Text('Próxima: ${_crescReps[_crescEtapa]} repetições',
                  style: const TextStyle(color: kMudo))),
          const SizedBox(height: 14),
          FilledButton(
            style: estiloPrimario,
            onPressed: () => setState(() => _crescPausa = 0),
            child: const Text('Pular pausa'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Série crescente • etapa ${_crescEtapa + 1} de ${_crescReps.length}',
            style: titulo(26)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_crescReps[_crescEtapa]}', style: titulo(54)),
                  const Text('Repetições (total 25)',
                      style: TextStyle(color: kMudo)),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _carga,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Carga (kg)',
                  filled: true,
                  fillColor: branco(.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: estiloPrimario,
          onPressed: _crescAvanca,
          icon: const Icon(Icons.check),
          label: Text(ultima
              ? 'Concluir série crescente'
              : 'Fiz as ${_crescReps[_crescEtapa]} reps'),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _cresc = false;
              _crescEtapa = 0;
              _crescPausa = 0;
            }),
            child: const Text('Cancelar e voltar à série normal'),
          ),
        ),
      ],
    );
  }

  Widget _descansoW() {
    return Column(
      children: [
        const Center(child: _DescansoPulsante()),
        Center(child: Text(_fmt(descanso), style: titulo(96))),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: estiloContorno,
                onPressed: () => setState(() => descanso += 15),
                child: const Text('+15 s'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: estiloPrimario,
                onPressed: () => setState(() => descanso = 0),
                child: const Text('Pular'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Descanso" pulsando em branco metálico (brilho que desliza + pulso suave).
class _DescansoPulsante extends StatefulWidget {
  const _DescansoPulsante();
  @override
  State<_DescansoPulsante> createState() => _DescansoPulsanteEstado();
}

class _DescansoPulsanteEstado extends State<_DescansoPulsante>
    with TickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);
  late final AnimationController _brilho = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  @override
  void dispose() {
    _pulso.dispose();
    _brilho.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulso, _brilho]),
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulso.value);
        final b = _brilho.value;
        return Opacity(
          opacity: 0.6 + 0.4 * t,
          child: Transform.scale(
            scale: 1.0 + 0.08 * t,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => LinearGradient(
                begin: Alignment(-2.0 + 3.0 * b, -0.4),
                end: Alignment(-0.6 + 3.0 * b, 0.4),
                tileMode: TileMode.repeated,
                colors: const [
                  Color(0xFF8C9199),
                  Color(0xFFFFFFFF),
                  Color(0xFFC9CDD3),
                  Color(0xFF8C9199),
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ).createShader(r),
              child: Text(
                'Descanso',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                        color: Colors.white.withOpacity(0.35 * t),
                        blurRadius: 14),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Biblioteca ----------
class BibliotecaTela extends StatefulWidget {
  final bool selecionar;
  const BibliotecaTela({super.key, this.selecionar = false});
  @override
  State<BibliotecaTela> createState() => _BibEstado();
}

class _BibEstado extends State<BibliotecaTela> {
  String q = '';

  List<Exercicio> _filtrar() {
    final n = norm(q);
    final l = app.lib
        .where((e) =>
            n.isEmpty ||
            norm(e.nome).contains(n) ||
            norm(e.grupo).contains(n) ||
            e.apelidos.any((a) => norm(a).contains(n)))
        .toList();
    // Ordena por grupo e depois por nome, para cada grupo ficar junto.
    l.sort((a, b) {
      final g = norm(a.grupo).compareTo(norm(b.grupo));
      return g != 0 ? g : norm(a.nome).compareTo(norm(b.nome));
    });
    return l;
  }

  void _novo() {
    final nome = TextEditingController();
    final grupo = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Novo exercício'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nome,
                decoration: const InputDecoration(labelText: 'Nome')),
            TextField(
                controller: grupo,
                decoration:
                    const InputDecoration(labelText: 'Grupo muscular')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (nome.text.trim().isNotEmpty) {
                app.addCustom(nome.text.trim(), grupo.text.trim());
              }
              Navigator.pop(c);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _detalhe(Exercicio e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSuperf,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            VideoExercicio(exId: e.id, nome: e.nome, altura: 300, abaixo: 16),
            Text(e.nome, style: titulo(30)),
            const SizedBox(height: 8),
            Text('Grupo: ${e.grupo}', style: const TextStyle(color: kMudo)),
            if (e.equip.isNotEmpty)
              Text('Equipamento: ${e.equip}',
                  style: const TextStyle(color: kMudo)),
            if (e.apelidos.isNotEmpty)
              Text('Também: ${e.apelidos.join(', ')}',
                  style: const TextStyle(color: kMudo)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: estiloPrimario,
              onPressed: () {
                Navigator.pop(c);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AnatomiaTela(ex: e)));
              },
              icon: const Icon(Icons.accessibility_new),
              label: const Text('Ver anatomia'),
            ),
          ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.selecionar
          ? AppBar(title: Text('Escolher exercício', style: titulo(26)))
          : null,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final lista = _filtrar();
            // Agrupa por grupo muscular: cabeçalho antes de cada grupo.
            final itens = <Object>[];
            String? grupoAtual;
            for (final e in lista) {
              final chave = norm(e.grupo);
              if (chave != grupoAtual) {
                grupoAtual = chave;
                itens.add(e.grupo);
              }
              itens.add(e);
            }
            return Column(
              children: [
                if (!widget.selecionar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Biblioteca', style: titulo(34)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => q = v),
                          decoration: InputDecoration(
                            hintText: 'Buscar exercício ou grupo',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: branco(.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                          onPressed: _novo,
                          icon: const Icon(Icons.add_circle_outline)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: itens.length,
                    itemBuilder: (context, i) {
                      final o = itens[i];
                      if (o is String) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnelBrilho(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                child: Text(o, style: titulo(22)),
                              ),
                            ),
                          ),
                        );
                      }
                      final e = o as Exercicio;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Material(
                          color: branco(.06),
                          borderRadius: BorderRadius.circular(18),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            title: Text(e.nome),
                            subtitle: Text(
                              e.equip.isEmpty
                                  ? e.grupo
                                  : '${e.grupo} • ${e.equip}',
                              style: const TextStyle(color: kMudo),
                            ),
                            trailing: IconButton(
                              tooltip: 'Editar exercício',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ExercicioEditTela(exercicio: e)),
                              ),
                              icon: Icon(
                                Icons.edit_note,
                                color: (e.custom || app.exOver.containsKey(e.id))
                                    ? kAzul
                                    : kMudo,
                              ),
                            ),
                            onTap: () => widget.selecionar
                                ? Navigator.pop(context, e)
                                : _detalhe(e),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------- Importar PDF ----------
class ImportarTela extends StatefulWidget {
  final void Function(int) irPara;
  const ImportarTela({super.key, required this.irPara});
  @override
  State<ImportarTela> createState() => _ImpEstado();
}

class _ImpEstado extends State<ImportarTela> {
  List<Dia> dias = [];
  String? arq;
  String? erro;

  Future<void> _escolher() async {
    setState(() => erro = null);
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (r == null || r.files.single.bytes == null) return;
      final doc = PdfDocument(inputBytes: r.files.single.bytes!);
      final texto = PdfTextExtractor(doc).extractText(layoutText: true);
      doc.dispose();
      final lido = lerPlano(texto, app.lib);
      setState(() {
        arq = r.files.single.name;
        dias = lido;
        if (lido.isEmpty) {
          erro = 'Não encontrei exercícios nesse PDF.';
        }
      });
    } catch (e) {
      setState(() => erro = 'Erro ao ler o PDF: $e');
    }
  }

  Future<void> _salvar() async {
    await app.salvarPlano(dias.where((d) => d.itens.isNotEmpty).toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Treino salvo!')));
    setState(() => dias = []);
    widget.irPara(0);
  }


  Future<void> _exportarPlano() async {
    if (app.plano.isEmpty || app.plano.every((d) => d.itens.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seu plano ainda não tem exercícios para exportar.')),
      );
      return;
    }
    final doc = PdfDocument();
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final dayFont = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
    final mutedFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    var page = doc.pages.add();
    var y = 34.0;
    void header() {
      page.graphics.drawString('MEU TREINO', titleFont,
          bounds: Rect.fromLTWH(28, y, 500, 30));
      y += 30;
      page.graphics.drawString('Plano semanal • Exportado em ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
          mutedFont, bounds: Rect.fromLTWH(28, y, 520, 18));
      y += 28;
    }
    header();
    for (final dia in app.plano) {
      if (dia.itens.isEmpty) continue;
      if (y > 730) {
        page = doc.pages.add();
        y = 30;
        header();
      }
      page.graphics.drawString(dia.nome, dayFont,
          bounds: Rect.fromLTWH(28, y, 520, 22));
      y += 20;
      if (dia.foco.trim().isNotEmpty) {
        page.graphics.drawString('Foco: ${dia.foco}', mutedFont,
            bounds: Rect.fromLTWH(28, y, 520, 16));
        y += 17;
      }
      for (var i = 0; i < dia.itens.length; i++) {
        if (y > 760) {
          page = doc.pages.add();
          y = 30;
          header();
        }
        final ex = dia.itens[i];
        final line = '${i + 1}. ${ex.nome}';
        page.graphics.drawString(line, bodyFont,
            bounds: Rect.fromLTWH(36, y, 500, 16));
        y += 15;
        page.graphics.drawString('${ex.grupo}  •  ${ex.series} séries  •  ${ex.reps} repetições',
            mutedFont, bounds: Rect.fromLTWH(48, y, 490, 15));
        y += 21;
      }
      y += 12;
    }
    final bytes = await doc.save();
    doc.dispose();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Meu_Treino_Plano_Semanal.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')],
        text: 'Meu plano de treino atualizado');
  }

  @override
  Widget build(BuildContext context) {
    final semMatch =
        dias.fold<int>(0, (s, d) => s + d.itens.where((i) => i.exId.isEmpty).length);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Text('Plano de treino', style: titulo(34)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exportarPlano,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Exportar plano atual em PDF'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: estiloPrimario,
            onPressed: _escolher,
            icon: const Icon(Icons.upload_file),
            label: Text(arq == null ? 'Importar treino em PDF' : 'Escolher outro PDF'),
          ),
          if (erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(erro!, style: const TextStyle(color: Colors.redAccent)),
            ),
          if (dias.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Toque no nome para trocar o exercício, arraste ≡ para reordenar.',
              style: TextStyle(color: kMudo, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              semMatch == 0
                  ? 'Tudo encontrado na biblioteca.'
                  : '$semMatch sem correspondência: toque no nome para escolher na biblioteca ou salve para criar como novo.',
              style: const TextStyle(color: kMudo),
            ),
            for (final d in dias) ...[
              const SizedBox(height: 16),
              Text(d.nome, style: titulo(28)),
              if (d.foco.isNotEmpty)
                Text(d.foco, style: const TextStyle(color: kMudo)),
              const SizedBox(height: 6),
              ListaItensEditavel(
                itens: d.itens,
                onChanged: () => setState(() {}),
              ),
              TextButton.icon(
                onPressed: () => adicionarExercicioA(
                    context, d.itens, () => setState(() {})),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar exercício'),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: estiloPrimario,
              onPressed: _salvar,
              child: const Text('Salvar treino'),
            ),
          ],
        ],
      ),
    );
  }
}
