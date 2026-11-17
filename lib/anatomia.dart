import 'package:flutter/material.dart';
import 'dart:typed_data' show ByteData;
import 'package:flutter/services.dart' show rootBundle;

import 'corpo_muscular.dart';
import 'state.dart';
import 'telas.dart';


// Intensidade (0 a 1) de cada papel no mapa de calor do corpo.
const double _iPrincipal = 1.0;
const double _iSecundario = .55;
const double _iEstab = .18;

/// Traduz o nome de um músculo ("Peitoral maior") em ids do desenho do corpo.
Set<String> _idsDe(String texto) {
  final s = norm(texto);
  bool tem(String t) => s.contains(t);
  final r = <String>{};
  if ((tem('posterior de coxa') || tem('isquio') || tem('femoral')) &&
      !tem('reto femoral')) {
    r.add('posterior');
  }
  if (tem('peitoral') || tem('serratil')) r.add('peito');
  if (tem('deltoide') || tem('ombro')) r.add('ombro');
  if (tem('triceps')) r.add('triceps');
  if (tem('biceps') && !tem('femoral')) r.add('biceps');
  if (tem('braquial') && !tem('braquiorradial')) r.add('biceps');
  if (tem('antebraco') || tem('braquiorradial')) r.add('antebraco');
  if (tem('obliq')) r.add('obliquos');
  if (tem('abdom') || tem('core')) r.add('abdomen');
  if (tem('quadriceps') || tem('reto femoral') || tem('vasto')) {
    r.add('quadriceps');
  }
  if (tem('trapezio')) r.add('trapezio');
  if (tem('dorsal') || tem('romboide') || tem('redondo')) r.add('dorsal');
  if (tem('lombar') || tem('eretores')) r.add('lombar');
  if (tem('gluteo')) r.add('gluteo');
  if (tem('panturrilha') || tem('gastrocnem') || tem('soleo')) {
    r.add('panturrilha');
  }
  return r;
}

Map<String, double> _intensidades(
    List<String> principal, List<String> secundario, List<String> estab) {
  final m = <String, double>{};
  void aplicar(List<String> lista, double v) {
    for (final t in lista) {
      for (final id in _idsDe(t)) {
        if (v > (m[id] ?? 0)) m[id] = v;
      }
    }
  }

  aplicar(estab, _iEstab);
  aplicar(secundario, _iSecundario);
  aplicar(principal, _iPrincipal);
  return m;
}

/// Corpo de frente e de costas (o mesmo do "Seu desempenho") com os músculos
/// do exercício coloridos. Tocar em um músculo mostra o nome e o papel dele.
class _CorposAnatomia extends StatefulWidget {
  final Map<String, double> intensidade;
  const _CorposAnatomia({required this.intensidade});
  @override
  State<_CorposAnatomia> createState() => _CorposAnatomiaEstado();
}

class _CorposAnatomiaEstado extends State<_CorposAnatomia> {
  String? _sel;

  Widget _painel(bool frente) => Expanded(
        child: Column(
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
                intensidade: widget.intensidade,
                destaque: _sel,
                aoTocar: (id) => setState(() => _sel = id),
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
        ),
      );

  String _legenda() {
    final id = _sel;
    if (id == null) return 'Toque em um músculo para ver o nome';
    final v = widget.intensidade[id] ?? 0;
    final papel = v >= _iPrincipal
        ? 'principal'
        : v >= _iSecundario
            ? 'secundário'
            : v > 0
                ? 'estabilizador'
                : 'não é trabalhado neste exercício';
    return '${rotulosMusculo[id] ?? id} • $papel';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _painel(true),
            const SizedBox(width: 12),
            _painel(false),
          ],
        ),
        const SizedBox(height: 10),
        Text(_legenda(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMudo, fontSize: 13)),
      ],
    );
  }
}

/// Tela de anatomia: foto do exercício em cima (se existir), desenho do corpo
/// com o músculo destacado, objetivo, execução, dicas e séries.
class AnatomiaTela extends StatelessWidget {
  final Exercicio ex;
  const AnatomiaTela({super.key, required this.ex});

  String get _caminhoFoto => 'assets/exercicios/${ex.id}.jpg';

  /// Só mostra a foto quando ela existe em assets/exercicios/<id>.jpg.
  Widget _foto() => FutureBuilder<ByteData>(
        future: rootBundle.load(_caminhoFoto),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(_caminhoFoto, fit: BoxFit.cover),
              ),
            ),
          );
        },
      );

  Widget _linhaMusculo(String t, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 16))),
          ],
        ),
      );

  Widget _secao(String cabeca, List<Widget> filhos) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Vidro(
          raio: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cabeca, style: titulo(22)),
              const SizedBox(height: 10),
              ...filhos,
            ],
          ),
        ),
      );

  List<Widget> _numerado(List passos) => [
        for (var i = 0; i < passos.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${i + 1}. ${passos[i]}',
                style: const TextStyle(fontSize: 16)),
          ),
      ];

  List<Widget> _marcadores(List itens) => [
        for (final d in itens)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('• $d', style: const TextStyle(fontSize: 16)),
          ),
      ];

  List<String> _lista(Object? x) =>
      [for (final m in (x as List? ?? const [])) m.toString()];

  @override
  Widget build(BuildContext context) {
    final a = app.anatomia[ex.id] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(title: Text(ex.nome, style: titulo(24))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _foto(),
          if (a == null)
            _secao('Anatomia', [
              const Text('Conteúdo ainda não cadastrado para este exercício.',
                  style: TextStyle(color: kMudo)),
            ])
          else ...[
            _secao('Músculos trabalhados', [
              _CorposAnatomia(
                intensidade: _intensidades(
                  _lista(a['principal']),
                  _lista(a['secundario']),
                  _lista(a['estabilizador']),
                ),
              ),
              const SizedBox(height: 14),
              for (final m in _lista(a['principal']))
                _linhaMusculo('$m (principal)', corIntensidade(_iPrincipal)),
              for (final m in _lista(a['secundario']))
                _linhaMusculo('$m (secundário)', corIntensidade(_iSecundario)),
              for (final m in _lista(a['estabilizador']))
                _linhaMusculo('$m (estabilizador)', corIntensidade(_iEstab)),
            ]),
            _secao('Objetivo', [
              Text('${a['objetivo']}',
                  style: const TextStyle(fontSize: 16, color: kMudo)),
            ]),
            _secao('Como executar',
                _numerado(a['execucao'] as List? ?? const [])),
            _secao('Dicas', _marcadores(a['dicas'] as List? ?? const [])),
            _secao('Séries, repetições e descanso', [
              Text(
                  'Séries: ${a['series']}   •   Reps: ${a['reps']}   •   Descanso: ${a['descanso']}',
                  style: const TextStyle(fontSize: 16)),
            ]),
          ],
        ],
      ),
    );
  }
}
