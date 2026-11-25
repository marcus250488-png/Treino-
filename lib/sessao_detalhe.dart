import 'package:flutter/material.dart';
import 'state.dart';
import 'telas.dart';
import 'extras.dart' show fmtTempo, fmtNum;
import 'compartilhar.dart';

/// Resumo completo de um treino ou cardio do histórico.
class SessaoDetalheTela extends StatefulWidget {
  final Sessao sessao;
  const SessaoDetalheTela({super.key, required this.sessao});

  @override
  State<SessaoDetalheTela> createState() => _SessaoDetalheEstado();
}

class _SessaoDetalheEstado extends State<SessaoDetalheTela> {
  Sessao get sessao => widget.sessao;

  Sessao? _anterior() {
    Sessao? r;
    for (final x in app.sessoes) {
      if (x.data == sessao.data) continue;
      if (x.dia != sessao.dia || !x.completo) continue;
      if (x.data.compareTo(sessao.data) >= 0) continue;
      if (r == null || x.data.compareTo(r.data) > 0) r = x;
    }
    return r;
  }

  String _data() {
    final d = DateTime.tryParse(sessao.data);
    if (d == null) return sessao.data;
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(d.day)}/${d2(d.month)}/${d.year} às ${d2(d.hour)}:${d2(d.minute)}';
  }

  Widget _caixa(String v, String r) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: branco(.07),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(v, style: titulo(30)),
              const SizedBox(height: 2),
              Text(r, style: const TextStyle(color: kMudo, fontSize: 12)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = sessao;
    final kcal = s.kcal ?? (s.seg / 60 * 6.5).round();
    return Scaffold(
      appBar: AppBar(
          title: Text(s.cardio ? 'Resumo do cardio' : 'Resumo do treino',
              style: titulo(28)),
          actions: [
            if (!s.cardio)
              IconButton(
                tooltip: 'Compartilhar',
                icon: const Icon(Icons.ios_share),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CompartilharTela(sessao: s)),
                ),
              ),
          ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Text(s.rotulo, style: titulo(36)),
          const SizedBox(height: 2),
          Text(_data(), style: const TextStyle(color: kMudo)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(s.completo ? 'Completo' : 'Parcial')),
              if (s.livre && !s.cardio) const Chip(label: Text('Treino livre')),
            ],
          ),
          const SizedBox(height: 10),
          if (s.cardio) ..._cardio(s, kcal) else ..._musculacao(s, kcal),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: estiloContornoFino,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Excluir este treino?'),
                  content: const Text(
                      'Ele sai do histórico e das estatísticas. Isso não pode ser desfeito.'),
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
              if (ok == true) {
                await app.excluirSessao(s);
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text('Excluir este treino',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  List<Widget> _cardio(Sessao s, int kcal) {
    final min = s.seg / 60;
    final km = s.km;
    return [
      Row(
        children: [
          _caixa(fmtTempo(s.seg), 'duração'),
          const SizedBox(width: 10),
          _caixa('$kcal', 'kcal'),
          const SizedBox(width: 10),
          _caixa(km != null && km > 0 ? fmtNum(km) : '--', 'km'),
        ],
      ),
      const SizedBox(height: 12),
      Vidro(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalhes', style: titulo(26)),
            const SizedBox(height: 8),
            Text('Modalidade: ${s.modalidade ?? 'Cardio'}'),
            if (km != null && km > 0 && min > 0) ...[
              Text('Velocidade média: ${fmtNum(km / (min / 60))} km/h'),
              Text('Ritmo: ${fmtNum(min / km)} min/km'),
            ],
            if (s.fc != null && s.fc! > 0)
              Text('Batimentos médios: ${s.fc} bpm'),
          ],
        ),
      ),
    ];
  }

  Future<void> _editarDuracao(BuildContext context, Sessao s) async {
    final h = TextEditingController(text: (s.seg ~/ 3600).toString());
    final m = TextEditingController(text: ((s.seg % 3600) ~/ 60).toString());
    final sec = TextEditingController(text: (s.seg % 60).toString());
    final valor = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Editar duração do treino'),
        content: Row(children: [
          Expanded(child: TextField(controller: h, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Horas'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: m, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutos'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: sec, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Segundos'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final hh = int.tryParse(h.text) ?? 0;
            final mm = int.tryParse(m.text) ?? 0;
            final ss = int.tryParse(sec.text) ?? 0;
            if (hh < 0 || mm < 0 || ss < 0 || mm > 59 || ss > 59) return;
            Navigator.pop(c, hh * 3600 + mm * 60 + ss);
          }, child: const Text('Salvar')),
        ],
      ),
    );
    h.dispose(); m.dispose(); sec.dispose();
    if (valor == null) return;
    await app.editarDuracaoSessao(s, valor);
    if (mounted) setState(() {});
  }

  Future<void> _editarExercicio(BuildContext context, Sessao s, int index, Map<String, dynamic> e) async {
    final resultado = await showDialog<Map<String, dynamic>?>(context: context, builder: (_) => _EditarExercicioHistorico(e: e));
    if (resultado == null) return;
    await app.editarExercicioSessao(s, index, resultado.isEmpty ? null : resultado);
    if (mounted) setState(() {});
  }

  List<Widget> _musculacao(Sessao s, int kcal) {
    final ant = _anterior();
    final out = <Widget>[
      Row(
        children: [
          _caixa(fmtTempo(s.seg), 'duração'),
          const SizedBox(width: 10),
          _caixa('${s.series}/${s.seriesTotal}', 'séries'),
          const SizedBox(width: 10),
          _caixa('${s.volume.round()}', 'kg volume'),
        ],
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _editarDuracao(context, s),
          icon: const Icon(Icons.timer_outlined, size: 18),
          label: const Text('Editar duração do treino'),
          style: TextButton.styleFrom(foregroundColor: kAzul),
        ),
      ),
      const SizedBox(height: 2),
      Text('~$kcal kcal gastas (estimativa)',
          style: const TextStyle(color: kMudo)),
    ];
    if (ant != null) {
      final dt = s.seg - ant.seg;
      final dv = s.volume - ant.volume;
      String sinal(num n) => n > 0 ? '+' : (n < 0 ? '−' : '');
      out.addAll([
        const SizedBox(height: 14),
        Vidro(
          padding: const EdgeInsets.all(16),
          raio: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comparado à vez anterior', style: titulo(24)),
              const SizedBox(height: 6),
              Text(
                  'Tempo: ${fmtTempo(ant.seg)} → ${fmtTempo(s.seg)} (${sinal(dt)}${fmtTempo(dt.abs())})'),
              Text(
                  'Volume: ${ant.volume.round()} → ${s.volume.round()} kg (${sinal(dv)}${dv.abs().round()} kg)'),
            ],
          ),
        ),
      ]);
    }
    out.add(const SizedBox(height: 16));
    out.add(Text('Exercícios', style: titulo(26)));
    out.add(const SizedBox(height: 8));
    final det = s.detalhes;
    if (det == null || det.isEmpty) {
      out.add(const Text(
        'Este treino foi salvo antes dos detalhes por exercício. Nos próximos treinos, cada exercício e as cargas usadas aparecem aqui.',
        style: TextStyle(color: kMudo),
      ));
    } else {
      for (var idx = 0; idx < det.length; idx++) {
        final e = det[idx];
        final cargas = ((e['cargas'] as List?) ?? const [])
            .map((c) => (c as num).toDouble())
            .toList();
        final reps = '${e['reps'] ?? ''}';
        var vol = 0.0;
        for (final c in cargas) {
          vol += c * repsMedio(reps);
        }
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Vidro(
            padding: const EdgeInsets.all(14),
            raio: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${e['nome']}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      tooltip: 'Editar ou excluir exercício',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _editarExercicio(context, s, idx, e),
                      icon: const Icon(Icons.edit_outlined, color: kAzul, size: 20),
                    ),
                  ],
                ),
                Text('${e['grupo'] ?? ''} • ${cargas.length} séries de $reps reps',
                    style: const TextStyle(color: kMudo, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < cargas.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: branco(.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                            '${i + 1}ª: ${cargas[i] > 0 ? '${fmtNum(cargas[i])} kg' : 'sem carga'}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                if (vol > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Volume: ${vol.round()} kg',
                        style: const TextStyle(color: kMudo, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ));
      }
    }
    return out;
  }
}


