import 'package:flutter/material.dart';
import 'corpo.dart';
import 'extras.dart' show fmtTempo, fmtNum, fmtDataIso;
import 'state.dart';
import 'telas.dart';

// ============================================================
// Seu desempenho — dados, resumo semanal e tela completa
// ============================================================

const _abrevDia = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
const _nomeDiaSemana = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];
const _nomeMes = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const _verde = Color(0xFF30D158);
const _vermelho = Color(0xFFFF453A);

String _d2(int n) => n.toString().padLeft(2, '0');
String _abrevMes(int m) => _nomeMes[(m - 1) % 12].substring(0, 3);
String _dataCurta(DateTime d) => '${_d2(d.day)}/${_d2(d.month)}';
DateTime _dia(DateTime d) => DateTime.utc(d.year, d.month, d.day);

String _milhar(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String _abrevNum(double v) =>
    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : fmtNum(v);

// ---------- Período ----------
class Periodo {
  final String tipo; // semana | mes | tri | tudo
  final int off; // 0 = atual, -1 = anterior...
  const Periodo(this.tipo, [this.off = 0]);

  static DateTime get _hoje {
    final h = DateTime.now();
    return DateTime(h.year, h.month, h.day);
  }

  DateTime get ini {
    final h = _hoje;
    switch (tipo) {
      case 'semana':
        return DateTime(h.year, h.month, h.day - h.weekday % 7 + 7 * off);
      case 'mes':
        return DateTime(h.year, h.month + off, 1);
      case 'tri':
        return DateTime(h.year, h.month - 2 + 3 * off, 1);
      default:
        return DateTime(2000);
    }
  }

  DateTime get fim {
    final i = ini;
    switch (tipo) {
      case 'semana':
        return DateTime(i.year, i.month, i.day + 7);
      case 'mes':
        return DateTime(i.year, i.month + 1, 1);
      case 'tri':
        return DateTime(i.year, i.month + 3, 1);
      default:
        return DateTime(2100);
    }
  }

  Periodo get anterior => Periodo(tipo, off - 1);
  bool get comparavel => tipo != 'tudo';

  String get rotulo {
    final i = ini;
    switch (tipo) {
      case 'semana':
        final f = DateTime(i.year, i.month, i.day + 6);
        return '${_dataCurta(i)} a ${_dataCurta(f)}';
      case 'mes':
        return '${_nomeMes[i.month - 1]} ${i.year}';
      case 'tri':
        final l = DateTime(i.year, i.month + 2, 1);
        return '${_abrevMes(i.month)} – ${_abrevMes(l.month)} ${l.year}';
      default:
        return 'Todo o período';
    }
  }
}

// ---------- Estatísticas ----------
DateTime? dataSessao(Sessao s) => DateTime.tryParse(s.data);

Dia? diaDaSessao(Sessao s) {
  final alvo = norm(s.dia);
  for (final d in app.plano) {
    if (norm(d.nome) == alvo) return d;
  }
  final p = alvo.split(' ').first;
  for (final d in app.plano) {
    if (norm(d.nome).startsWith(p)) return d;
  }
  return null;
}

class Stats {
  int treinos = 0;
  int completos = 0;
  int series = 0;
  int seriesTotal = 0;
  int seg = 0;
  double volume = 0;
  final Set<DateTime> dias = {};
  final Map<String, double> musculos = {};
  final Map<String, double> grupos = {};
  final List<Sessao> lista = [];

  Map<String, double> get intensidade {
    var mx = 0.0;
    for (final v in musculos.values) {
      if (v > mx) mx = v;
    }
    if (mx <= 0) return {};
    return {for (final e in musculos.entries) e.key: e.value / mx};
  }

  double get totalSeriesMusculos {
    var t = 0.0;
    for (final v in musculos.values) {
      t += v;
    }
    return t;
  }
}

Stats calcular(Periodo p) {
  final st = Stats();
  final ini = p.ini;
  final fim = p.fim;
  for (final s in app.sessoes) {
    if (s.cardio) continue;
    final dt = dataSessao(s);
    if (dt == null) continue;
    if (dt.isBefore(ini) || !dt.isBefore(fim)) continue;
    st.treinos += 1;
    if (s.completo) st.completos += 1;
    st.series += s.series;
    st.seriesTotal += s.seriesTotal;
    st.seg += s.seg;
    st.volume += s.volume;
    st.dias.add(_dia(dt));
    st.lista.add(s);
    final dia = diaDaSessao(s);
    if (dia != null) {
      final ratio = s.seriesTotal > 0
          ? (s.series / s.seriesTotal).clamp(0.0, 1.0).toDouble()
          : 1.0;
      for (final it in dia.itens) {
        final w = it.series * ratio;
        st.grupos[it.grupo] = (st.grupos[it.grupo] ?? 0) + w;
        for (final id in musculosDoGrupo(it.grupo)) {
          st.musculos[id] = (st.musculos[id] ?? 0) + w;
        }
      }
    }
  }
  return st;
}

class Recordes {
  Sessao? maiorVolume;
  Sessao? maisLonga;
  int maiorSeq = 0;
  int seqAtual = 0;
  int total = 0;
  int? diaFavorito;
}

Recordes calcularRecordes() {
  final r = Recordes();
  final dias = <DateTime>{};
  final porDia = List<int>.filled(7, 0);
  for (final s in app.sessoes) {
    if (s.cardio) continue;
    final dt = dataSessao(s);
    if (dt == null) continue;
    r.total += 1;
    if (r.maiorVolume == null || s.volume > r.maiorVolume!.volume) {
      r.maiorVolume = s;
    }
    if (r.maisLonga == null || s.seg > r.maisLonga!.seg) {
      r.maisLonga = s;
    }
    dias.add(_dia(dt));
    porDia[dt.weekday % 7] += 1;
  }
  final ord = dias.toList()..sort();
  var seq = 0;
  DateTime? ant;
  for (final d in ord) {
    if (ant != null && d.difference(ant).inDays == 1) {
      seq += 1;
    } else {
      seq = 1;
    }
    if (seq > r.maiorSeq) r.maiorSeq = seq;
    ant = d;
  }
  final hoje = _dia(DateTime.now());
  var cursor =
      dias.contains(hoje) ? hoje : hoje.subtract(const Duration(days: 1));
  var atual = 0;
  while (dias.contains(cursor)) {
    atual += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  r.seqAtual = atual;
  if (r.total >= 3) {
    var melhorDia = 0;
    for (var i = 1; i < 7; i++) {
      if (porDia[i] > porDia[melhorDia]) melhorDia = i;
    }
    r.diaFavorito = melhorDia;
  }
  return r;
}

List<MapEntry<String, double>> _barras(
    Periodo p, List<Sessao> lista, String metrica) {
  double valor(Sessao s) {
    if (metrica == 'volume') return s.volume;
    if (metrica == 'series') return s.series.toDouble();
    return s.seg / 60.0;
  }

  var n = 0;
  var rot = <String>[];
  int Function(DateTime) idx = (d) => 0;
  final h = DateTime.now();
  switch (p.tipo) {
    case 'semana':
      n = 7;
      rot = _abrevDia;
      idx = (d) => d.weekday % 7;
      break;
    case 'mes':
      n = 5;
      rot = ['S1', 'S2', 'S3', 'S4', 'S5'];
      idx = (d) => (d.day - 1) ~/ 7;
      break;
    case 'tri':
      n = 3;
      final iTri = p.ini;
      rot = [
        for (var k = 0; k < 3; k++)
          _abrevMes(DateTime(iTri.year, iTri.month + k, 1).month)
      ];
      idx = (d) => (d.year - iTri.year) * 12 + d.month - iTri.month;
      break;
    default:
      n = 6;
      final iTudo = DateTime(h.year, h.month - 5, 1);
      rot = [
        for (var k = 0; k < 6; k++)
          _abrevMes(DateTime(iTudo.year, iTudo.month + k, 1).month)
      ];
      idx = (d) => (d.year - iTudo.year) * 12 + d.month - iTudo.month;
  }
  final vals = List<double>.filled(n, 0);
  for (final s in lista) {
    final d = dataSessao(s);
    if (d == null) continue;
    final k = idx(d);
    if (k >= 0 && k < n) vals[k] += valor(s);
  }
  return [for (var k = 0; k < n; k++) MapEntry(rot[k], vals[k])];
}

// ---------- Componentes reutilizáveis ----------
Widget seletorPeriodo(String tipo, ValueChanged<String> aoMudar) {
  const opcoes = [
    ['semana', 'Semana'],
    ['mes', 'Mês'],
    ['tri', '3 meses'],
    ['tudo', 'Tudo'],
  ];
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final o in opcoes)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => aoMudar(o[0]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: tipo == o[0] ? kAzul : branco(.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(o[1],
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: tipo == o[0] ? Colors.white : kMudo)),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget legendaCalor() {
  return Column(
    children: [
      Container(
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(colors: [
            corIntensidade(0),
            corIntensidade(.5),
            corIntensidade(1),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Menos estímulo', style: TextStyle(color: kMudo, fontSize: 11)),
          Text('Mais estímulo', style: TextStyle(color: kMudo, fontSize: 11)),
        ],
      ),
    ],
  );
}

Widget _corpoCard(bool frente, Map<String, double> inten,
    {String? destaque, ValueChanged<String>? aoTocar}) {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: branco(.045),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: branco(.10)),
        ),
        child: CorpoMuscular(
          frente: frente,
          intensidade: inten,
          destaque: destaque,
          aoTocar: aoTocar,
        ),
      ),
      const SizedBox(height: 7),
      Text(frente ? 'FRENTE' : 'COSTAS',
          style: const TextStyle(
              color: kMudo,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    ],
  );
}

Widget _medalha(int pos, {double tam = 22}) {
  if (pos == 1) return Text('🥇', style: TextStyle(fontSize: tam));
  if (pos == 2) return Text('🥈', style: TextStyle(fontSize: tam));
  if (pos == 3) return Text('🥉', style: TextStyle(fontSize: tam));
  return Text('$pos', style: const TextStyle(color: kMudo, fontWeight: FontWeight.w700));
}

Widget _secao(String tit, Widget child, {String? sub, Widget? direita}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Vidro(
      padding: const EdgeInsets.all(18),
      raio: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(tit, style: titulo(24))),
              if (direita != null) direita,
            ],
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub, style: const TextStyle(color: kMudo, fontSize: 13)),
            ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

