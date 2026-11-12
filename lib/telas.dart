import 'dart:async';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'
    show PdfDocument, PdfTextExtractor;
import 'state.dart';
import 'extras.dart' show MeuPlanoTela, DesempenhoTela;

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
final estiloContorno = OutlinedButton.styleFrom(
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(56),
  shape: const StadiumBorder(),
  side: const BorderSide(color: kAzul, width: 2),
  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
);

const _sem = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
String _dois(int n) => n.toString().padLeft(2, '0');
String _fmt(int s) => '${_dois(s ~/ 60)}:${_dois(s % 60)}';

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
                'Entre com sua conta Google para ter sua foto e seu nome no app.',
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
            .subtract(Duration(days: hoje.weekday % 7));
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
                children: [
                  for (var i = 0; i < 7; i++) _diaBtn(i, semana[i], hoje),
                ],
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
    final feito = app.feitos.contains(chaveData(d));
    final sel = i == _sel;
    final temTreino = app.treinoNo(d) != null;
    return Expanded(
      child: GestureDetector(
        onTap: () => _escolherDia(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF0A1F4D) : branco(.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: sel ? kAzul : branco(.12), width: sel ? 2 : 1),
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
        ),
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

  Widget _hero(BuildContext context, DateTime data, DateTime hoje) {
    final eHoje = chaveData(data) == chaveData(hoje);
    final feito = app.feitos.contains(chaveData(data));
    final dia = app.treinoNo(data);

    if (dia == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _decCard,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bedtime_outlined, size: 90, color: kMudo),
            const SizedBox(height: 16),
            Text('Descanso', style: titulo(46)),
            const SizedBox(height: 6),
            Text('Sem treino na ${_nomeDia(data)}.',
                style: const TextStyle(color: kMudo)),
          ],
        ),
      );
    }

    final grupos = dia.itens.map((e) => e.grupo).toSet().toList();
    final series = dia.itens.fold<int>(0, (s, e) => s + e.series);
    final min = (series * (40 + app.descanso) / 60).round();
    final kcal = (min * 6.5).round();
    final rotulo = feito ? 'Concluído' : (eHoje ? 'Treino do dia' : 'Programado');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decCard,
      child: Stack(
        children: [
          const Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Icon(Icons.fitness_center,
                size: 150, color: Color.fromRGBO(0, 80, 230, .25)),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: kAzul,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(rotulo),
                ),
                const SizedBox(height: 10),
                Text(dia.nome, style: titulo(46), textAlign: TextAlign.center),
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
                    '${dia.itens.length} exercícios • $series séries • ~$min min • ~$kcal kcal',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kMudo)),
                const SizedBox(height: 14),
                FilledButton(
                  style: estiloPrimario,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TreinoTela(dia: dia)),
                  ),
                  child: Text(eHoje ? 'Iniciar treino' : 'Ver treino'),
                ),
              ],
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
  const TreinoTela({super.key, required this.dia});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(dia.nome, style: titulo(28))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          if (dia.foco.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(dia.foco, style: const TextStyle(color: kMudo)),
            ),
          for (var i = 0; i < dia.itens.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Vidro(
                padding: const EdgeInsets.all(14),
                raio: 22,
                onTap: () => detalheExercicio(context, dia.itens[i]),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1F4D),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('${i + 1}', style: titulo(24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.ex(dia.itens[i].exId)?.nome ?? dia.itens[i].nome,
                              style: titulo(22)),
                          Text(dia.itens[i].grupo,
                              style: const TextStyle(color: kMudo)),
                        ],
                      ),
                    ),
                    Text('${dia.itens[i].series} × ${dia.itens[i].reps}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: estiloPrimario,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RunTela(dia: dia)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Começar'),
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
          ],
        ),
      ),
    );
  }
}

// ---------- Execução do treino ----------
class RunTela extends StatefulWidget {
  final Dia dia;
  const RunTela({super.key, required this.dia});
  @override
  State<RunTela> createState() => _RunEstado();
}

