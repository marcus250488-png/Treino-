import 'dart:async';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'
    show PdfDocument, PdfTextExtractor;
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
  side: const BorderSide(color: kAzul, width: 2),
  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
);

const _sem = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

/// Anel fino com um brilho que gira em volta do dia selecionado.
class _AnelBrilho extends StatefulWidget {
  final Widget child;
  const _AnelBrilho({required this.child});
  @override
  State<_AnelBrilho> createState() => _AnelBrilhoEstado();
}

class _AnelBrilhoEstado extends State<_AnelBrilho>
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
        foregroundPainter: _AnelBrilhoPainter(_c.value),
        child: child,
      ),
    );
  }
}

class _AnelBrilhoPainter extends CustomPainter {
  final double t;
  _AnelBrilhoPainter(this.t);

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
  bool shouldRepaint(covariant _AnelBrilhoPainter old) => old.t != t;
}

Widget _envolveSel(bool sel, Widget child) =>
    sel ? _AnelBrilho(child: child) : child;
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
    _sel = DateTime.now().weekday % 7;
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
        final domingo = DateTime(hoje.year, hoje.month, hoje.day)
            .subtract(Duration(days: hoje.weekday % 7))
            .add(Duration(days: 7 * _semOff));
        final semana =
            List.generate(7, (i) => domingo.add(Duration(days: i)));
        final nFeitos =
            semana.where((d) => app.feitos.contains(chaveData(d))).length;
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
                          ? 'Esta semana'
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
    return Expanded(
      child: GestureDetector(
        onTap: () => _escolherDia(i),
        child: _envolveSel(sel, AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
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
                      fontSize: 15,
                      color: chaveData(d) == chaveData(hoje)
                          ? kAzul
                          : Colors.white)),
              Text(_sem[d.weekday % 7],
                  style: const TextStyle(color: kMudo, fontSize: 12)),
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
                  ? '${f.dia} • ${f.resumoCardio}'
                  : '${f.dia} • ${(f.seg / 60).round()} min',
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
            !app.feitoHojeEx(app.ex(i.exId)?.nome ?? i.nome, dia.nome))
        .length;
    final retomando = !feitoHoje && faltam > 0 && faltam < dia.itens.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(data != null ? _nomeDia(data!) : dia.nome, style: titulo(28)),
        actions: [
          IconButton(
            tooltip: 'Editar treino (trocar e reordenar)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditarDiaTela(dia: dia)),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          _cabecalho(resumo),
          const SizedBox(height: 12),
          _blocoAquecimento(),
          for (var i = 0; i < dia.itens.length; i++)
            _cartaoExercicio(context, i),
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

  Widget _cartaoExercicio(BuildContext context, int i) {
    final it = dia.itens[i];
    final ex = app.ex(it.exId);
    final nome = ex?.nome ?? it.nome;
    final equip = ex?.equip ?? '';
    final feito = app.feitoHojeEx(nome, dia.nome);
    final estilo = estiloGrupo(it.grupo);
    final ultimas = app.ultimasCargas(nome);
    final sugerida = app.sugestaoCarga(nome, it.series);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: feito ? .45 : 1,
        child: Vidro(
          padding: const EdgeInsets.all(14),
          raio: 22,
          onTap: () => detalheExercicio(context, it, dia: dia, indice: i),
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
                child: Icon(feito ? Icons.check : estilo.icone,
                    color: feito ? Colors.white : estilo.cor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: titulo(22)),
                    Text(equip.isEmpty ? it.grupo : '${it.grupo} • $equip',
                        style: TextStyle(color: estilo.cor, fontSize: 13)),
                    if (ultimas != null && ultimas.isNotEmpty)
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
            ],
          ),
        ),
      ),
    );
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

