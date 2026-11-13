import 'package:flutter/material.dart';
import 'corpo.dart';
import 'desempenho.dart' show DesempenhoDetalheTela, Periodo, calcular;
import 'extras.dart' show campo, lerNum, pedirNumero, fmtNum, fmtDataIso;
import 'state.dart';
import 'telas.dart';

// ============================================================
// Evolução — peso, medidas, composição e atalho para o desempenho
// ============================================================

const _metricas = <String, List<String>>{
  'peso': ['Peso', 'kg'],
  'gordura': ['Gordura', '%'],
  'cintura': ['Cintura', 'cm'],
  'quadril': ['Quadril', 'cm'],
  'peito': ['Peito', 'cm'],
  'braco': ['Braço', 'cm'],
  'coxa': ['Coxa', 'cm'],
};

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

const _verde = Color(0xFF30D158);
const _vermelho = Color(0xFFFF453A);
const _ambar = Color(0xFFFFB020);
const _linhaCor = Color(0xFF4DA3FF);

String _d2(int n) => n.toString().padLeft(2, '0');
String _dm(DateTime d) => '${_d2(d.day)}/${_d2(d.month)}';
String _dma(DateTime d) => '${_d2(d.day)}/${_d2(d.month)}/${d.year % 100}';

class _Pt {
  final DateTime d;
  final double v;
  const _Pt(this.d, this.v);
}

List<_Pt> _serie(String k) {
  final r = <_Pt>[];
  for (final a in app.avaliacoes) {
    final v = a.v[k];
    if (v == null) continue;
    r.add(_Pt(DateTime.tryParse(a.data) ?? DateTime.now(), v));
  }
  return r;
}

double? _ultimo(String k) {
  for (final a in app.avaliacoes.reversed) {
    final v = a.v[k];
    if (v != null) return v;
  }
  return null;
}

class EvolucaoTela extends StatefulWidget {
  const EvolucaoTela({super.key});
  @override
  State<EvolucaoTela> createState() => _EvoEstado();
}

class _EvoEstado extends State<EvolucaoTela> {
  String m = 'peso';
  String per = 'tudo'; // 30 | 90 | 365 | tudo
  int? selIdx;

  Future<void> _nova() async {
    final ultimos = <String, double>{};
    for (final f in _camposAval) {
      final v = _ultimo(f[0]);
      if (v != null) ultimos[f[0]] = v;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSuperf,
      builder: (c) => _FormAvaliacao(ultimos: ultimos),
    );
  }

  Future<void> _metaPeso() async {
    final v = await pedirNumero(context, 'Meta de peso',
        sufixo: 'kg',
        inicial: app.metaPeso == null ? '' : fmtNum(app.metaPeso!));
    if (v != null && v > 0) await app.setMetaPeso(v);
  }

  List<_Pt> _filtrar(List<_Pt> s) {
    if (per == 'tudo') return s;
    final dias = per == '30' ? 30 : (per == '90' ? 90 : 365);
    final corte = DateTime.now().subtract(Duration(days: dias));
    return s.where((p) => p.d.isAfter(corte)).toList();
  }