double? _pct(num atual, num ant) => ant == 0 ? null : (atual - ant) / ant * 100;

Widget _delta(double? pct) {
  if (pct == null) return const SizedBox(height: 16);
  final neutro = pct.abs() < 0.5;
  final sobe = pct >= 0;
  final cor = neutro ? kMudo : (sobe ? _verde : _vermelho);
  final seta = neutro ? '•' : (sobe ? '▲' : '▼');
  return Text('$seta ${pct.abs().round()}%',
      style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700));
}

Widget _kpi(IconData ic, String valor, String rot, double? pct) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: branco(.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: branco(.08)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(ic, size: 18, color: kAzul),
          const Spacer(),
          _delta(pct),
        ]),
        const SizedBox(height: 10),
        Text(valor, style: titulo(30)),
        Text(rot, style: const TextStyle(color: kMudo, fontSize: 12)),
      ],
    ),
  );
}

Widget _linha2(Widget a, Widget b) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      ),
    );

Widget _grafBarras(List<MapEntry<String, double>> b) {
  var mx = 0.0;
  for (final e in b) {
    if (e.value > mx) mx = e.value;
  }
  const alt = 120.0;
  return SizedBox(
    height: alt + 44,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final e in b)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(e.value > 0 ? _abrevNum(e.value) : '',
                    style: const TextStyle(color: kMudo, fontSize: 10)),
                const SizedBox(height: 4),
                Container(
                  width: 20,
                  height: mx == 0
                      ? 4.0
                      : (e.value / mx * alt).clamp(4.0, alt).toDouble(),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: e.value > 0
                          ? [const Color(0xFF4DA3FF), kAzul]
                          : [branco(.10), branco(.10)],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(e.key, style: const TextStyle(color: kMudo, fontSize: 11)),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _chipMetrica(String id, String rot, String atual, ValueChanged<String> f) {
  final sel = atual == id;
  return GestureDetector(
    onTap: () => f(id),
    child: Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sel ? kAzul : branco(.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(rot,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: sel ? Colors.white : kMudo)),
    ),
  );
}

Widget _barraHoriz(double frac, Color cor) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: LinearProgressIndicator(
      value: frac.clamp(0.0, 1.0).toDouble(),
      minHeight: 8,
      color: cor,
      backgroundColor: branco(.10),
    ),
  );
}