class _RunEstado extends State<RunTela> {
  int ei = 0, si = 0, seg = 0, descanso = 0, feitasSeries = 0;
  bool pausado = false;
  double volume = 0;
  late Timer _t;
  final _carga = TextEditingController();
  Item get it => widget.dia.itens[ei];

  @override
  void initState() {
    super.initState();
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

  void _concluir() {
    app.setCarga(it.exId, _carga.text.trim());
    final cg = double.tryParse(_carga.text.trim().replaceAll(',', '.')) ?? 0;
    volume += cg * repsMedio(it.reps);
    feitasSeries++;
    if (si + 1 < it.series) {
      setState(() {
        si++;
        descanso = app.descanso;
      });
    } else if (ei + 1 < widget.dia.itens.length) {
      setState(() {
        ei++;
        si = 0;
        descanso = app.descanso;
        _carregar();
      });
    } else {
      _fim();
    }
  }

  Future<void> _fim({bool parcial = false}) async {
    _t.cancel();
    final total = widget.dia.itens.fold<int>(0, (s, e) => s + e.series);
    if (parcial && feitasSeries == 0) {
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    await app.addSessao(Sessao(
      data: DateTime.now().toIso8601String(),
      dia: widget.dia.nome,
      seg: seg,
      series: feitasSeries,
      seriesTotal: total,
      volume: volume,
      completo: !parcial,
    ));
    if (!parcial) await app.concluirDia(DateTime.now());
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(parcial ? 'Treino parcial salvo' : 'Treino concluído'),
        content: Text(
            'Duração: ${_fmt(seg)}\nSéries: $feitasSeries de $total\nVolume: ${volume.round()} kg'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
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
    final prox = ei + 1 < widget.dia.itens.length
        ? widget.dia.itens[ei + 1]
        : null;
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
                  if ((app.obs[it.exId] ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Obs: ${app.obs[it.exId]}',
                          style: const TextStyle(color: Colors.amberAccent)),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(
                      it.series,
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
        const SizedBox(height: 20),
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
    l.sort((a, b) => norm(a.nome).compareTo(norm(b.nome)));
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
                    itemCount: lista.length,
                    itemBuilder: (context, i) {
                      final e = lista[i];
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
                            trailing: e.custom
                                ? const Icon(Icons.edit_note, color: kMudo)
                                : null,
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

  Future<void> _trocar(Item it) async {
    final e = await Navigator.push<Exercicio>(
      context,
      MaterialPageRoute(builder: (_) => const BibliotecaTela(selecionar: true)),
    );
    if (e != null) setState(() => it.exId = e.id);
  }

  Future<void> _salvar() async {
    await app.salvarPlano(dias);
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
            Text(
              semMatch == 0
                  ? 'Tudo encontrado na biblioteca.'
                  : '$semMatch sem correspondência: toque para escolher ou salve para criar como novo.',
              style: const TextStyle(color: kMudo),
            ),
            for (final d in dias) ...[
              const SizedBox(height: 16),
              Text(d.nome, style: titulo(28)),
              if (d.foco.isNotEmpty)
                Text(d.foco, style: const TextStyle(color: kMudo)),
              const SizedBox(height: 6),
              for (final it in d.itens)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: branco(.06),
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      leading: Icon(
                        it.exId.isEmpty
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle,
                        color: it.exId.isEmpty ? Colors.amber : kAzul,
                      ),
                      title: Text(it.nome),
                      subtitle: Text(
                        it.exId.isEmpty
                            ? 'Sem correspondência'
                            : '→ ${app.ex(it.exId)?.nome ?? ''}',
                        style: const TextStyle(color: kMudo),
                      ),
                      trailing: Text('${it.series}×${it.reps}'),
                      onTap: () => _trocar(it),
                    ),
                  ),
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
