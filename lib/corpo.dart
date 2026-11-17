import 'package:flutter/material.dart';

import 'state.dart' show norm;
import 'telas.dart' show branco;

const _corPrincipal = Color(0xFFE53935);
const _corSecundario = Color(0xFFFB8C00);
const _corEstab = Color(0xFF1E88E5);

/// Região muscular desenhada sobre o corpo. view 0 = frente, 1 = costas.
class _Reg {
  final String id;
  final int view;
  final List<Rect> retangulos;
  const _Reg(this.id, this.view, this.retangulos);
}

// Coordenadas em unidades de um quadro de 240 x 200 (duas vistas lado a lado).
final List<_Reg> _regioes = [
  _Reg('peito', 0, [
    Rect.fromLTWH(33, 52, 15, 14),
    Rect.fromLTWH(52, 52, 15, 14),
  ]),
  _Reg('ombro', 0, [
    Rect.fromLTWH(20, 40, 12, 12),
    Rect.fromLTWH(68, 40, 12, 12),
  ]),
  _Reg('ombro', 1, [
    Rect.fromLTWH(20, 40, 12, 12),
    Rect.fromLTWH(68, 40, 12, 12),
  ]),
  _Reg('biceps', 0, [
    Rect.fromLTWH(15, 54, 9, 26),
    Rect.fromLTWH(76, 54, 9, 26),
  ]),
  _Reg('triceps', 1, [
    Rect.fromLTWH(15, 54, 9, 26),
    Rect.fromLTWH(76, 54, 9, 26),
  ]),
  _Reg('antebraco', 0, [
    Rect.fromLTWH(11, 82, 9, 30),
    Rect.fromLTWH(80, 82, 9, 30),
  ]),
  _Reg('antebraco', 1, [
    Rect.fromLTWH(11, 82, 9, 30),
    Rect.fromLTWH(80, 82, 9, 30),
  ]),
  _Reg('abdomen', 0, [Rect.fromLTWH(42, 72, 16, 30)]),
  _Reg('quadriceps', 0, [
    Rect.fromLTWH(34, 124, 13, 52),
    Rect.fromLTWH(53, 124, 13, 52),
  ]),
  _Reg('adutor', 0, [Rect.fromLTWH(46, 128, 8, 40)]),
  _Reg('trapezio', 1, [Rect.fromLTWH(38, 36, 24, 14)]),
  _Reg('dorsal', 1, [
    Rect.fromLTWH(31, 56, 12, 36),
    Rect.fromLTWH(57, 56, 12, 36),
  ]),
  _Reg('lombar', 1, [Rect.fromLTWH(42, 94, 16, 18)]),
  _Reg('gluteo', 1, [
    Rect.fromLTWH(34, 114, 14, 14),
    Rect.fromLTWH(52, 114, 14, 14),
  ]),
  _Reg('posterior', 1, [
    Rect.fromLTWH(34, 130, 13, 46),
    Rect.fromLTWH(53, 130, 13, 46),
  ]),
  _Reg('panturrilha', 1, [
    Rect.fromLTWH(34, 178, 12, 18),
    Rect.fromLTWH(54, 178, 12, 18),
  ]),
];

/// Traduz o texto de um músculo (ex.: "Peitoral maior") em regiões do desenho.
Set<String> regioesDeTexto(String t) {
  final s = norm(t);
  final r = <String>{};
  if (s.contains('posterior de coxa') ||
      s.contains('isquio') ||
      s.contains('femoral')) {
    r.add('posterior');
  }
  if (s.contains('peitoral') || s.contains('serratil')) r.add('peito');
  if (s.contains('deltoide')) r.add('ombro');
  if (s.contains('triceps')) r.add('triceps');
  if (!s.contains('femoral') && s.contains('biceps')) r.add('biceps');
  if (s.contains('braquial')) r.add('biceps');
  if (s.contains('antebraco')) r.add('antebraco');
  if (s.contains('abdom') || s.contains('core') || s.contains('obliq')) {
    r.add('abdomen');
  }
  if (s.contains('quadriceps') || s.contains('reto femoral') || s.contains('vasto')) {
    r.add('quadriceps');
  }
  if (s.contains('adutor')) r.add('adutor');
  if (s.contains('trapezio')) r.add('trapezio');
  if (s.contains('dorsal') || s.contains('romboide')) r.add('dorsal');
  if (s.contains('lombar') || s.contains('eretores')) r.add('lombar');
  if (s.contains('gluteo')) r.add('gluteo');
  if (s.contains('panturrilha') || s.contains('gastrocnem') || s.contains('soleo')) {
    r.add('panturrilha');
  }
  return r;
}

/// Desenho do corpo (frente e costas) com os músculos trabalhados destacados.
/// Vermelho = principal, laranja = secundário, azul = estabilizador.
class CorpoDiagrama extends StatelessWidget {
  final List<String> principal;
  final List<String> secundario;
  final List<String> estabilizador;
  const CorpoDiagrama({
    super.key,
    required this.principal,
    required this.secundario,
    required this.estabilizador,
  });

  @override
  Widget build(BuildContext context) {
    final cores = <String, Color>{};
    void aplica(List<String> lista, Color cor) {
      for (final t in lista) {
        for (final id in regioesDeTexto(t)) {
          cores.putIfAbsent(id, () => cor); // principal tem prioridade
        }
      }
    }

    aplica(principal, _corPrincipal);
    aplica(secundario, _corSecundario);
    aplica(estabilizador, _corEstab);
    return AspectRatio(
      aspectRatio: 240 / 200,
      child: CustomPaint(
        painter: _CorpoPainter(cores),
        size: Size.infinite,
      ),
    );
  }
}

class _CorpoPainter extends CustomPainter {
  final Map<String, Color> cores;
  _CorpoPainter(this.cores);

  @override
  void paint(Canvas canvas, Size size) {
    final escala = (size.width / 240) < (size.height / 200)
        ? size.width / 240
        : size.height / 200;
    canvas.save();
    canvas.translate((size.width - 240 * escala) / 2,
        (size.height - 200 * escala) / 2);
    canvas.scale(escala);

    final corpo = Paint()..color = branco(.14);
    for (final view in [0, 1]) {
      canvas.save();
      canvas.translate(view * 120.0, 0);
      canvas.drawOval(Rect.fromLTWH(37, 6, 26, 28), corpo);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(28, 36, 44, 84), const Radius.circular(18)),
          corpo);
      for (final b in [
        Rect.fromLTWH(12, 40, 14, 80),
        Rect.fromLTWH(74, 40, 14, 80),
      ]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(b, const Radius.circular(7)), corpo);
      }
      for (final p in [
        Rect.fromLTWH(33, 118, 16, 78),
        Rect.fromLTWH(51, 118, 16, 78),
      ]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(p, const Radius.circular(8)), corpo);
      }
      for (final r in _regioes) {
        if (r.view != view) continue;
        final cor = cores[r.id];
        if (cor == null) continue;
        final paint = Paint()..color = cor.withOpacity(.95);
        for (final rect in r.retangulos) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);
        }
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CorpoPainter old) => true;
}