class _EditarExercicioHistorico extends StatefulWidget {
  final Map<String, dynamic> e;
  const _EditarExercicioHistorico({required this.e});
  @override
  State<_EditarExercicioHistorico> createState() => _EditarExercicioHistoricoState();
}

class _EditarExercicioHistoricoState extends State<_EditarExercicioHistorico> {
  late final TextEditingController nome, grupo, reps;
  late List<TextEditingController> cargas;

  @override
  void initState() {
    super.initState();
    nome = TextEditingController(text: '${widget.e['nome'] ?? ''}');
    grupo = TextEditingController(text: '${widget.e['grupo'] ?? ''}');
    reps = TextEditingController(text: '${widget.e['reps'] ?? ''}');
    cargas = ((widget.e['cargas'] as List?) ?? const [])
        .map((v) => TextEditingController(text: '$v')).toList();
    if (cargas.isEmpty) cargas.add(TextEditingController(text: '0'));
  }

  @override
  void dispose() {
    nome.dispose(); grupo.dispose(); reps.dispose();
    for (final c in cargas) { c.dispose(); }
    super.dispose();
  }

  InputDecoration _decoracao(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label, hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 19),
        filled: true, fillColor: branco(.055),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: branco(.08))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: branco(.09))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: kAzul, width: 1.5)),
      );

  Widget _campo(TextEditingController c, String label,
      {String? hint, IconData? icon}) => TextField(
        controller: c,
        decoration: _decoracao(label, hint: hint, icon: icon),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101722),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25),
          side: BorderSide(color: kAzul.withOpacity(.35))),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .86,
          maxWidth: 480,
        ),
        child: StatefulBuilder(builder: (context, refresh) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
              child: Row(children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: kAzul.withOpacity(.14),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.tune_rounded, color: kAzul)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Editar exercício', style: titulo(23)),
                    const SizedBox(height: 2),
                    const Text('Ajuste os dados e as cargas',
                        style: TextStyle(color: kMudo, fontSize: 12)),
                  ])),
                IconButton(onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            Divider(height: 1, color: branco(.08)),
            Flexible(child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              children: [
                const Text('INFORMAÇÕES', style: TextStyle(color: kMudo,
                    fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                const SizedBox(height: 10),
                _campo(nome, 'Nome do exercício', icon: Icons.fitness_center_rounded),
                const SizedBox(height: 10),
                _campo(grupo, 'Grupo muscular', icon: Icons.category_outlined),
                const SizedBox(height: 10),
                _campo(reps, 'Repetições por série', hint: 'Ex.: 12 / 10 / 8',
                    icon: Icons.repeat_rounded),
                const SizedBox(height: 22),
                Row(children: [
                  const Expanded(child: Text('CARGAS POR SÉRIE', style: TextStyle(
                      color: kMudo, fontSize: 11, fontWeight: FontWeight.w800,
                      letterSpacing: 1.1))),
                  Text('${cargas.length} séries',
                      style: const TextStyle(color: kMudo, fontSize: 12)),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => refresh(() =>
                        cargas.add(TextEditingController(text: '0'))),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Adicionar'),
                    style: TextButton.styleFrom(foregroundColor: kAzul,
                        visualDensity: VisualDensity.compact),
                  ),
                ]),
                const SizedBox(height: 8),
                for (var i = 0; i < cargas.length; i++)
                  Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
                      decoration: BoxDecoration(color: branco(.045),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: branco(.07))),
                      child: Row(children: [
                        Container(width: 30, height: 30, alignment: Alignment.center,
                          decoration: BoxDecoration(color: kAzul.withOpacity(.14),
                              shape: BoxShape.circle),
                          child: Text('${i + 1}', style: const TextStyle(color: kAzul,
                              fontWeight: FontWeight.w800, fontSize: 12))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(
                          controller: cargas[i],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Carga utilizada',
                              suffixText: 'kg', border: InputBorder.none, isDense: true),
                        )),
                        IconButton(
                          tooltip: 'Remover série',
                          onPressed: cargas.length <= 1 ? null : () => refresh(() {
                            final c = cargas.removeAt(i); c.dispose();
                          }),
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: Colors.redAccent),
                        ),
                      ]),
                    )),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: kAzul.withOpacity(.07),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: kAzul, size: 18),
                      SizedBox(width: 9),
                      Expanded(child: Text(
                        'As alterações serão refletidas nos dados deste treino e nas métricas relacionadas.',
                        style: TextStyle(color: kMudo, fontSize: 12, height: 1.4))),
                    ]),
                ),
              ],
            )),
            Divider(height: 1, color: branco(.08)),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(children: [
                SizedBox(width: double.infinity, child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kAzul,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    final cs = cargas.map((c) =>
                        double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0).toList();
                    Navigator.pop(context, {
                      'nome': nome.text.trim(), 'grupo': grupo.text.trim(),
                      'reps': reps.text.trim(), 'cargas': cs,
                      'rpe': widget.e['rpe'] ?? '',
                    });
                  },
                  child: const Text('Salvar alterações',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                )),
                const SizedBox(height: 7),
                SizedBox(width: double.infinity, child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                  onPressed: () => Navigator.pop(context, <String, dynamic>{}),
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  label: const Text('Excluir exercício'),
                )),
              ]),
            ),
          ],
        )),
      ),
    );
  }
}
