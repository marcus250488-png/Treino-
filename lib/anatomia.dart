import 'package:flutter/material.dart';
import 'dart:typed_data' show ByteData;
import 'package:flutter/services.dart' show rootBundle;

import 'corpo.dart';
import 'state.dart';
import 'telas.dart';

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
              CorpoDiagrama(
                principal: _lista(a['principal']),
                secundario: _lista(a['secundario']),
                estabilizador: _lista(a['estabilizador']),
              ),
              const SizedBox(height: 14),
              for (final m in _lista(a['principal']))
                _linhaMusculo('$m (principal)', const Color(0xFFE53935)),
              for (final m in _lista(a['secundario']))
                _linhaMusculo('$m (secundário)', const Color(0xFFFB8C00)),
              for (final m in _lista(a['estabilizador']))
                _linhaMusculo('$m (estabilizador)', const Color(0xFF1E88E5)),
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