  void _selecionar(double dx, double largura, int n) {
    if (n == 0) return;
    final w = largura - GraficoEvo.esq - GraficoEvo.dir;
    var i = 0;
    if (n > 1 && w > 0) {
      i = (((dx - GraficoEvo.esq) / w) * (n - 1)).round().clamp(0, n - 1).toInt();
    }
    if (i != selIdx) setState(() => selIdx = i);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final tem = app.avaliacoes.isNotEmpty;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text('Evolução', style: titulo(34)),
              const Text('Acompanhe seu corpo e seu treino',
                  style: TextStyle(color: kMudo)),
              const SizedBox(height: 14),
              _cartaoDesempenho(),
              const SizedBox(height: 12),
              if (!tem)
                _vazio()
              else ...[
                _hero(),
                const SizedBox(height: 12),
                _lembrete(),
                _medidasAtuais(),
                _graficoSecao(),
                _composicao(),
              ],
              const SizedBox(height: 4),
              FilledButton.icon(
                style: estiloPrimario,
                onPressed: _nova,
                icon: const Icon(Icons.add),
                label: const Text('Nova avaliação'),
              ),
              const SizedBox(height: 20),
              if (tem) Text('Histórico por data', style: titulo(26)),
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

  // ---------- Atalho para Seu desempenho ----------
  Widget _cartaoDesempenho() {
    final st = calcular(const Periodo('semana'));
    final inten = st.intensidade;
    return Vidro(
      padding: const EdgeInsets.all(16),
      raio: 24,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DesempenhoDetalheTela()),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: kAzul),
                    const SizedBox(width: 8),
                    Text('Seu desempenho', style: titulo(24)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Esta semana',
                    style: TextStyle(color: kMudo, fontSize: 13)),
                const SizedBox(height: 8),
                Text('${st.treinos} ${st.treinos == 1 ? "treino" : "treinos"} · ${st.series} séries',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${st.volume.round()} kg de volume',
                    style: const TextStyle(color: kMudo, fontSize: 13)),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Text('Ver detalhes',
                        style: TextStyle(
                            color: _linhaCor, fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right, color: _linhaCor, size: 18),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 44, child: CorpoMuscular(frente: true, intensidade: inten)),
          const SizedBox(width: 6),
          SizedBox(width: 44, child: CorpoMuscular(frente: false, intensidade: inten)),
        ],
      ),
    );
  }

  Widget _vazio() {
    return Vidro(
      child: Column(
        children: [
          const Icon(Icons.monitor_weight_outlined, size: 46, color: kAzul),
          const SizedBox(height: 10),
          Text('Comece sua evolução', style: titulo(28)),
          const SizedBox(height: 6),
          const Text(
            'Registre peso e medidas para acompanhar gráficos, meta de peso e composição corporal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMudo),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ---------- Herói: peso, meta, IMC ----------
  Widget _hero() {
    final peso = _ultimo('peso');
    final altura = _ultimo('altura');
    final sp = _serie('peso');
    final primeiro = sp.isNotEmpty ? sp.first.v : null;
    final anterior = sp.length >= 2 ? sp[sp.length - 2].v : null;
    final meta = app.metaPeso;
    final imc = (peso != null && altura != null && altura > 0)
        ? peso / ((altura / 100) * (altura / 100))
        : null;

    bool? baixarEhBom;
    if (meta != null && peso != null && (meta - peso).abs() >= 0.05) {
      baixarEhBom = meta < peso;
    }

    Widget? chipDelta;
    if (peso != null && anterior != null) {
      final d = peso - anterior;
      chipDelta = _chipDelta(d, 'kg', baixarEhBom: baixarEhBom, sufixo: ' vs anterior');
    }

    double? frac;
    String? txtMeta;
    if (meta != null && peso != null && primeiro != null) {
      final querPerder = primeiro > meta;
      final total = primeiro - meta;
      frac = total.abs() < 0.05
          ? 1.0
          : ((primeiro - peso) / total).clamp(0.0, 1.0).toDouble();
      final falta = querPerder ? peso - meta : meta - peso;
      if (falta.abs() < 0.05) {
        txtMeta = 'Meta atingida 🎉';
      } else if (falta > 0) {
        txtMeta = 'Faltam ${fmtNum(falta)} kg para a meta de ${fmtNum(meta)} kg';
      } else {
        txtMeta = 'Meta de ${fmtNum(meta)} kg superada em ${fmtNum(-falta)} kg';
      }
    }

    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(peso == null ? '—' : fmtNum(peso), style: titulo(56)),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('kg', style: TextStyle(color: kMudo, fontSize: 16)),
              ),
              const Spacer(),
              if (chipDelta != null)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: chipDelta),
            ],
          ),
          if (peso != null && primeiro != null && sp.length >= 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Desde a primeira avaliação: ${_sinal(peso - primeiro)}${fmtNum((peso - primeiro).abs())} kg',
                style: const TextStyle(color: kMudo, fontSize: 13),
              ),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _metaPeso,
            child: meta == null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kAzul, width: 1.2),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_outlined, size: 18, color: _linhaCor),
                        SizedBox(width: 8),
                        Text('Definir meta de peso',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flag_outlined, size: 16, color: _ambar),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(txtMeta ?? 'Meta: ${fmtNum(meta)} kg',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          const Text('editar',
                              style: TextStyle(color: kMudo, fontSize: 12)),
                        ],
                      ),
                      if (frac != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 10,
                            color: _ambar,
                            backgroundColor: branco(.10),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${(frac * 100).round()}% do caminho',
                            style: const TextStyle(color: kMudo, fontSize: 12)),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _miniInfo(imc == null ? '—' : imc.toStringAsFixed(1).replaceAll('.', ','), 'IMC', sub: imc == null ? null : _classeImc(imc), cor: imc == null ? null : _corImc(imc))),
              const SizedBox(width: 8),
              Expanded(child: _miniInfo(altura == null ? '—' : '${fmtNum(altura)} cm', 'altura')),
              const SizedBox(width: 8),
              Expanded(child: _miniInfo('${app.avaliacoes.length}', 'avaliações')),
            ],
          ),
          if (imc != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'IMC é só uma referência e não substitui avaliação profissional.',
                style: TextStyle(color: kMudo, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  String _sinal(double d) => d.abs() < 0.05 ? '' : (d > 0 ? '+' : '−');

  String _classeImc(double v) {
    if (v < 18.5) return 'Abaixo do peso';
    if (v < 25) return 'Peso normal';
    if (v < 30) return 'Sobrepeso';
    if (v < 35) return 'Obesidade I';
    if (v < 40) return 'Obesidade II';
    return 'Obesidade III';
  }

  Color _corImc(double v) {
    if (v < 18.5) return _linhaCor;
    if (v < 25) return _verde;
    if (v < 30) return _ambar;
    return _vermelho;
  }

  Widget _miniInfo(String v, String r, {String? sub, Color? cor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: branco(.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(v, style: titulo(24)),
          Text(r, style: const TextStyle(color: kMudo, fontSize: 11)),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: cor ?? kMudo,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _chipDelta(double d, String un, {bool? baixarEhBom, String sufixo = ''}) {
    final neutro = d.abs() < 0.05;
    Color cor = kMudo;
    if (!neutro && baixarEhBom != null) {
      cor = ((d < 0) == baixarEhBom) ? _verde : _vermelho;
    }
    final seta = neutro ? '•' : (d > 0 ? '▲' : '▼');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withOpacity(.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text('$seta ${fmtNum(d.abs())} $un$sufixo',
          style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  // ---------- Lembrete de reavaliação ----------
  Widget _lembrete() {
    if (app.avaliacoes.isEmpty) return const SizedBox.shrink();
    final ult = DateTime.tryParse(app.avaliacoes.last.data);
    if (ult == null) return const SizedBox.shrink();
    final dias = DateTime.now().difference(ult).inDays;
    if (dias < 30) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _nova,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _ambar.withOpacity(.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _ambar.withOpacity(.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.update_rounded, color: _ambar),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Faz $dias dias desde a última avaliação. Que tal atualizar suas medidas?',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const Icon(Icons.chevron_right, color: kMudo),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Medidas atuais ----------
  Widget _medidasAtuais() {
    const chaves = ['gordura', 'cintura', 'quadril', 'peito', 'braco', 'coxa'];
    const baixarBom = {'gordura': true, 'cintura': true, 'quadril': true};
    final tiles = <Widget>[];
    for (final k in chaves) {
      final s = _serie(k);
      if (s.isEmpty) continue;
      final atual = s.last.v;
      final dl = s.length >= 2 ? atual - s[s.length - 2].v : null;
      final sel = m == k;
      tiles.add(GestureDetector(
        onTap: () => setState(() {
          m = k;
          selIdx = null;
        }),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sel ? kAzul.withOpacity(.22) : branco(.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? kAzul : branco(.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_metricas[k]![0],
                  style: const TextStyle(color: kMudo, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtNum(atual), style: titulo(28)),
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(_metricas[k]![1],
                        style: const TextStyle(color: kMudo, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (dl != null)
                _miniDelta(dl, baixarBom[k])
              else
                const SizedBox(height: 16),
            ],
          ),
        ),
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    final linhas = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      linhas.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: tiles[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
          ],
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Medidas atuais', style: titulo(24)),
          const Text('Toque para ver no gráfico',
              style: TextStyle(color: kMudo, fontSize: 12)),
          const SizedBox(height: 10),
          ...linhas,
        ],
      ),
    );
  }

  Widget _miniDelta(double d, bool? baixarEhBom) {
    final neutro = d.abs() < 0.05;
    Color cor = kMudo;
    if (!neutro && baixarEhBom != null) {
      cor = ((d < 0) == baixarEhBom) ? _verde : _vermelho;
    }
    final seta = neutro ? '•' : (d > 0 ? '▲' : '▼');
    return Text('$seta ${fmtNum(d.abs())} vs anterior',
        style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700));
  }

  // ---------- Gráfico ----------
  Widget _graficoSecao() {
    final nomeM = _metricas[m]![0];
    final unM = _metricas[m]![1];
    final todos = _serie(m);
    final serie = _filtrar(todos);
    final idxSel = (selIdx != null && selIdx! < serie.length) ? selIdx : null;

    String rotPer(String id, String r) => r;
    Widget chipPer(String id, String r) {
      final s = per == id;
      return GestureDetector(
        onTap: () => setState(() {
          per = id;
          selIdx = null;
        }),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: s ? kAzul : branco(.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(rotPer(id, r),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: s ? Colors.white : kMudo)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Vidro(
        padding: const EdgeInsets.all(16),
        raio: 26,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gráfico de evolução', style: titulo(24)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final e in _metricas.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value[0]),
                        selected: m == e.key,
                        selectedColor: kAzul,
                        onSelected: (_) => setState(() {
                          m = e.key;
                          selIdx = null;
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                chipPer('30', '30 dias'),
                chipPer('90', '90 dias'),
                chipPer('365', '1 ano'),
                chipPer('tudo', 'Tudo'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: serie.isEmpty
                  ? Center(
                      child: Text(
                        todos.isEmpty
                            ? 'Sem registros de $nomeM ainda.'
                            : 'Sem registros de $nomeM neste período.',
                        style: const TextStyle(color: kMudo),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) =>
                            _selecionar(d.localPosition.dx, box.maxWidth, serie.length),
                        onHorizontalDragUpdate: (d) =>
                            _selecionar(d.localPosition.dx, box.maxWidth, serie.length),
                        child: CustomPaint(
                          size: Size(box.maxWidth, 220),
                          painter: GraficoEvo(
                            serie,
                            meta: m == 'peso' ? app.metaPeso : null,
                            sel: idxSel,
                            un: unM,
                          ),
                        ),
                      ),
                    ),
            ),
            if (serie.isNotEmpty) ...[
              const SizedBox(height: 12),
              _estatisticas(serie, unM),
            ],
          ],
        ),
      ),
    );
  }

  Widget _estatisticas(List<_Pt> s, String un) {
    var mn = s.first.v;
    var mx = s.first.v;
    for (final p in s) {
      if (p.v < mn) mn = p.v;
      if (p.v > mx) mx = p.v;
    }
    final ini = s.first.v;
    final fim = s.last.v;
    final d = fim - ini;
    final bom = (m == 'peso' && app.metaPeso != null)
        ? (app.metaPeso! < ini)
        : ((m == 'gordura' || m == 'cintura' || m == 'quadril') ? true : null);
    Color corD = kMudo;
    if (d.abs() >= 0.05 && bom != null) {
      corD = ((d < 0) == bom) ? _verde : _vermelho;
    }
    Widget col(String v, String r, {Color? cor}) => Expanded(
          child: Column(
            children: [
              Text(v,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: cor ?? Colors.white)),
              const SizedBox(height: 2),
              Text(r, style: const TextStyle(color: kMudo, fontSize: 11)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: branco(.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          col(fmtNum(ini), 'início'),
          col(fmtNum(fim), 'atual'),
          col(s.length < 2 ? '—' : '${_sinal(d)}${fmtNum(d.abs())}', 'variação', cor: corD),
          col(fmtNum(mn), 'mínimo'),
          col(fmtNum(mx), 'máximo'),
        ],
      ),
    );
  }

  // ---------- Composição e proporções ----------
  Widget _composicao() {
    final peso = _ultimo('peso');
    final g = _ultimo('gordura');
    final alt = _ultimo('altura');
    final cint = _ultimo('cintura');
    final quad = _ultimo('quadril');
    final itens = <Widget>[];

    if (peso != null && g != null && g > 0 && g < 70) {
      final gorda = peso * g / 100;
      final magra = peso - gorda;
      itens.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  Expanded(
                    flex: (magra / peso * 1000).round().clamp(1, 999).toInt(),
                    child: Container(color: kAzul),
                  ),
                  Expanded(
                    flex: (gorda / peso * 1000).round().clamp(1, 999).toInt(),
                    child: Container(color: const Color(0xFFFF3D8B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legenda(kAzul, 'Massa magra ${fmtNum(magra)} kg'),
              const SizedBox(width: 16),
              _legenda(const Color(0xFFFF3D8B), 'Massa gorda ${fmtNum(gorda)} kg'),
            ],
          ),
        ],
      ));
    }
    if (cint != null && quad != null && quad > 0) {
      itens.add(_linhaProp('Relação cintura/quadril',
          (cint / quad).toStringAsFixed(2).replaceAll('.', ',')));
    }
    if (cint != null && alt != null && alt > 0) {
      itens.add(_linhaProp('Relação cintura/altura',
          (cint / alt).toStringAsFixed(2).replaceAll('.', ','),
          obs: 'Valores abaixo de 0,50 costumam ser citados como referência.'));
    }
    if (itens.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Vidro(
        padding: const EdgeInsets.all(18),
        raio: 26,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Composição e proporções', style: titulo(24)),
            const Text(
              'Estimativas a partir das suas medidas; não substituem avaliação profissional.',
              style: TextStyle(color: kMudo, fontSize: 12),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < itens.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == itens.length - 1 ? 0 : 14),
                child: itens[i],
              ),
          ],
        ),
      ),
    );
  }

  Widget _legenda(Color c, String t) => Expanded(
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );

  Widget _linhaProp(String r, String v, {String? obs}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(r, style: const TextStyle(color: kMudo))),
            Text(v, style: titulo(24)),
          ],
        ),
        if (obs != null)
          Text(obs, style: const TextStyle(color: kMudo, fontSize: 11)),
      ],
    );
  }

  // ---------- Histórico ----------
  Widget _cartaoAval(int i) {
    final a = app.avaliacoes[i];
    final ant = i > 0 ? app.avaliacoes[i - 1] : null;
    final ehUltima = i == app.avaliacoes.length - 1;
    const baixarBom = {'gordura': true, 'cintura': true, 'quadril': true};
    final pills = <Widget>[];

    void add(String k, String nome, String un) {
      final v = a.v[k];
      if (v == null) return;
      final p = ant?.v[k];
      Widget? delta;
      if (p != null && k != 'altura') {
        final d = v - p;
        if (d.abs() >= 0.05) {
          Color cor = kMudo;
          final bom = baixarBom[k];
          if (bom != null) cor = ((d < 0) == bom) ? _verde : _vermelho;
          delta = Text(' ${d > 0 ? "▲" : "▼"}${fmtNum(d.abs())}',
              style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700));
        }
      }
      pills.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: branco(.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$nome ', style: const TextStyle(color: kMudo, fontSize: 12)),
            Text('${fmtNum(v)} $un',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (delta != null) delta,
          ],
        ),
      ));
    }

    add('altura', 'Altura', 'cm');
    for (final e in _metricas.entries) {
      add(e.key, e.value[0], e.value[1]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(fmtDataIso(a.data),
                  style: const TextStyle(color: kMudo)),
            ),
            if (ehUltima)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kAzul.withOpacity(.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('mais recente',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: pills),
      ],
    );
  }
}

