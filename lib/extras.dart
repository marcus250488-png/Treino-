import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'state.dart';
import 'telas.dart';

// ---------- Utilidades ----------
String _d2(int n) => n.toString().padLeft(2, '0');

String fmtTempo(int s) {
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final x = s % 60;
  return h > 0 ? '$h:${_d2(m)}:${_d2(x)}' : '${_d2(m)}:${_d2(x)}';
}

String fmtDataIso(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_d2(d.day)}/${_d2(d.month)}/${d.year} ${_d2(d.hour)}:${_d2(d.minute)}';
}

String fmtNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

double? lerNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

InputDecoration campo(String rotulo, {String? sufixo}) => InputDecoration(
      labelText: rotulo,
      suffixText: sufixo,
      filled: true,
      fillColor: branco(.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

Widget _resumo(String valor, String rotulo) => Column(
      children: [
        Text(valor, style: titulo(30)),
        Text(rotulo, style: const TextStyle(color: kMudo, fontSize: 12)),
      ],
    );

Future<double?> pedirNumero(BuildContext context, String rotulo,
    {String sufixo = '', String inicial = ''}) {
  return showDialog<double?>(
    context: context,
    builder: (c) =>
        _DialogoNumero(rotulo: rotulo, sufixo: sufixo, inicial: inicial),
  );
}

class _DialogoNumero extends StatefulWidget {
  final String rotulo, sufixo, inicial;
  const _DialogoNumero(
      {required this.rotulo, required this.sufixo, required this.inicial});
  @override
  State<_DialogoNumero> createState() => _DialogoNumeroEstado();
}

class _DialogoNumeroEstado extends State<_DialogoNumero> {
  late final TextEditingController _c;
  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.inicial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rotulo),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: campo(widget.rotulo, sufixo: widget.sufixo),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(context, lerNum(_c.text)),
            child: const Text('Salvar')),
      ],
    );
  }
}

