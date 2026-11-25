import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'state.dart';
import 'telas.dart';

class _Mod {
  final String nome;
  final IconData icone;
  final double met; // gasto de energia (MET) em intensidade moderada
  const _Mod(this.nome, this.icone, this.met);
}

const _mods = <_Mod>[
  _Mod('Esteira', Icons.directions_run, 8.3),
  _Mod('Caminhada', Icons.directions_walk, 3.8),
  _Mod('Bicicleta', Icons.directions_bike, 7.0),
  _Mod('Elíptico', Icons.all_inclusive, 5.0),
  _Mod('Escada', Icons.stairs, 8.8),
  _Mod('Pular corda', Icons.sports_gymnastics, 11.8),
  _Mod('Remo', Icons.rowing, 7.0),
  _Mod('Natação', Icons.pool, 6.0),
];

const _intensNomes = ['Leve', 'Moderada', 'Intensa'];
const _intensMult = [0.8, 1.0, 1.25];
const _metas = <int?>[15, 20, 30, 45, 60, null];

class CardioTela extends StatefulWidget {
  final DateTime? dia; // dia em que o cardio será registrado (padrão: hoje)
  const CardioTela({super.key, this.dia});
  @override
  State<CardioTela> createState() => _CardioEstado();
}

class _CardioEstado extends State<CardioTela> {
  int _mod = 0, _int = 1;
  int? _meta = 30;
  int _acumMs = 0;
  DateTime? _ini;
  bool _rodando = false;
  bool _metaAvisada = false;
  Timer? _t;
  final _km = TextEditingController();
  final _fc = TextEditingController();
  final _kcalCtl = TextEditingController();
  // Esteira/caminhada: velocidade e inclinação ajustáveis durante o cardio.
  double _vel = 8.0, _inc = 0.0;
  double _kmAcum = 0, _kcalAcum = 0;
  DateTime? _ultTick;

