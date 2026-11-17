import 'package:flutter/material.dart';

import 'state.dart';
import 'telas.dart';

const _corPrincipal = Color(0xFFE53935);
const _corSecundario = Color(0xFFFB8C00);
const _corEstab = Color(0xFF1E88E5);

/// Tela de anatomia: foto do exercício em cima e, embaixo, os músculos,
/// o objetivo, a execução e as dicas. A foto vem de assets/exercicios/<id>.jpg.
class AnatomiaTela extends StatelessWidget {
  final Exercicio ex;
  const AnatomiaTela({super.key, required this.ex});

  Widget _foto() => AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/exercicios/${ex.id}.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: branco(.06),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 56, color: branco(.35)),
                  const SizedBox(height: 8),
                  Text('Foto do exercício ainda não adicionada',
                      style: TextStyle(color: branco(.5))),
                ],
              ),
            ),
          ),
        ),
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
              for (final m in (a['principal'] as List? ?? const []))
                _linhaMusculo('$m (principal)', _corPrincipal),
              for (final m in (a['secundario'] as List? ?? const []))
                _linhaMusculo('$m (secundário)', _corSecundario),
              for (final m in (a['estabilizador'] as List? ?? const []))
                _linhaMusculo('$m (estabilizador)', _corEstab),
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