// ---------- Histórico de treinos ----------
class HistoricoTela extends StatelessWidget {
  const HistoricoTela({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Histórico', style: titulo(28))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final l = app.sessoes.reversed.toList();
          if (l.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum treino registrado ainda. Conclua um treino para ele aparecer aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMudo),
                ),
              ),
            );
          }
          final tempo = l.fold<int>(0, (s, e) => s + e.seg);
          final vol = l.fold<double>(0, (s, e) => s + e.volume);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Vidro(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _resumo('${l.length}', 'treinos'),
                    _resumo(fmtTempo(tempo), 'tempo total'),
                    _resumo('${vol.round()}', 'kg de volume'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final s in l)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Vidro(
                    padding: const EdgeInsets.all(14),
                    raio: 22,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.dia, style: titulo(24)),
                              Text(fmtDataIso(s.data),
                                  style: const TextStyle(color: kMudo)),
                              const SizedBox(height: 4),
                              Text(
                                  '${s.series} de ${s.seriesTotal} séries • ${fmtTempo(s.seg)} • ${s.volume.round()} kg',
                                  style: const TextStyle(color: kMudo)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: s.completo
                                ? kAzul
                                : const Color.fromRGBO(255, 193, 7, .25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(s.completo ? 'Completo' : 'Parcial',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ],
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

// ---------- Evolução (avaliação física + gráfico) ----------
const _metricas = <String, List<String>>{
  'peso': ['Peso', 'kg'],
  'gordura': ['Gordura', '%'],
  'cintura': ['Cintura', 'cm'],
  'quadril': ['Quadril', 'cm'],
  'peito': ['Peito', 'cm'],
  'braco': ['Braço', 'cm'],
  'coxa': ['Coxa', 'cm'],
};

class EvolucaoTela extends StatefulWidget {
  const EvolucaoTela({super.key});
  @override
  State<EvolucaoTela> createState() => _EvoEstado();
}

class _EvoEstado extends State<EvolucaoTela> {
  String m = 'peso';

  double? _ultimo(String k) {
    for (final a in app.avaliacoes.reversed) {
      if (a.v.containsKey(k)) return a.v[k];
    }
    return null;
  }

  Future<void> _nova() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSuperf,
      builder: (c) => const _FormAvaliacao(),
    );
  }

  Future<void> _metaPeso() async {
    final v = await pedirNumero(context, 'Meta de peso',
        sufixo: 'kg',
        inicial: app.metaPeso == null ? '' : fmtNum(app.metaPeso!));
    if (v != null && v > 0) await app.setMetaPeso(v);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final peso = _ultimo('peso');
        final altura = _ultimo('altura');
        final imc = (peso != null && altura != null && altura > 0)
            ? peso / ((altura / 100) * (altura / 100))
            : null;
        final ys = app.avaliacoes
            .where((a) => a.v.containsKey(m))
            .map((a) => a.v[m]!)
            .toList();
        final nomeM = _metricas[m]![0];
        final unM = _metricas[m]![1];
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text('Evolução', style: titulo(34)),
              const SizedBox(height: 12),
              Vidro(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _resumo(peso == null ? '—' : fmtNum(peso), 'peso (kg)'),
                    _resumo(imc == null ? '—' : imc.toStringAsFixed(1), 'IMC'),
                    GestureDetector(
                      onTap: _metaPeso,
                      child: _resumo(
                          app.metaPeso == null ? '—' : fmtNum(app.metaPeso!),
                          'meta (toque p/ editar)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in _metricas.entries)
                    ChoiceChip(
                      label: Text(e.value[0]),
                      selected: m == e.key,
                      selectedColor: kAzul,
                      onSelected: (_) => setState(() => m = e.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Vidro(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  height: 190,
                  child: ys.isEmpty
                      ? Center(
                          child: Text('Sem registros de $nomeM ainda.',
                              style: const TextStyle(color: kMudo)))
                      : CustomPaint(
                          size: Size.infinite,
                          painter: GraficoLinha(ys,
                              meta: m == 'peso' ? app.metaPeso : null),
                        ),
                ),
              ),
              if (ys.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      '$nomeM: ${ys.length} registro(s) • último ${fmtNum(ys.last)} $unM',
                      style: const TextStyle(color: kMudo)),
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: estiloPrimario,
                onPressed: _nova,
                icon: const Icon(Icons.add),
                label: const Text('Nova avaliação'),
              ),
              const SizedBox(height: 18),
              if (app.avaliacoes.isNotEmpty)
                Text('Histórico por data', style: titulo(26)),
              const SizedBox(height: 8),
              for (var i = app.avaliacoes.length - 1; i >= 0; i--)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Vidro(
                    padding: const EdgeInsets.all(14),
                    raio: 22,
                    child: _cartaoAval(i),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _cartaoAval(int i) {
    final a = app.avaliacoes[i];
    final ant = i > 0 ? app.avaliacoes[i - 1] : null;
    final linhas = <Widget>[];
    void add(String k, String nome, String un) {
      final v = a.v[k];
      if (v == null) return;
      var t = '$nome: ${fmtNum(v)} $un';
      final p = ant?.v[k];
      if (p != null && k != 'altura') {
        final d = v - p;
        if (d.abs() >= 0.05) t += '  (${d > 0 ? '+' : '−'}${fmtNum(d.abs())})';
      }
      linhas.add(Text(t, style: const TextStyle(fontSize: 14)));
    }

    add('altura', 'Altura', 'cm');
    for (final e in _metricas.entries) {
      add(e.key, e.value[0], e.value[1]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fmtDataIso(a.data), style: const TextStyle(color: kMudo)),
        const SizedBox(height: 6),
        ...linhas,
      ],
    );
  }
}

const _camposAval = [
  ['altura', 'Altura', 'cm'],
  ['peso', 'Peso', 'kg'],
  ['gordura', 'Gordura corporal', '%'],
  ['cintura', 'Cintura', 'cm'],
  ['quadril', 'Quadril', 'cm'],
  ['peito', 'Peito', 'cm'],
  ['braco', 'Braço', 'cm'],
  ['coxa', 'Coxa', 'cm'],
];

class _FormAvaliacao extends StatefulWidget {
  const _FormAvaliacao();
  @override
  State<_FormAvaliacao> createState() => _FormAvaliacaoEstado();
}

class _FormAvaliacaoEstado extends State<_FormAvaliacao> {
  final Map<String, TextEditingController> _c = {
    for (final f in _camposAval) f[0]: TextEditingController(),
  };
  String? erro;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    final v = <String, double>{};
    _c.forEach((k, ctl) {
      final n = lerNum(ctl.text);
      if (n != null && n > 0) v[k] = n;
    });
    if (v.isEmpty) {
      setState(() => erro = 'Preencha pelo menos uma medida.');
      return;
    }
    await app.addAvaliacao(v);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final larg = (MediaQuery.of(context).size.width - 20 * 2 - 12) / 2;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nova avaliação', style: titulo(30)),
            const SizedBox(height: 4),
            const Text(
              'Todos os campos são opcionais. Os dados ficam só neste celular.',
              style: TextStyle(color: kMudo),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final f in _camposAval)
                  SizedBox(
                    width: larg,
                    child: TextField(
                      controller: _c[f[0]],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: campo(f[1], sufixo: f[2]),
                    ),
                  ),
              ],
            ),
            if (erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(erro!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              style: estiloPrimario,
              onPressed: _salvar,
              child: const Text('Salvar avaliação'),
            ),
          ],
        ),
      ),
    );
  }
}