// ============================================================
// Gráfico de linha suave com área, meta e seleção por toque
// ============================================================
class GraficoEvo extends CustomPainter {
  static const double esq = 44.0;
  static const double dir = 14.0;
  static const double topo = 22.0;
  static const double base = 26.0;

  final List<_Pt> pts;
  final double? meta;
  final int? sel;
  final String un;
  GraficoEvo(this.pts, {this.meta, this.sel, required this.un});

  void _texto(Canvas c, String t, Offset o,
      {Color cor = const Color(0xFFA1A1A6),
      double tam = 11,
      bool centro = false,
      bool direita = false,
      bool forte = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
            color: cor,
            fontSize: tam,
            fontWeight: forte ? FontWeight.w700 : FontWeight.w400),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var x = o.dx;
    if (centro) x -= tp.width / 2;
    if (direita) x -= tp.width;
    tp.paint(c, Offset(x, o.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;
    final todos = <double>[for (final p in pts) p.v];
    if (meta != null) todos.add(meta!);
    var mn = todos.first;
    var mx = todos.first;
    for (final v in todos) {
      if (v < mn) mn = v;
      if (v > mx) mx = v;
    }
    if (mx - mn < 0.5) {
      mx += 1;
      mn -= 1;
    }
    final pad = (mx - mn) * 0.18;
    mn -= pad;
    mx += pad;

    final w = size.width - esq - dir;
    final h = size.height - topo - base;
    double yDe(double v) => topo + h - (v - mn) / (mx - mn) * h;
    double xDe(int i) =>
        pts.length == 1 ? esq + w / 2 : esq + i * w / (pts.length - 1);

    // grade
    final grade = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, .08)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final v = mn + (mx - mn) * i / 3;
      final y = yDe(v);
      canvas.drawLine(Offset(esq, y), Offset(esq + w, y), grade);
      _texto(canvas, fmtNum(double.parse(v.toStringAsFixed(1))), Offset(esq - 8, y),
          direita: true);
    }

    // meta tracejada
    if (meta != null) {
      final y = yDe(meta!);
      final tr = Paint()
        ..color = _ambar.withOpacity(.85)
        ..strokeWidth = 1.5;
      var x = esq;
      while (x < esq + w) {
        final fim = (x + 6) > esq + w ? esq + w : x + 6;
        canvas.drawLine(Offset(x, y), Offset(fim, y), tr);
        x += 10;
      }
      _texto(canvas, 'meta', Offset(esq + w, y - 8), cor: _ambar, direita: true, tam: 10);
    }

    // linha suave + área
    final linha = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = Offset(xDe(i), yDe(pts[i].v));
      if (i == 0) {
        linha.moveTo(o.dx, o.dy);
      } else {
        final a = Offset(xDe(i - 1), yDe(pts[i - 1].v));
        final mxm = (a.dx + o.dx) / 2;
        linha.cubicTo(mxm, a.dy, mxm, o.dy, o.dx, o.dy);
      }
    }
    if (pts.length >= 2) {
      final area = Path()..addPath(linha, Offset.zero);
      area.lineTo(xDe(pts.length - 1), topo + h);
      area.lineTo(xDe(0), topo + h);
      area.close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_linhaCor.withOpacity(.40), _linhaCor.withOpacity(0)],
          ).createShader(Rect.fromLTWH(esq, topo, w, h)),
      );
      canvas.drawPath(
        linha,
        Paint()
          ..color = _linhaCor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // pontos
    for (var i = 0; i < pts.length; i++) {
      final o = Offset(xDe(i), yDe(pts[i].v));
      canvas.drawCircle(o, 4, Paint()..color = Colors.white);
      canvas.drawCircle(
        o,
        4,
        Paint()
          ..color = _linhaCor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // datas no eixo X
    final idxs = <int>{0, pts.length - 1};
    if (pts.length >= 3) idxs.add(pts.length ~/ 2);
    for (final i in idxs) {
      _texto(canvas, _dm(pts[i].d), Offset(xDe(i), topo + h + 14),
          centro: true, tam: 10);
    }

    // seleção
    if (sel != null && sel! < pts.length) {
      final i = sel!;
      final o = Offset(xDe(i), yDe(pts[i].v));
      canvas.drawLine(
        Offset(o.dx, topo),
        Offset(o.dx, topo + h),
        Paint()
          ..color = const Color.fromRGBO(255, 255, 255, .25)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(o, 7, Paint()..color = _linhaCor);
      canvas.drawCircle(o, 3.5, Paint()..color = Colors.white);

      final t1 = '${fmtNum(pts[i].v)} $un';
      final t2 = _dma(pts[i].d);
      final tp1 = TextPainter(
        text: TextSpan(
            text: t1,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      final tp2 = TextPainter(
        text: TextSpan(
            text: t2,
            style: const TextStyle(color: Color(0xFFA1A1A6), fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      final bw = (tp1.width > tp2.width ? tp1.width : tp2.width) + 20;
      const bh = 42.0;
      var bx = o.dx - bw / 2;
      if (bx < 2) bx = 2;
      if (bx + bw > size.width - 2) bx = size.width - 2 - bw;
      var by = o.dy - bh - 12;
      if (by < 0) by = o.dy + 12;
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(10));
      canvas.drawRRect(r, Paint()..color = const Color(0xFF2A2A2E));
      canvas.drawRRect(
        r,
        Paint()
          ..color = const Color.fromRGBO(255, 255, 255, .18)
          ..style = PaintingStyle.stroke,
      );
      tp1.paint(canvas, Offset(bx + (bw - tp1.width) / 2, by + 6));
      tp2.paint(canvas, Offset(bx + (bw - tp2.width) / 2, by + 24));
    }
  }

  @override
  bool shouldRepaint(covariant GraficoEvo old) => true;
}

// ============================================================
// Formulário de avaliação
// ============================================================
class _FormAvaliacao extends StatefulWidget {
  final Map<String, double> ultimos;
  const _FormAvaliacao({required this.ultimos});
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
              'Todos os campos são opcionais. Os dados ficam só neste celular. O valor em cinza é o último registrado.',
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: campo(f[1], sufixo: f[2]).copyWith(
                        hintText: widget.ultimos[f[0]] == null
                            ? null
                            : fmtNum(widget.ultimos[f[0]]!),
                      ),
                    ),
                  ),
              ],
            ),
            if (erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(erro!, style: const TextStyle(color: Colors.redAccent)),
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