String _nivel(double v) {
  if (v <= 0) return 'Sem estímulo';
  if (v < .34) return 'Leve';
  if (v < .67) return 'Moderado';
  return 'Alto';
}

// ============================================================
// Resumo (tela "Meu treino" > Seu desempenho)
// ============================================================
class DesempenhoTela extends StatefulWidget {
  const DesempenhoTela({super.key});
  @override
  State<DesempenhoTela> createState() => _DesempenhoEstado();
}

class _DesempenhoEstado extends State<DesempenhoTela> {
  String aba = 'musculos'; // musculos | volume
  String? sel;

  void _abrirCompleto([String tipo = 'semana']) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DesempenhoDetalheTela(tipoInicial: tipo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        const p = Periodo('semana');
        final st = calcular(p);
        final inten = st.intensidade;
        final ranking = st.grupos.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return Scaffold(
          appBar: AppBar(
            title: Text('Meu treino', style: titulo(28)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                  icon: const Icon(Icons.notifications_none), onPressed: () {}),
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Vidro(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _abrirCompleto,
                      child: Row(
                        children: [
                          const Icon(Icons.bar_chart_rounded, color: kAzul),
                          const SizedBox(width: 8),
                          Text('Seu desempenho', style: titulo(24)),
                          const Spacer(),
                          const Text('Ver tudo',
                              style: TextStyle(color: kMudo, fontSize: 13)),
                          const Icon(Icons.chevron_right, color: kMudo),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Semana · ${p.rotulo}',
                        style: const TextStyle(color: kMudo, fontSize: 13)),
                    const Text(
                      'Veja quais grupos musculares você mais trabalhou.',
                      style: TextStyle(color: kMudo, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _abaBtn('Músculos', 'musculos'),
                        const SizedBox(width: 8),
                        _abaBtn('Volume', 'volume'),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 20, color: kMudo),
                          onPressed: () => _abrirCompleto('mes'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _miniKpi('${st.treinos}', 'treinos')),
                        const SizedBox(width: 8),
                        Expanded(child: _miniKpi('${st.series}', 'séries')),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _miniKpi(_milhar(st.volume), 'kg volume')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (aba == 'musculos') ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _corpoCard(true, inten,
                                destaque: sel,
                                aoTocar: (id) => setState(() => sel = id)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _corpoCard(false, inten,
                                destaque: sel,
                                aoTocar: (id) => setState(() => sel = id)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (sel != null)
                        Center(
                          child: Text(
                            '${rotulosMusculo[sel] ?? sel}: ${fmtNum(st.musculos[sel] ?? 0)} séries na semana',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                      else
                        const Center(
                          child: Text('Toque em um músculo para ver detalhes',
                              style: TextStyle(color: kMudo, fontSize: 12)),
                        ),
                      const SizedBox(height: 10),
                      legendaCalor(),
                    ] else ...[
                      _grafBarras(_barras(p, st.lista, 'volume')),
                      const Center(
                        child: Text('Volume por dia (kg)',
                            style: TextStyle(color: kMudo, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 18),
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
              _botao(Icons.emoji_events_outlined, 'Detalhes da intensidade muscular',
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DetalhesIntensidadeTela()),
                );
              }),
              const SizedBox(height: 10),
              _botao(Icons.insights_rounded, 'Desempenho completo', _abrirCompleto),
            ],
          ),
        );
      },
    );
  }

  Widget _botao(IconData ic, String txt, VoidCallback f) {
    return Material(
      color: branco(.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: f,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(ic, color: kAzul),
              const SizedBox(width: 12),
              Expanded(
                child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right, color: kMudo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniKpi(String v, String r) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: branco(.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(v, style: titulo(24)),
          Text(r, style: const TextStyle(color: kMudo, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _abaBtn(String label, String id) {
    final s = aba == id;
    return GestureDetector(
      onTap: () => setState(() => aba = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: s ? kAzul : branco(.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: s ? Colors.white : kMudo)),
      ),
    );
  }

  Widget _rankingItem(int pos, String nome, double series) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 32, child: Center(child: _medalha(pos))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(nome,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          Text('${fmtNum(series)} séries', style: const TextStyle(color: kMudo)),
        ],
      ),
    );
  }
}

// ============================================================
// Intensidade muscular (detalhe por músculo)
// ============================================================
class DetalhesIntensidadeTela extends StatefulWidget {
  const DetalhesIntensidadeTela({super.key});
  @override
  State<DetalhesIntensidadeTela> createState() => _DetInt();
}

class _DetInt extends State<DetalhesIntensidadeTela> {
  String tipo = 'semana';

  @override
  Widget build(BuildContext context) {
    final p = Periodo(tipo);
    final st = calcular(p);
    final inten = st.intensidade;
    final ids = rotulosMusculo.keys.toList()
      ..sort((a, b) => (st.musculos[b] ?? 0).compareTo(st.musculos[a] ?? 0));
    return Scaffold(
      appBar: AppBar(
        title: Text('Intensidade muscular', style: titulo(26)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          seletorPeriodo(tipo, (t) => setState(() => tipo = t)),
          const SizedBox(height: 6),
          Text(p.rotulo, style: const TextStyle(color: kMudo)),
          const SizedBox(height: 14),
          Vidro(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _corpoCard(true, inten)),
                    const SizedBox(width: 12),
                    Expanded(child: _corpoCard(false, inten)),
                  ],
                ),
                const SizedBox(height: 14),
                legendaCalor(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (st.musculos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('Complete treinos para ver a intensidade.',
                    style: TextStyle(color: kMudo)),
              ),
            )
          else
            for (final id in ids)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _linhaMusculo(id, st, inten[id] ?? 0),
              ),
        ],
      ),
    );
  }

  Widget _linhaMusculo(String id, Stats st, double v) {
    final cor = v > 0 ? corIntensidade(v) : branco(.25);
    final series = st.musculos[id] ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: branco(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: branco(.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(rotulosMusculo[id] ?? id,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Text(_nivel(v), style: TextStyle(color: cor, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          _barraHoriz(v, cor),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${fmtNum(series)} séries',
                style: const TextStyle(color: kMudo, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Desempenho completo
// ============================================================
class DesempenhoDetalheTela extends StatefulWidget {
  final String tipoInicial;
  const DesempenhoDetalheTela({super.key, this.tipoInicial = 'semana'});
  @override
  State<DesempenhoDetalheTela> createState() => _DetEstado();
}

class _DetEstado extends State<DesempenhoDetalheTela> {
  late String tipo = widget.tipoInicial;
  int off = 0;
  String metrica = 'volume'; // volume | series | tempo
  String? sel;

  Periodo get p => Periodo(tipo, off);

  void _mudarTipo(String t) => setState(() {
        tipo = t;
        off = 0;
        sel = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seu desempenho', style: titulo(28)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final st = calcular(p);
          final ant = p.comparavel ? calcular(p.anterior) : null;
          final rec = calcularRecordes();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              seletorPeriodo(tipo, _mudarTipo),
              const SizedBox(height: 8),
              _navegacao(),
              const SizedBox(height: 6),
              _secaoKpis(st, ant),
              _secaoCorpo(st),
              _secaoBarras(st),
              _secaoGrupos(st),
              _secaoEquilibrio(st),
              _secaoNegligenciados(st),
              _secaoRecordes(rec),
              _secaoCalendario(),
              _secaoAgua(),
              _secaoRecentes(st),
            ],
          );
        },
      ),
    );
  }

  Widget _navegacao() {
    final podeNavegar = p.comparavel;
    return Row(
      children: [
        IconButton(
          onPressed: podeNavegar ? () => setState(() => off -= 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(p.rotulo, style: titulo(26)),
              if (off == 0 && podeNavegar)
                const Text('período atual',
                    style: TextStyle(color: kMudo, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          onPressed: podeNavegar && off < 0 ? () => setState(() => off += 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  // ---- KPIs ----
  Widget _secaoKpis(Stats st, Stats? ant) {
    double? cmp(num Function(Stats) f) =>
        ant == null ? null : _pct(f(st), f(ant));
    String consist() {
      if (!p.comparavel || app.plano.isEmpty) return '${st.dias.length}';
      final sem = p.fim.difference(p.ini).inDays / 7;
      final meta = (app.plano.length * sem).round();
      return '${st.dias.length}/$meta';
    }

    int mediaDe(Stats x) => x.treinos == 0 ? 0 : (x.seg / x.treinos).round();
    final media = mediaDe(st);
    final conclusao =
        st.seriesTotal == 0 ? 0 : (st.series / st.seriesTotal * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        children: [
          _linha2(
            _kpi(Icons.fitness_center, '${st.treinos}', 'treinos',
                cmp((x) => x.treinos)),
            _kpi(Icons.layers_rounded, '${st.series}', 'séries feitas',
                cmp((x) => x.series)),
          ),
          _linha2(
            _kpi(Icons.scale_rounded, _milhar(st.volume), 'kg de volume',
                cmp((x) => x.volume)),
            _kpi(Icons.timer_outlined, fmtTempo(st.seg), 'tempo total',
                cmp((x) => x.seg)),
          ),
          _linha2(
            _kpi(Icons.event_available_rounded, consist(), 'dias treinados',
                cmp((x) => x.dias.length)),
            _kpi(Icons.av_timer_rounded, media == 0 ? '—' : fmtTempo(media),
                'duração média', cmp(mediaDe)),
          ),
          if (st.seriesTotal > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Vidro(
                padding: const EdgeInsets.all(16),
                raio: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Conclusão das séries planejadas',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text('$conclusao%', style: titulo(24)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _barraHoriz(conclusao / 100, kAzul),
                    const SizedBox(height: 4),
                    Text(
                      '${st.completos} de ${st.treinos} treinos concluídos por inteiro',
                      style: const TextStyle(color: kMudo, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Mapa muscular ----
  Widget _secaoCorpo(Stats st) {
    final inten = st.intensidade;
    return _secao(
      'Mapa muscular',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _corpoCard(true, inten,
                    destaque: sel, aoTocar: (id) => setState(() => sel = id)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _corpoCard(false, inten,
                    destaque: sel, aoTocar: (id) => setState(() => sel = id)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          legendaCalor(),
          const SizedBox(height: 12),
          if (sel != null)
            _detalheMusculo(sel!, st)
          else
            Text(
              st.musculos.isEmpty
                  ? 'Complete treinos neste período para colorir o mapa.'
                  : 'Toque em um músculo para ver séries e exercícios.',
              style: const TextStyle(color: kMudo, fontSize: 13),
            ),
        ],
      ),
      sub: 'Cores baseadas nas séries feitas em cada músculo.',
    );
  }

  Widget _detalheMusculo(String id, Stats st) {
    final v = st.musculos[id] ?? 0;
    final total = st.totalSeriesMusculos;
    final share = total <= 0 ? 0 : (v / total * 100).round();
    final exs = <String>{};
    for (final d in app.plano) {
      for (final it in d.itens) {
        if (musculosDoGrupo(it.grupo).contains(id)) exs.add(it.nome);
      }
    }
    final lista = exs.take(5).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: branco(.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: branco(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(rotulosMusculo[id] ?? id, style: titulo(24)),
              ),
              GestureDetector(
                onTap: () => setState(() => sel = null),
                child: const Icon(Icons.close, size: 18, color: kMudo),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${fmtNum(v)} séries · $share% do estímulo · ${_nivel(st.intensidade[id] ?? 0)}',
              style: const TextStyle(color: kMudo, fontSize: 13)),
          if (lista.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('No seu plano: ${lista.join(', ')}',
                style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  // ---- Barras ----
  Widget _secaoBarras(Stats st) {
    final b = _barras(p, st.lista, metrica);
    final un = metrica == 'volume' ? 'kg' : (metrica == 'series' ? 'séries' : 'min');
    final sub = tipo == 'tudo'
        ? 'Últimos 6 meses ($un)'
        : (tipo == 'semana' ? 'Por dia ($un)' : (tipo == 'mes' ? 'Por semana do mês ($un)' : 'Por mês ($un)'));
    return _secao(
      'Evolução da carga',
      _grafBarras(b),
      sub: sub,
      direita: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chipMetrica('volume', 'Volume', metrica, (m) => setState(() => metrica = m)),
          _chipMetrica('series', 'Séries', metrica, (m) => setState(() => metrica = m)),
          _chipMetrica('tempo', 'Tempo', metrica, (m) => setState(() => metrica = m)),
        ],
      ),
    );
  }

  // ---- Ranking por grupo ----
  Widget _secaoGrupos(Stats st) {
    final r = st.grupos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (r.isEmpty) {
      return _secao('Séries por grupo muscular',
          const Text('Sem dados neste período.', style: TextStyle(color: kMudo)));
    }
    var total = 0.0;
    for (final e in r) {
      total += e.value;
    }
    final mx = r.first.value;
    return _secao(
      'Séries por grupo muscular',
      Column(
        children: [
          for (var i = 0; i < r.length && i < 8; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 30, child: Center(child: _medalha(i + 1, tam: 20))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r[i].key,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        '${fmtNum(r[i].value)} · ${(r[i].value / total * 100).round()}%',
                        style: const TextStyle(color: kMudo, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _barraHoriz(mx == 0 ? 0.0 : r[i].value / mx, corIntensidade(mx == 0 ? 0.0 : r[i].value / mx)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- Equilíbrio ----
  Widget _secaoEquilibrio(Stats st) {
    const cats = <String, List<String>>{
      'Empurrar': ['peito', 'ombro', 'triceps'],
      'Puxar': ['dorsal', 'trapezio', 'biceps', 'antebraco'],
      'Pernas': ['quadriceps', 'posterior', 'gluteo', 'panturrilha'],
      'Core': ['abdomen', 'obliquos', 'lombar'],
    };
    const cores = <String, Color>{
      'Empurrar': Color(0xFF2E8BFF),
      'Puxar': Color(0xFF8A5CFF),
      'Pernas': Color(0xFFFF3D8B),
      'Core': Color(0xFFFFB020),
    };
    final soma = <String, double>{};
    var total = 0.0;
    cats.forEach((k, ids) {
      var s = 0.0;
      for (final id in ids) {
        s += st.musculos[id] ?? 0;
      }
      soma[k] = s;
      total += s;
    });
    if (total <= 0) {
      return _secao('Equilíbrio do treino',
          const Text('Sem dados neste período.', style: TextStyle(color: kMudo)));
    }
    final push = soma['Empurrar'] ?? 0;
    final pull = soma['Puxar'] ?? 0;
    final pernas = soma['Pernas'] ?? 0;
    final dicas = <String>[];
    if (push > 0 && pull > 0) {
      final r = pull / push;
      if (r < .6) dicas.add('Você empurra bem mais do que puxa. Costas e bíceps podem ganhar mais séries.');
      if (r > 1.7) dicas.add('Você puxa bem mais do que empurra. Peito, ombro e tríceps podem ganhar mais séries.');
    } else if (push > 0 && pull == 0) {
      dicas.add('Nenhuma série de puxar neste período.');
    } else if (pull > 0 && push == 0) {
      dicas.add('Nenhuma série de empurrar neste período.');
    }
    if (pernas / total < .2) {
      dicas.add('Pernas representam menos de 20% do seu estímulo.');
    }
    return _secao(
      'Equilíbrio do treino',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  for (final e in soma.entries)
                    if (e.value > 0)
                      Expanded(
                        flex: (e.value / total * 1000).round().clamp(1, 1000).toInt(),
                        child: Container(color: cores[e.key]),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final e in soma.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: cores[e.key], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('${e.key} ${(e.value / total * 100).round()}%',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
            ],
          ),
          for (final d in dicas)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFFFB020)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(d, style: const TextStyle(color: kMudo, fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
      sub: 'Distribuição das séries por tipo de movimento.',
    );
  }

  // ---- Músculos sem estímulo ----
  Widget _secaoNegligenciados(Stats st) {
    if (st.treinos == 0) return const SizedBox.shrink();
    final sem = [
      for (final id in rotulosMusculo.keys)
        if ((st.musculos[id] ?? 0) <= 0) id,
    ];
    if (sem.isEmpty) {
      return _secao(
        'Músculos sem estímulo',
        const Row(
          children: [
            Icon(Icons.check_circle, color: _verde),
            SizedBox(width: 8),
            Expanded(child: Text('Todos os grupos receberam estímulo neste período.')),
          ],
        ),
      );
    }
    return _secao(
      'Músculos sem estímulo',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in sem)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: branco(.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: branco(.12)),
              ),
              child: Text(rotulosMusculo[id] ?? id, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
      sub: 'Nenhuma série registrada neste período.',
    );
  }

  // ---- Recordes ----
  Widget _secaoRecordes(Recordes r) {
    Widget linha(IconData ic, String rot, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Icon(ic, size: 20, color: kAzul),
              const SizedBox(width: 12),
              Expanded(child: Text(rot, style: const TextStyle(color: kMudo))),
              Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        );
    String dataDe(Sessao? s) {
      if (s == null) return '';
      final d = dataSessao(s);
      return d == null ? '' : ' (${_dataCurta(d)})';
    }

    if (r.total == 0) {
      return _secao('Recordes e sequências',
          const Text('Conclua um treino para começar a registrar recordes.',
              style: TextStyle(color: kMudo)));
    }
    return _secao(
      'Recordes e sequências',
      Column(
        children: [
          linha(Icons.local_fire_department_rounded, 'Sequência atual',
              '${r.seqAtual} ${r.seqAtual == 1 ? "dia" : "dias"}'),
          linha(Icons.emoji_events_outlined, 'Maior sequência',
              '${r.maiorSeq} ${r.maiorSeq == 1 ? "dia" : "dias"}'),
          if (r.maiorVolume != null)
            linha(Icons.scale_rounded, 'Maior volume em um treino',
                '${_milhar(r.maiorVolume!.volume)} kg${dataDe(r.maiorVolume)}'),
          if (r.maisLonga != null)
            linha(Icons.timer_outlined, 'Treino mais longo',
                '${fmtTempo(r.maisLonga!.seg)}${dataDe(r.maisLonga)}'),
          if (r.diaFavorito != null)
            linha(Icons.calendar_today_outlined, 'Dia em que mais treina',
                _nomeDiaSemana[r.diaFavorito!]),
          linha(Icons.fitness_center, 'Treinos registrados', '${r.total}'),
        ],
      ),
    );
  }

  // ---- Calendário de consistência ----
  Widget _secaoCalendario() {
    final h = DateTime.now();
    final hoje = DateTime(h.year, h.month, h.day);
    final domAtual = DateTime(hoje.year, hoje.month, hoje.day - hoje.weekday % 7);
    final inicio = DateTime(domAtual.year, domAtual.month, domAtual.day - 7 * 11);
    final cont = <DateTime, int>{};
    for (final s in app.sessoes) {
      final d = dataSessao(s);
      if (d == null) continue;
      final k = _dia(d);
      cont[k] = (cont[k] ?? 0) + 1;
    }
    Widget cel(DateTime d) {
      final futuro = d.isAfter(hoje);
      final n = cont[_dia(d)] ?? 0;
      final cor = futuro
          ? Colors.transparent
          : (n == 0 ? branco(.07) : (n == 1 ? kAzul.withOpacity(.65) : kAzul));
      final ehHoje = d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: cor,
            borderRadius: BorderRadius.circular(5),
            border: ehHoje ? Border.all(color: Colors.white, width: 1.2) : null,
          ),
        ),
      );
    }

    return _secao(
      'Consistência',
      Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < 12; c++)
                Expanded(
                  child: Column(
                    children: [
                      for (var r = 0; r < 7; r++)
                        cel(DateTime(inicio.year, inicio.month, inicio.day + 7 * c + r)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12 semanas atrás', style: TextStyle(color: kMudo, fontSize: 11)),
              Text('Hoje', style: TextStyle(color: kMudo, fontSize: 11)),
            ],
          ),
        ],
      ),
      sub: 'Cada quadrado é um dia. Mais azul, mais treinos.',
    );
  }

  // ---- Água ----
  Widget _secaoAgua() {
    final h = DateTime.now();
    final hoje = DateTime(h.year, h.month, h.day);
    var ini = p.ini;
    var fim = p.fim.subtract(const Duration(days: 1));
    if (tipo == 'tudo') {
      ini = DateTime(hoje.year, hoje.month, hoje.day - 29);
    }
    if (fim.isAfter(hoje)) fim = hoje;
    var dias = 0;
    var soma = 0;
    var batidas = 0;
    var d = DateTime(ini.year, ini.month, ini.day);
    while (!d.isAfter(fim)) {
      final ml = app.agua[chaveData(d)] ?? 0;
      dias += 1;
      soma += ml;
      if (ml >= app.metaAgua) batidas += 1;
      d = DateTime(d.year, d.month, d.day + 1);
    }
    if (dias == 0 || soma == 0) return const SizedBox.shrink();
    final media = (soma / dias).round();
    return _secao(
      'Hidratação',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_milhar(media)} ml', style: titulo(34)),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('por dia (média)', style: TextStyle(color: kMudo)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _barraHoriz(media / app.metaAgua, const Color(0xFF2E8BFF)),
          const SizedBox(height: 6),
          Text('Meta de ${_milhar(app.metaAgua)} ml batida em $batidas de $dias dias',
              style: const TextStyle(color: kMudo, fontSize: 13)),
        ],
      ),
      sub: tipo == 'tudo' ? 'Últimos 30 dias' : null,
    );
  }

  // ---- Treinos recentes ----
  Widget _secaoRecentes(Stats st) {
    final l = st.lista.reversed.take(8).toList();
    if (l.isEmpty) {
      return _secao('Treinos do período',
          const Text('Nenhum treino neste período.', style: TextStyle(color: kMudo)));
    }
    return _secao(
      'Treinos do período',
      Column(
        children: [
          for (final s in l)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: branco(.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (s.completo ? _verde : const Color(0xFFFFB020)).withOpacity(.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      s.completo ? Icons.check_rounded : Icons.timelapse_rounded,
                      size: 20,
                      color: s.completo ? _verde : const Color(0xFFFFB020),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.dia, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(fmtDataIso(s.data),
                            style: const TextStyle(color: kMudo, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          s.cardio
                              ? 'Cardio'
                              : '${s.series}/${s.seriesTotal} séries',
                          style: const TextStyle(fontSize: 13)),
                      Text(
                          s.cardio
                              ? s.resumoCardio
                              : '${fmtTempo(s.seg)} · ${_milhar(s.volume)} kg',
                          style: const TextStyle(color: kMudo, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