class GraficoLinha extends CustomPainter {
  final List<double> ys;
  final double? meta;
  GraficoLinha(this.ys, {this.meta});

  @override
  void paint(Canvas canvas, Size size) {
    if (ys.isEmpty) return;
    final todos = <double>[...ys, if (meta != null) meta!];
    var mn = todos.reduce((a, b) => a < b ? a : b);
    var mx = todos.reduce((a, b) => a > b ? a : b);
    if (mx - mn < 0.5) {
      mx += 1;
      mn -= 1;
    }
    final pad = (mx - mn) * 0.15;
    mn -= pad;
    mx += pad;
    const esq = 44.0, dir = 12.0, topo = 12.0, base = 12.0;
    final w = size.width - esq - dir;
    final h = size.height - topo - base;
    double yDe(double v) => topo + h - (v - mn) / (mx - mn) * h;
    double xDe(int i) =>
        ys.length == 1 ? esq + w / 2 : esq + i * w / (ys.length - 1);

    final grade = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, .1)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final v = mn + (mx - mn) * i / 2;
      final y = yDe(v);
      canvas.drawLine(Offset(esq, y), Offset(esq + w, y), grade);
      final tp = TextPainter(
        text: TextSpan(
            text: v.toStringAsFixed(1),
            style: const TextStyle(color: Color(0xFFA1A1A6), fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    if (meta != null) {
      final y = yDe(meta!);
      canvas.drawLine(
          Offset(esq, y),
          Offset(esq + w, y),
          Paint()
            ..color = const Color.fromRGBO(255, 193, 7, .8)
            ..strokeWidth = 1.5);
    }
    final linha = Paint()
      ..color = const Color(0xFF0050E6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < ys.length; i++) {
      final o = Offset(xDe(i), yDe(ys[i]));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, linha);
    final ponto = Paint()..color = Colors.white;
    for (var i = 0; i < ys.length; i++) {
      canvas.drawCircle(Offset(xDe(i), yDe(ys[i])), 4, ponto);
    }
  }

  @override
  bool shouldRepaint(covariant GraficoLinha old) => true;
}

// ---------- Hábitos (água) ----------
class HabitosTela extends StatelessWidget {
  const HabitosTela({super.key});

  Future<void> _outro(BuildContext context) async {
    final v = await pedirNumero(context, 'Quantidade de água', sufixo: 'ml');
    if (v != null && v > 0) await app.addAgua(DateTime.now(), v.round());
  }

  Future<void> _meta(BuildContext context) async {
    final v = await pedirNumero(context, 'Meta diária de água',
        sufixo: 'ml', inicial: '${app.metaAgua}');
    if (v != null && v >= 500) await app.setMetaAgua(v.round());
  }

  @override
  Widget build(BuildContext context) {
    const letras = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final hoje = DateTime.now();
        final ml = app.agua[chaveData(hoje)] ?? 0;
        final p = (ml / app.metaAgua).clamp(0.0, 1.0).toDouble();
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text('Hábitos', style: titulo(34)),
              const SizedBox(height: 12),
              Vidro(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Água de hoje', style: titulo(26)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _meta(context),
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text('meta ${app.metaAgua} ml'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 170,
                            height: 170,
                            child: CircularProgressIndicator(
                              value: p,
                              strokeWidth: 12,
                              color: kAzul,
                              backgroundColor: branco(.1),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$ml ml', style: titulo(40)),
                              Text('${(p * 100).round()}% da meta',
                                  style: const TextStyle(color: kMudo)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final v in [150, 250, 500]) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: estiloContorno,
                              onPressed: () => app.addAgua(hoje, v),
                              child: Text('+$v'),
                            ),
                          ),
                          if (v != 500) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: estiloContorno,
                            onPressed: () => _outro(context),
                            child: const Text('Outro valor'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: estiloContorno,
                            onPressed: () => app.addAgua(hoje, -250),
                            child: const Text('−250 (corrigir)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Vidro(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Últimos 7 dias', style: titulo(26)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (var i = 6; i >= 0; i--)
                            _barra(hoje.subtract(Duration(days: i)), letras),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _barra(DateTime d, List<String> letras) {
    final ml = app.agua[chaveData(d)] ?? 0;
    final f = (ml / app.metaAgua).clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: 4 + 80 * f,
          decoration: BoxDecoration(
            color: ml >= app.metaAgua ? kAzul : branco(.3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 6),
        Text(letras[d.weekday % 7],
            style: const TextStyle(color: kMudo, fontSize: 12)),
      ],
    );
  }
}

// ---------- Mais ----------
class MaisTela extends StatelessWidget {
  final void Function(int) irPara;
  const MaisTela({super.key, required this.irPara});

  Widget _item(IconData i, String t, String sub, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: branco(.06),
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: Icon(i, color: kAzul),
          title: Text(t),
          subtitle: Text(sub, style: const TextStyle(color: kMudo)),
          trailing: const Icon(Icons.chevron_right, color: kMudo),
          onTap: onTap,
        ),
      ),
    );
  }

  void _abrir(BuildContext context, Widget w) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Future<void> _sair(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sair da conta Google?'),
        content: const Text('Seus treinos e registros continuam no celular.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sair')),
        ],
      ),
    );
    if (ok == true) await app.sair();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text('Mais', style: titulo(34)),
              const SizedBox(height: 12),
              _item(Icons.history, 'Histórico de treinos',
                  '${app.sessoes.length} treino(s) registrado(s)',
                  () => _abrir(context, const HistoricoTela())),
              _item(Icons.picture_as_pdf_outlined, 'Importar treino (PDF)',
                  'Atualize sua ficha de treino',
                  () => abrirImportar(context, irPara)),
              _item(Icons.tune, 'Configurações', 'Descanso entre séries',
                  () => _abrir(context, const ConfigTela())),
              _item(Icons.privacy_tip_outlined, 'Privacidade e dados',
                  'O que fica salvo e exportação',
                  () => _abrir(context, const PrivacidadeTela())),
              if (app.logado)
                _item(Icons.logout, 'Sair da conta Google', app.email ?? '',
                    () => _sair(context))
              else
                _item(Icons.login, 'Entrar com Google',
                    'Mostrar sua foto e seu nome', () async {
                  final msg = ScaffoldMessenger.of(context);
                  final e = await app.entrar();
                  if (e != null) msg.showSnackBar(SnackBar(content: Text(e)));
                }),
            ],
          ),
        );
      },
    );
  }
}

