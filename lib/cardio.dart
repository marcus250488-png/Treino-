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
  const CardioTela({super.key});
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

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_rodando) return;
      setState(() {});
      _checarMeta();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _km.dispose();
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

  int get _seg {
    final extra = (_rodando && _ini != null)
        ? DateTime.now().difference(_ini!).inMilliseconds
        : 0;
    return (_acumMs + extra) ~/ 1000;
  }

  int _kcalDe(int seg) =>
      (_mods[_mod].met * _intensMult[_int] * _peso * seg / 3600).round();

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
      _rodando = true;
    });
  }

  void _pausar() {
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
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Finalizar cardio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${_mods[_mod].nome} • ${_fmt(seg)} • ~${_kcalDe(seg)} kcal'),
              const SizedBox(height: 12),
              TextField(
                controller: _km,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Distância (km) — opcional'),
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
    final nome = _mods[_mod].nome;
    final msg = ScaffoldMessenger.of(context);
    await app.addSessao(Sessao(
      data: DateTime.now().toIso8601String(),
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
      kcal: _kcalDe(seg),
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
                _modalidades(emAndamento),
                const SizedBox(height: 14),
                _intensidade(),
                const SizedBox(height: 14),
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
            children: [
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
                    onTap: travado ? null : () => setState(() => _mod = i),
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