/// Tira um exercício só da sessão de hoje e salva o treino de hoje como completo,
/// com os exercícios feitos. A rotina do dia não muda.
Future<void> finalizarTreinoSemExercicio(Dia dia, String nome) async {
  final k = chaveData(DateTime.now());
  final doDia = app.sessoes
      .where((s) =>
          !s.cardio &&
          s.dia == dia.nome &&
          chaveData(DateTime.tryParse(s.data) ?? DateTime(1970)) == k)
      .toList();

  var seg = 0;
  var series = 0;
  var volume = 0.0;
  final det = <Map<String, dynamic>>[];
  for (final s in doDia) {
    seg += s.seg;
    series += s.series;
    volume += s.volume;
    for (final m in s.detalhes ?? const <Map<String, dynamic>>[]) {
      if (m['nome'] == nome) {
        // Remove o volume e as séries deste exercício da sessão.
        final cargas = ((m['cargas'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList();
        series -= cargas.length;
        volume -= cargas.fold<double>(0, (a, c) => a + c) *
            repsMedio((m['reps'] ?? '') as String);
      } else {
        det.add(m);
      }
    }
  }

  // Séries planejadas de hoje, sem o exercício removido.
  var total = 0;
  for (final i in dia.itens) {
    if ((app.ex(i.exId)?.nome ?? i.nome) != nome) total += i.series;
  }

  final sessao = Sessao(
    data: DateTime.now().toIso8601String(),
    dia: dia.nome,
    seg: seg,
    series: series < 0 ? 0 : series,
    seriesTotal: total,
    volume: volume < 0 ? 0 : volume,
    completo: true,
    livre: false,
    detalhes: det,
  );
  for (final s in doDia) {
    await app.excluirSessao(s);
  }
  await app.addSessao(sessao);
  await app.concluirDia(DateTime.now());
}

void detalheExercicio(BuildContext context, Item it,
    {Dia? dia, int indice = 0}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: kSuperf,
    builder: (c) => _DetalheEx(it: it, dia: dia, indice: indice),
  );
}

class _DetalheEx extends StatefulWidget {
  final Item it;
  final Dia? dia;
  final int indice;
  const _DetalheEx({required this.it, this.dia, this.indice = 0});
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
            if (widget.dia != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                style: estiloPrimario,
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(
                    builder: (_) =>
                        RunTela(dia: widget.dia!, inicio: widget.indice),
                  ));
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Começar daqui'),
              ),
              if (app.eTreinoDeHoje(widget.dia!)) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Excluir e finalizar treino?'),
                        content: const Text(
                            'Remover este exercício só de hoje e finalizar o treino?\n\nA rotina dos outros dias continua igual.'),
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
                    final nome = app.ex(widget.it.exId)?.nome ?? widget.it.nome;
                    await finalizarTreinoSemExercicio(widget.dia!, nome);
                    if (!mounted) return;
                    nav.pop();
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Treino de hoje finalizado')));
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir e finalizar treino'),
                ),
              ],
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
  _ResumoEx(this.nome, this.grupo, this.reps, this.cargas);

  String get texto {
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

class RunTela extends StatefulWidget {
  final Dia dia;
  final bool livre;
  final int inicio; // exercício em que começar ("começar daqui")
  const RunTela({
    super.key,
    required this.dia,
    this.livre = false,
    this.inicio = 0,
  });
  @override
  State<RunTela> createState() => _RunEstado();
}

class _RunEstado extends State<RunTela> {
  late List<int> _fila; // ordem dos exercícios; "Pular" manda o atual para o fim
  int get ei => _fila.first;
  int si = 0, seg = 0, descanso = 0, feitasSeries = 0;
  final Map<String, String> _rpeNome = {}; // nome do exercício -> Fácil/Ok/Pesado
  final Map<int, int> _extra = {}; // séries a mais por exercício (só nesta execução)
  int get seriesAtual => it.series + (_extra[ei] ?? 0);
  bool pausado = false;
  double volume = 0;
  late Timer _t;
  final _carga = TextEditingController();
  final List<_ResumoEx> resumo = [];
  final List<double> _cargasEx = [];
  final Set<String> _recordes = {}; // exercícios que bateram o recorde nesta sessão
  Item get it => widget.dia.itens[ei];

  @override
  void initState() {
    super.initState();
    // Fila: só os exercícios que ainda faltam hoje (se já houve treino parcial).
    final n = widget.dia.itens.length;
    final todos = [for (var k = 0; k < n; k++) k];
    final pend = [
      for (final k in todos)
        if (!app.feitoHojeEx(
            app.ex(widget.dia.itens[k].exId)?.nome ?? widget.dia.itens[k].nome,
            widget.dia.nome))
          k
    ];
    var base = widget.livre || pend.isEmpty ? todos : pend;
    final ini = widget.inicio > 0 && widget.inicio < n ? widget.inicio : 0;
    if (ini > 0 && !base.contains(ini)) base = [ini, ...base];
    final pos = base.indexOf(ini);
    _fila = pos > 0
        ? [for (var k = 0; k < base.length; k++) base[(pos + k) % base.length]]
        : base;
    _carregar();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (pausado) return;
      setState(() {
        seg++;
        if (descanso > 0) descanso--;
      });
    });
  }

  @override
  void dispose() {
    _t.cancel();
    _carga.dispose();
    super.dispose();
  }

  void _carregar() => _carga.text = app.cargas[it.exId] ?? '';

  Future<void> _concluir() async {
    app.setCarga(it.exId, _carga.text.trim());
    final cg = double.tryParse(_carga.text.trim().replaceAll(',', '.')) ?? 0;
    final recAtual = app.recorde(app.ex(it.exId)?.nome ?? it.nome);
    if (cg > 0 && recAtual != null && cg > recAtual) _recordes.add(it.exId);
    volume += cg * repsMedio(it.reps);
    feitasSeries++;
    _cargasEx.add(cg);
    if (si + 1 >= seriesAtual) {
      resumo.add(_ResumoEx(app.ex(it.exId)?.nome ?? it.nome, it.grupo,
          it.reps, List<double>.from(_cargasEx)));
      _cargasEx.clear();
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
        _carregar();
      });
    } else {
      _fim();
    }
  }

  /// Pula para o próximo; este volta ao fim da fila (só se ainda não há série feita).
  void _pular() {
    setState(() {
      _fila.add(_fila.removeAt(0));
      si = 0;
      descanso = 0;
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
    _t.cancel();
    final total = widget.dia.itens.fold<int>(0, (s, e) => s + e.series) +
        _extra.values.fold<int>(0, (s, e) => s + e);
    // Exercício que ficou pela metade entra no resumo como parcial.
    if (_cargasEx.isNotEmpty) {
      resumo.add(_ResumoEx(app.ex(it.exId)?.nome ?? it.nome, it.grupo,
          it.reps, List<double>.from(_cargasEx)));
      _cargasEx.clear();
    }
    if (parcial && feitasSeries == 0) {
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
          },
      ],
    );
    await app.addSessao(sessao);
    if (!parcial && !widget.livre) await app.concluirDia(DateTime.now());
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

  Future<void> _encerrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Encerrar treino?'),
        content: Text(feitasSeries == 0
            ? 'Nenhuma série foi concluída, então nada será salvo.'
            : 'Vamos salvar como treino parcial ($feitasSeries séries).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Continuar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Encerrar')),
        ],
      ),
    );
    if (ok == true) await _fim(parcial: true);
  }

  @override
  Widget build(BuildContext context) {
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
                IconButton(
                  tooltip: 'Encerrar treino',
                  onPressed: _encerrar,
                  icon: const Icon(Icons.stop_circle_outlined, size: 30),
                ),
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
                  descanso > 0 ? _descansoW() : _serieW(),
                ],
              ),
            ),
            if (prox != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Próximo: ${prox.nome}',
                    style: const TextStyle(color: kMudo)),
              ),
            if (si == 0 && _fila.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  style: estiloContornoFino,
                  onPressed: _pular,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text('Pular para o próximo'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                style: estiloContornoFino,
                onPressed: () => setState(() => _extra[ei] = (_extra[ei] ?? 0) + 1),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar 1 série'),
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
        Text('Série ${si + 1} de ${it.series}', style: titulo(26)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.reps, style: titulo(54)),
                  const Text('Repetições', style: TextStyle(color: kMudo)),
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
        FilledButton.icon(
          style: estiloPrimario,
          onPressed: _concluir,
          icon: const Icon(Icons.check),
          label: const Text('Concluir série'),
        ),
      ],
    );
  }

  Widget _descansoW() {
    return Column(
      children: [
        const Center(child: Text('Descanso', style: TextStyle(color: kMudo))),
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
      backgroundColor: kSuperf,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                            child: _AnelBrilho(
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

  @override
  Widget build(BuildContext context) {
    final semMatch =
        dias.fold<int>(0, (s, d) => s + d.itens.where((i) => i.exId.isEmpty).length);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Text('Importar treino', style: titulo(34)),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: estiloPrimario,
            onPressed: _escolher,
            icon: const Icon(Icons.upload_file),
            label: Text(arq == null ? 'Escolher PDF' : 'Escolher outro PDF'),
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