class ConfigTela extends StatelessWidget {
  const ConfigTela({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configurações', style: titulo(28))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Vidro(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Descanso entre séries', style: titulo(26)),
                  const SizedBox(height: 4),
                  Text('${app.descanso} segundos',
                      style: const TextStyle(color: kMudo)),
                  Slider(
                    min: 30,
                    max: 180,
                    divisions: 10,
                    value: app.descanso.toDouble().clamp(30.0, 180.0),
                    onChanged: (v) => app.setDescanso(v.round()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacidadeTela extends StatelessWidget {
  const PrivacidadeTela({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Privacidade e dados', style: titulo(28))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Vidro(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('O que fica salvo',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Seu treino importado, histórico de treinos, avaliações físicas, água, cargas e anotações ficam somente neste celular. Nada é enviado para servidores.',
                  style: TextStyle(color: kMudo),
                ),
                SizedBox(height: 14),
                Text('Conta Google',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Usada só para mostrar seu nome, e-mail e foto no app. O login é opcional.',
                  style: TextStyle(color: kMudo),
                ),
                SizedBox(height: 14),
                Text('Dados de saúde',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Peso e medidas são opcionais e servem só para acompanhar sua evolução. O app não faz diagnóstico médico.',
                  style: TextStyle(color: kMudo),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: estiloPrimario,
            onPressed: () async {
              final msg = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: app.exportar()));
              msg.showSnackBar(const SnackBar(
                  content: Text(
                      'Dados copiados (JSON). Cole em um app de notas para guardar.')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Exportar meus dados'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Meu Plano de Treino (detalhes)
// ============================================================
class MeuPlanoTela extends StatelessWidget {
  const MeuPlanoTela({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final totalTreinos = app.sessoes.where((s) => s.completo).length;
        final totalPlano = app.plano.isEmpty ? 5 * 5 : app.plano.length * 5; // 5 semanas
        final pct = totalPlano == 0 ? 0.0 : (totalTreinos / totalPlano).clamp(0.0, 1.0);
        final diasAtivos = app.feitos.length;
        final frequencia = app.plano.length;

        // Semana atual aproximada (1-based)
        final inicio = DateTime.now().subtract(Duration(days: DateTime.now().weekday % 7));
        // ranking simples de semanas
        final semanas = List.generate(5, (i) {
          final feitosSemana = app.feitos.where((k) {
            final d = DateTime.tryParse(k);
            if (d == null) return false;
            final semanaDoAno = (d.difference(DateTime(d.year)).inDays / 7).floor();
            final atual = (DateTime.now().difference(DateTime(DateTime.now().year)).inDays / 7).floor();
            return semanaDoAno == atual - (4 - i);
          }).length;
          return feitosSemana;
        });

        return Scaffold(
          appBar: AppBar(
            title: Text('Meu plano', style: titulo(28)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // Boas-vindas
              Vidro(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.primeiroNome.isEmpty
                          ? 'Bem-vindo ao seu plano de treino!'
                          : 'Bem-vindo ao seu plano de treino, ${app.primeiroNome}!',
                      style: titulo(26),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Você irá visualizar todas as informações sobre seu programa. Ele terá duração total de 30 dias e foi criado para ajudar você a alcançar seu objetivo principal.',
                      style: TextStyle(color: kMudo, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _infoChip(Icons.fitness_center, '$frequencia Treinos', 'Por semana')),
                        const SizedBox(width: 10),
                        Expanded(child: _infoChip(Icons.location_on_outlined, 'Academia', 'Local')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _infoChip(Icons.timer_outlined, '5 Semanas', 'Duração')),
                        const SizedBox(width: 10),
                        Expanded(child: _infoChip(Icons.trending_up, 'Iniciante', 'Nível')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: estiloContorno,
                      onPressed: () {
                        // abre importar / editar
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Use a aba Mais > Importar treino (PDF) para editar o plano.')),
                        );
                      },
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Editar meu plano de treino'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Jornada
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0050E6), Color(0xFF1A6CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sua jornada de 5 semanas',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Colors.white)),
                          SizedBox(height: 6),
                          Text(
                            'É aqui onde tudo começa! Você visualizará quais dias têm treinos, dias de descanso e quantos treinos já foram realizados.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('🚀', style: TextStyle(fontSize: 42)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Progresso geral
              Vidro(
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 90,
                                height: 90,
                                child: CircularProgressIndicator(
                                  value: pct,
                                  strokeWidth: 9,
                                  color: kAzul,
                                  backgroundColor: branco(.12),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${(pct * 100).round()}%', style: titulo(22)),
                                  const Text('Concluído',
                                      style: TextStyle(color: kMudo, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Treinos realizados', style: titulo(20)),
                              Text('$totalTreinos de $totalPlano',
                                  style: const TextStyle(color: kMudo)),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  color: kAzul,
                                  backgroundColor: branco(.12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _miniStat('Frequência', '${frequencia}x sem'),
                                  _miniStat('Dias ativos', '$diasAtivos'),
                                  _miniStat('Recorde', '${diasAtivos > 0 ? diasAtivos : 0} dias'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Semanas
              Text('Sua jornada', style: titulo(26)),
              const SizedBox(height: 12),
              for (var s = 1; s <= 5; s++) ...[
                _semanaCard(context, s, s == 1, semanas[s - 1].clamp(0, 5)),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: branco(.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: kAzul, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(sub, style: const TextStyle(color: kMudo, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(label, style: const TextStyle(color: kMudo, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _semanaCard(BuildContext context, int num, bool atual, int feitos) {
    final total = app.plano.isEmpty ? 5 : app.plano.length;
    return Material(
      color: branco(.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (atual) {
            // mostra treino do dia se houver
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: atual ? kAzul : branco(.12), width: atual ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: atual ? kAzul : branco(.12),
                  border: Border.all(color: kAzul, width: 2),
                ),
                child: Text('$num',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: atual ? Colors.white : kAzul)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Semana $num', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        if (atual) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: kAzul,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Em andamento',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('$feitos/$total treinos realizados',
                        style: const TextStyle(color: kMudo, fontSize: 13)),
                  ],
                ),
              ),
              Icon(
                feitos >= total ? Icons.check_circle : Icons.circle_outlined,
                color: feitos >= total ? kAzul : kMudo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Seu desempenho / Intensidade muscular
// ============================================================
class DesempenhoTela extends StatefulWidget {
  const DesempenhoTela({super.key});
  @override
  State<DesempenhoTela> createState() => _DesempenhoEstado();
}

class _DesempenhoEstado extends State<DesempenhoTela> {
  String aba = 'musculos'; // musculos | volume

  Map<String, int> _contarGrupos() {
    final contagem = <String, int>{};
    // Conta a partir das sessões + itens do plano dos dias feitos
    for (final s in app.sessoes) {
      if (!s.completo) continue;
      // tenta achar o dia do plano pelo nome
      Dia? dia;
      for (final d in app.plano) {
        if (d.nome.toLowerCase().contains(s.dia.toLowerCase().split('-').first)) {
          dia = d;
          break;
        }
      }
      if (dia != null) {
        for (final it in dia.itens) {
          final g = it.grupo.isEmpty ? 'Outros' : it.grupo;
          contagem[g] = (contagem[g] ?? 0) + 1;
        }
      }
    }
    // fallback: se não tiver sessões, usa o plano atual
    if (contagem.isEmpty && app.plano.isNotEmpty) {
      for (final d in app.plano) {
        for (final it in d.itens) {
          final g = it.grupo.isEmpty ? 'Outros' : it.grupo;
          contagem[g] = (contagem[g] ?? 0) + 1;
        }
      }
    }
    return contagem;
  }

  @override
  Widget build(BuildContext context) {
    final contagem = _contarGrupos();
    final ranking = contagem.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: Text('Meu treino', style: titulo(28)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // botão treino livre
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: kAzul, width: 1.5),
                shape: const StadiumBorder(),
              ),
              onPressed: () {},
              child: const Text('Conhecer o treino livre'),
            ),
          ),
          const SizedBox(height: 16),

          // Card principal desempenho
          Vidro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: kAzul),
                    const SizedBox(width: 8),
                    Text('Seu desempenho', style: titulo(24)),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: kMudo),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Semana · ${_semanaAtual()}',
                  style: const TextStyle(color: kMudo, fontSize: 13),
                ),
                const Text(
                  'Veja quais grupos musculares você mais trabalhou.',
                  style: TextStyle(color: kMudo, fontSize: 13),
                ),
                const SizedBox(height: 14),
                // Abas
                Row(
                  children: [
                    _abaBtn('Músculos', 'musculos'),
                    const SizedBox(width: 8),
                    _abaBtn('Volume', 'volume'),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.calendar_today_outlined, size: 20, color: kMudo),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Visual simples dos músculos (frente / costas)
                if (aba == 'musculos') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _corpoSilhueta(true, ranking.take(4).map((e) => e.key).toList()),
                      _corpoSilhueta(false, ranking.take(4).map((e) => e.key).toList()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Frente  ·  Costas',
                        style: TextStyle(color: kMudo, fontSize: 12)),
                  ),
                ] else ...[
                  // volume simples
                  if (ranking.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('Sem dados de volume ainda.', style: TextStyle(color: kMudo))),
                    )
                  else
                    ...ranking.take(6).map((e) {
                      final maxV = ranking.first.value.toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                                Text('${e.value}x', style: const TextStyle(color: kMudo)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: e.value / maxV,
                                minHeight: 8,
                                color: kAzul,
                                backgroundColor: branco(.1),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],

                const SizedBox(height: 18),
                // Ranking com troféus
                if (ranking.isNotEmpty) ...[
                  for (var i = 0; i < ranking.length && i < 8; i++)
                    _rankingItem(i + 1, ranking[i].key, ranking[i].value),
                ] else
                  const Text('Complete treinos para ver o ranking de músculos.',
                      style: TextStyle(color: kMudo)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botão detalhes
          Material(
            color: branco(.07),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DetalhesIntensidadeTela(ranking: ranking),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, color: kAzul),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Detalhes da intensidade muscular',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right, color: kMudo),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _abaBtn(String label, String id) {
    final sel = aba == id;
    return GestureDetector(
      onTap: () => setState(() => aba = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? kAzul : branco(.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : kMudo)),
      ),
    );
  }

  Widget _corpoSilhueta(bool frente, List<String> top) {
    // Representação simples com ícones de músculos destacados
    final destaque = top.isNotEmpty;
    return Column(
      children: [
        Container(
          width: 110,
          height: 180,
          decoration: BoxDecoration(
            color: branco(.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: branco(.12)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.accessibility_new,
                  size: 70, color: destaque ? kAzul : kMudo),
              const SizedBox(height: 8),
              Text(frente ? 'Frente' : 'Costas',
                  style: const TextStyle(color: kMudo, fontSize: 12)),
              if (destaque && top.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    top.take(2).join('\n'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: kAzul, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rankingItem(int pos, String nome, int vezes) {
    Widget medal;
    if (pos == 1) {
      medal = const Text('🥇', style: TextStyle(fontSize: 22));
    } else if (pos == 2) {
      medal = const Text('🥈', style: TextStyle(fontSize: 22));
    } else if (pos == 3) {
      medal = const Text('🥉', style: TextStyle(fontSize: 22));
    } else {
      medal = Text('$pos', style: const TextStyle(color: kMudo, fontWeight: FontWeight.w700));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 32, child: Center(child: medal)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          Text('$vezes ${vezes == 1 ? "vez" : "vezes"}',
              style: const TextStyle(color: kMudo)),
        ],
      ),
    );
  }

  String _semanaAtual() {
    final agora = DateTime.now();
    final inicio = agora.subtract(Duration(days: agora.weekday % 7));
    final fim = inicio.add(const Duration(days: 6));
    return '${inicio.day.toString().padLeft(2, "0")}/${inicio.month.toString().padLeft(2, "0")} a ${fim.day.toString().padLeft(2, "0")}/${fim.month.toString().padLeft(2, "0")}';
  }
}

class DetalhesIntensidadeTela extends StatelessWidget {
  final List<MapEntry<String, int>> ranking;
  const DetalhesIntensidadeTela({super.key, required this.ranking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhes da intensidade muscular', style: titulo(22)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ranking.isEmpty
          ? const Center(
              child: Text('Complete treinos para ver a intensidade.',
                  style: TextStyle(color: kMudo)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ranking.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = ranking[i];
                final pos = i + 1;
                Widget medal;
                if (pos == 1) {
                  medal = const Text('🥇', style: TextStyle(fontSize: 26));
                } else if (pos == 2) {
                  medal = const Text('🥈', style: TextStyle(fontSize: 26));
                } else if (pos == 3) {
                  medal = const Text('🥉', style: TextStyle(fontSize: 26));
                } else {
                  medal = Text('$posº',
                      style: const TextStyle(color: kMudo, fontWeight: FontWeight.w700));
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: branco(.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: branco(.1)),
                  ),
                  child: Row(
                    children: [
                      // ícone genérico de músculo
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: branco(.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.accessibility_new, color: kAzul),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(e.key,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                      medal,
                      const SizedBox(width: 10),
                      Text('${e.value} ${e.value == 1 ? "vez" : "vezes"}',
                          style: const TextStyle(color: kMudo)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