  bool get _ehEsteira => _mod == 0 || _mod == 1;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_rodando) return;
      _acumula();
      setState(() {});
      _checarMeta();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _km.dispose();
    _fc.dispose();
    _kcalCtl.dispose();
    super.dispose();
  }

  /// Gasto por hora pela velocidade e inclinação (equações ACSM).
  double _kcalHoraEsteira() {
    final v = _vel * 1000 / 60; // m/min
    final g = _inc / 100;
    final vo2 = (_mod == 1 || _vel <= 7.2)
        ? 3.5 + 0.1 * v + 1.8 * v * g
        : 3.5 + 0.2 * v + 0.9 * v * g;
    return vo2 / 3.5 * _peso;
  }

  /// Soma distância e calorias do tempo decorrido desde a última chamada.
  void _acumula() {
    final agora = DateTime.now();
    final dt = _ultTick == null
        ? 0.0
        : agora.difference(_ultTick!).inMilliseconds / 1000.0;
    _ultTick = agora;
    if (!_rodando || dt <= 0) return;
    if (_ehEsteira) {
      _kmAcum += _vel * dt / 3600;
      _kcalAcum += _kcalHoraEsteira() * dt / 3600;
    } else {
      _kcalAcum +=
          _mods[_mod].met * _intensMult[_int] * _peso * dt / 3600;
    }
  }

  String _ritmo(int seg, double km) {
    if (km < 0.05 || seg <= 0) return '--';
    final s = (seg / km).round();
    return "${s ~/ 60}'${(s % 60).toString().padLeft(2, '0')}\"";
  }

  String _num(double v, [int d = 1]) => v.toStringAsFixed(d).replaceAll('.', ',');

  double get _peso {
    for (final a in app.avaliacoes.reversed) {
      final p = a.v['peso'];
      if (p != null && p > 0) return p;
    }
    return 75;
  }

  int get _seg {
    final extra = (_rodando && _ini != null)
        ? DateTime.now().difference(_ini!).inMilliseconds
        : 0;
    return (_acumMs + extra) ~/ 1000;
  }

  int _kcalDe(int seg) => _kcalAcum.round();

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$ss' : '$m:$ss';
  }

  void _checarMeta() {
    final meta = _meta;
    if (meta == null || _metaAvisada) return;
    if (_seg >= meta * 60) {
      _metaAvisada = true;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meta de $meta min atingida! 🎉')),
      );
    }
  }

  void _iniciar() {
    setState(() {
      _ini = DateTime.now();
      _ultTick = DateTime.now();
      _rodando = true;
    });
  }

  void _pausar() {
    _acumula();
    if (_ini != null) {
      _acumMs += DateTime.now().difference(_ini!).inMilliseconds;
    }
    setState(() => _rodando = false);
  }

  Future<void> _finalizar() async {
    if (_rodando) _pausar();
    final seg = _seg;
    if (seg < 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Inicie o cardio antes.')));
      return;
    }
    _km.text =
        _kmAcum > 0 ? _kmAcum.toStringAsFixed(2).replaceAll('.', ',') : '';
    _kcalCtl.text = '${_kcalDe(seg)}';
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Finalizar cardio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_mods[_mod].nome} • ${_fmt(seg)}'),
              const SizedBox(height: 4),
              const Text(
                  'Ajuste com os números da esteira, se quiser.',
                  style: TextStyle(color: kMudo, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: _kcalCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calorias (kcal)'),
              ),
              TextField(
                controller: _km,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Distância (km)'),
              ),
              TextField(
                controller: _fc,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Batimentos médios (bpm) — opcional'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, 'voltar'),
              child: const Text('Voltar')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'descartar'),
              child: const Text('Descartar')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'salvar'),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (!mounted) return;
    if (r == 'descartar') {
      Navigator.of(context).popUntil((x) => x.isFirst);
      return;
    }
    if (r != 'salvar') return;
    final km = double.tryParse(_km.text.trim().replaceAll(',', '.'));
    final fc = int.tryParse(_fc.text.trim());
    final kcalDigitada = int.tryParse(_kcalCtl.text.trim());
    final nome = _mods[_mod].nome;
    final msg = ScaffoldMessenger.of(context);
    final agora = DateTime.now();
    final d = widget.dia;
    final quando = d == null
        ? agora
        : DateTime(d.year, d.month, d.day, agora.hour, agora.minute, agora.second);
    await app.addSessao(Sessao(
      data: quando.toIso8601String(),
      dia: 'Cardio • $nome',
      seg: seg,
      series: 0,
      seriesTotal: 0,
      volume: 0,
      completo: true,
      livre: true,
      tipo: 'cardio',
      modalidade: nome,
      km: (km != null && km > 0) ? km : null,
      kcal: (kcalDigitada != null && kcalDigitada > 0) ? kcalDigitada : _kcalDe(seg),
      fc: (fc != null && fc > 0) ? fc : null,
    ));
    msg.showSnackBar(const SnackBar(content: Text('Cardio salvo no histórico!')));
    if (!mounted) return;
    Navigator.of(context).popUntil((x) => x.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final seg = _seg;
    final meta = _meta;
    final emAndamento = _rodando || seg > 0;
    final prog = meta == null
        ? (seg % 60) / 60.0
        : (seg / (meta * 60)).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _cabecalho(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                _cronometro(seg, prog),
                const SizedBox(height: 14),
                if (_ehEsteira) ...[
                  _ajustesEsteira(),
                  const SizedBox(height: 14),
                ],
                _modalidades(emAndamento),
                const SizedBox(height: 14),
                if (!_ehEsteira) ...[
                  _intensidade(),
                  const SizedBox(height: 14),
                ],
                _metaTempo(emAndamento),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: !emAndamento
              ? FilledButton.icon(
                  style: estiloPrimario,
                  onPressed: _iniciar,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Iniciar cardio'),
                )
              : Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: estiloContorno,
                        onPressed: _rodando ? _pausar : _iniciar,
                        icon: Icon(_rodando
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                        label: Text(_rodando ? 'Pausar' : 'Retomar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: estiloPrimario,
                        onPressed: _finalizar,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Finalizar'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _cabecalho() {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/fotos/cardio.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.8),
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
                colors: [
                  Color(0x55000000),
                  Color(0x00000000),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cardio', style: titulo(56)),
                const Text('Escolha, ajuste e comece',
                    style: TextStyle(color: kMudo)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cronometro(int seg, double prog) {
    final kcal = _kcalDe(seg);
    return Vidro(
      child: Column(
        children: [
          SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: prog,
                    strokeWidth: 12,
                    backgroundColor: branco(.1),
                    color: kAzul,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_fmt(seg), style: titulo(64)),
                    Text(_rodando ? 'em andamento' : (seg > 0 ? 'pausado' : 'pronto'),
                        style: const TextStyle(color: kMudo)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _ehEsteira
                ? [
                    _mini(_num(_kmAcum, 2), 'km'),
                    _mini('~$kcal', 'kcal'),
                    _mini(_ritmo(seg, _kmAcum), 'min/km'),
                  ]
                : [
                    _mini('~$kcal', 'kcal'),
                    _mini(_mods[_mod].nome, 'modalidade'),
                    _mini(_intensNomes[_int], 'intensidade'),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String v, String r) => Column(
        children: [
          Text(v, style: titulo(26)),
          Text(r, style: const TextStyle(color: kMudo, fontSize: 12)),
        ],
      );

  Widget _passo(String t, VoidCallback f) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          style: estiloContornoMini,
          onPressed: f,
          child: Text(t),
        ),
      );

  Widget _stepper(String rotulo, String valor, void Function(double) mudar,
      List<double> passos) {
    String sinal(double d) => (d > 0 ? '+' : '−') + _num(d.abs());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: const TextStyle(color: kMudo)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final d in passos.reversed) _passo(sinal(-d), () => mudar(-d)),
            Expanded(
              child: Center(child: Text(valor, style: titulo(34))),
            ),
            for (final d in passos) _passo(sinal(d), () => mudar(d)),
          ],
        ),
      ],
    );
  }

  /// Igual ao painel da esteira: ajuste velocidade e inclinação durante o cardio.
  Widget _ajustesEsteira() {
    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ajustes da esteira', style: titulo(26)),
          const SizedBox(height: 4),
          const Text(
              'Mudou a velocidade ou a inclinação na esteira? Ajuste aqui também.',
              style: TextStyle(color: kMudo, fontSize: 12)),
          const SizedBox(height: 12),
          _stepper('Velocidade (km/h)', _num(_vel), (d) {
            _acumula();
            setState(() => _vel = (_vel + d).clamp(0.5, 25.0).toDouble());
          }, const [0.1, 0.5]),
          const SizedBox(height: 14),
          _stepper('Inclinação (%)', _num(_inc), (d) {
            _acumula();
            setState(() => _inc = (_inc + d).clamp(0.0, 15.0).toDouble());
          }, const [0.5, 1.0]),
        ],
      ),
    );
  }

  Widget _modalidades(bool travado) {
    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Modalidade', style: titulo(26)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 3 * 8) / 4;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _mods.length; i++)
                  GestureDetector(
                    onTap: travado
                        ? null
                        : () => setState(() {
                              _mod = i;
                              if (i == 0) _vel = 8.0;
                              if (i == 1) _vel = 5.0;
                            }),
                    child: Opacity(
                      opacity: travado && i != _mod ? 0.4 : 1,
                      child: Container(
                        width: w,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: i == _mod
                              ? kAzul.withOpacity(0.28)
                              : branco(.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: i == _mod ? kAzul : branco(.12),
                              width: i == _mod ? 2 : 1),
                        ),
                        child: Column(
                          children: [
                            Icon(_mods[i].icone,
                                color: i == _mod ? Colors.white : kMudo),
                            const SizedBox(height: 6),
                            Text(_mods[i].nome,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _intensidade() {
    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Intensidade', style: titulo(26)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _intensNomes.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _int = i),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: i == _intensNomes.length - 1 ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            i == _int ? kAzul.withOpacity(0.28) : branco(.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: i == _int ? kAzul : branco(.12),
                            width: i == _int ? 2 : 1),
                      ),
                      child: Text(_intensNomes[i]),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaTempo(bool travado) {
    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Meta de tempo', style: titulo(26)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _metas)
                ChoiceChip(
                  label: Text(m == null ? 'Livre' : '$m min'),
                  selected: _meta == m,
                  onSelected: (_) => setState(() {
                    _meta = m;
                    _metaAvisada = false;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'As calorias são uma estimativa pelo seu último peso registrado (ou 75 kg), modalidade e intensidade.',
            style: TextStyle(color: kMudo, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Registra um cardio que já foi feito (sem usar o cronômetro).
Future<void> registrarCardioManual(BuildContext context, DateTime dia) async {
  final r = await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(builder: (_) => const _CardioFeitoTela()),
  );
  if (r == null) return;
  final agora = DateTime.now();
  final quando = DateTime(dia.year, dia.month, dia.day, agora.hour, agora.minute);
  final nome = _mods[r['mod'] as int].nome;
  await app.addSessao(Sessao(
    data: quando.toIso8601String(),
    dia: 'Cardio • $nome',
    seg: r['seg'] as int,
    series: 0,
    seriesTotal: 0,
    volume: 0,
    completo: true,
    livre: true,
    tipo: 'cardio',
    modalidade: nome,
    km: r['km'] as double?,
    kcal: r['kcal'] as int,
    fc: r['fc'] as int?,
  ));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Cardio registrado!')));
  }
}

/// Tela "Já fiz cardio": os mesmos números do painel da esteira
/// (distância, tempo, calorias e ritmo), com o resumo atualizando enquanto digita.
class _CardioFeitoTela extends StatefulWidget {
  const _CardioFeitoTela();
  @override
  State<_CardioFeitoTela> createState() => _CardioFeitoEstado();
}

class _CardioFeitoEstado extends State<_CardioFeitoTela> {
  int _mod = 0;
  bool _kcalEditada = false;
  final _min = TextEditingController(text: '20');
  final _sec = TextEditingController(text: '00');
  final _km = TextEditingController();
  final _kcal = TextEditingController();
  final _fc = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recalc();
  }

  @override
  void dispose() {
    _min.dispose();
    _sec.dispose();
    _km.dispose();
    _kcal.dispose();
    _fc.dispose();
    super.dispose();
  }

  double get _peso {
    for (final a in app.avaliacoes.reversed) {
      final p = a.v['peso'];
      if (p != null && p > 0) return p;
    }
    return 75;
  }

  int get _seg =>
      (int.tryParse(_min.text.trim()) ?? 0) * 60 +
      (int.tryParse(_sec.text.trim()) ?? 0);
  double get _kmV =>
      double.tryParse(_km.text.trim().replaceAll(',', '.')) ?? 0;
  double get _velMedia => (_seg > 0 && _kmV > 0) ? _kmV / (_seg / 3600) : 0;

  int get _estimativa {
    final seg = _seg;
    if (seg <= 0) return 0;
    if (_mod <= 1 && _velMedia > 0) {
      final v = _velMedia * 1000 / 60;
      final vo2 = (_mod == 1 || _velMedia <= 7.2) ? 3.5 + 0.1 * v : 3.5 + 0.2 * v;
      return (vo2 / 3.5 * _peso * seg / 3600).round();
    }
    return (_mods[_mod].met * _peso * seg / 3600).round();
  }

  void _recalc() {
    if (!_kcalEditada) _kcal.text = '$_estimativa';
  }

  String _num(double v, [int d = 1]) => v.toStringAsFixed(d).replaceAll('.', ',');

  String get _tempoTxt {
    final s = _seg;
    final h = s ~/ 3600;
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$ss' : '$m:$ss';
  }

  String get _ritmoTxt {
    if (_kmV < 0.05 || _seg <= 0) return '--';
    final s = (_seg / _kmV).round();
    return "${s ~/ 60}'${(s % 60).toString().padLeft(2, '0')}\"";
  }

  Widget _grande(String v, String r, IconData i) => Expanded(
        child: Column(
          children: [
            Icon(i, size: 20, color: kAzul),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: titulo(40))),
            Text(r, style: const TextStyle(color: kMudo, fontSize: 12)),
          ],
        ),
      );

  Widget _painel() {
    final kcal = int.tryParse(_kcal.text.trim()) ?? 0;
    return Vidro(
      child: Column(
        children: [
          Row(
            children: [
              _grande(_kmV > 0 ? _num(_kmV, 2) : '0,00', 'km', Icons.straighten),
              _grande(_tempoTxt, 'min:s', Icons.timer_outlined),
              _grande('$kcal', 'kcal', Icons.local_fire_department_outlined),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: branco(.12), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [
                Text(_ritmoTxt, style: titulo(26)),
                const Text('min/km', style: TextStyle(color: kMudo, fontSize: 12)),
              ]),
              Column(children: [
                Text(_velMedia > 0 ? _num(_velMedia) : '--', style: titulo(26)),
                const Text('km/h (média)',
                    style: TextStyle(color: kMudo, fontSize: 12)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modalidades() {
    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Modalidade', style: titulo(26)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 3 * 8) / 4;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _mods.length; i++)
                  GestureDetector(
                    onTap: () => setState(() {
                      _mod = i;
                      _recalc();
                    }),
                    child: Container(
                      width: w,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: i == _mod ? kAzul.withOpacity(0.28) : branco(.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: i == _mod ? kAzul : branco(.12),
                            width: i == _mod ? 2 : 1),
                      ),
                      child: Column(
                        children: [
                          Icon(_mods[i].icone,
                              color: i == _mod ? Colors.white : kMudo),
                          const SizedBox(height: 6),
                          Text(_mods[i].nome,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  InputDecoration _deco(String rotulo, {String? sufixo}) => InputDecoration(
        labelText: rotulo,
        suffixText: sufixo,
        filled: true,
        fillColor: branco(.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  Widget _dados() {
    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Números da esteira', style: titulo(26)),
          const SizedBox(height: 4),
          const Text('Copie do visor: tempo, distância e calorias.',
              style: TextStyle(color: kMudo, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _min,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(_recalc),
                  decoration: _deco('Tempo', sufixo: 'min'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _sec,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(_recalc),
                  decoration: _deco('Segundos', sufixo: 's'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _km,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(_recalc),
            decoration: _deco('Distância', sufixo: 'km'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _kcal,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _kcalEditada = true),
            decoration: _deco('Calorias', sufixo: 'kcal'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _kcalEditada
                  ? 'Valor digitado por você.'
                  : 'Estimativa automática; troque pelo número da esteira.',
              style: const TextStyle(color: kMudo, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _fc,
            keyboardType: TextInputType.number,
            decoration: _deco('Batimentos médios (opcional)', sufixo: 'bpm'),
          ),
        ],
      ),
    );
  }

  void _salvar() {
    final seg = _seg;
    if (seg <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o tempo do cardio.')));
      return;
    }
    final km = _kmV;
    final fc = int.tryParse(_fc.text.trim());
    final kcal = int.tryParse(_kcal.text.trim());
    Navigator.pop(context, {
      'mod': _mod,
      'seg': seg,
      'km': km > 0 ? km : null,
      'fc': (fc != null && fc > 0) ? fc : null,
      'kcal': (kcal != null && kcal > 0) ? kcal : _estimativa,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cardio feito', style: titulo(28))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _painel(),
          const SizedBox(height: 14),
          _modalidades(),
          const SizedBox(height: 14),
          _dados(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            style: estiloPrimario,
            onPressed: _salvar,
            icon: const Icon(Icons.check),
            label: const Text('Salvar cardio'),
          ),
        ),
      ),
    );
  }
}
