import 'package:flutter/material.dart';
import 'state.dart';
import 'telas.dart';
import 'extras.dart' show fmtTempo, fmtNum;
import 'compartilhar.dart';

/// Resumo completo de um treino ou cardio do histórico.
class SessaoDetalheTela extends StatelessWidget {
  final Sessao sessao;
  const SessaoDetalheTela({super.key, required this.sessao});

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
            style: estiloContorno,
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
      const SizedBox(height: 8),
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
      for (final e in det) {
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
                Text('${e['nome']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
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
