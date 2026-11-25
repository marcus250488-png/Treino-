import 'package:flutter/material.dart';
import 'state.dart' show norm;

// ============================================================
// Corpo muscular (frente / costas) com mapa de calor por intensidade.
// Geometria em canvas 200x400; formas do lado esquerdo são espelhadas.
// ============================================================

const List<String> _silhueta = [
  'M 100 12 C 109 12 113 20 113 29 C 113 39 108 46 100 46 Z',
  'M 100 40 L 91 42 C 92 50 91 56 88 59 L 100 62 Z',
  'M 92 46 C 92 52 91 56 88 59 C 76 62 62 62 52 68 C 44 72 41 84 41 98 C 40 114 39 128 38 140 C 36 158 32 178 30 196 C 29 204 29 212 31 218 C 35 222 41 220 42 214 C 44 198 48 176 52 158 C 54 150 57 138 58 124 C 59 112 60 104 61 98 C 62 118 66 138 69 154 C 69 172 63 194 58 214 C 55 232 57 262 62 284 C 63 292 62 298 62 306 C 60 322 62 340 66 362 C 68 372 68 384 67 394 C 72 399 84 399 88 393 C 87 384 87 372 88 362 C 91 340 92 320 91 304 C 93 290 96 270 98 250 C 99 240 100 232 100 226 L 100 46 Z',
];

const Map<String, List<String>> _formasFrente = {
  'trapezio': ['M 100 52 C 90 54 78 58 66 63 C 72 68 82 66 89 62 C 95 58 99 56 100 52 Z'],
  'ombro': ['M 52 68 C 45 72 42 84 42 98 C 43 104 48 108 54 108 C 57 98 58 86 62 74 C 62 68 58 66 52 68 Z'],
  'peito': ['M 99 73 C 90 70 78 70 67 75 C 62 80 61 92 66 100 C 74 109 90 111 99 106 Z'],
  'obliquos': ['M 64 104 C 63 120 66 138 70 152 C 75 152 79 149 80 145 C 78 130 76 116 73 106 Z'],
  'abdomen': ['M 99 117 C 95 116 89 116 86 118 C 84 121 84 125 86 127 C 89 130 95 130 99 129 Z', 'M 99 133 C 95 132 89 132 86 134 C 84 137 84 142 86 144 C 89 147 95 147 99 146 Z', 'M 99 150 C 95 149 89 149 86 151 C 84 154 84 159 86 161 C 89 164 95 164 99 163 Z', 'M 99 167 C 95 166 89 166 86 168 C 84 171 84 174 86 176 C 89 179 95 179 99 178 Z'],
  'biceps': ['M 55 100 C 49 110 45 124 43 136 C 47 141 54 140 57 134 C 59 122 59 110 57 100 Z'],
  'antebraco': ['M 44 142 C 40 158 36 176 33 194 C 35 200 40 200 42 196 C 46 180 50 162 53 146 C 50 146 47 145 44 142 Z'],
  'quadriceps': ['M 59 244 C 56 262 58 282 63 296 C 68 298 73 298 76 296 C 74 276 74 256 78 232 C 71 232 64 236 59 244 Z', 'M 78 230 C 74 256 75 278 77 296 C 81 298 85 298 87 295 C 90 276 92 252 92 230 C 88 228 83 228 78 230 Z', 'M 93 232 C 95 252 93 276 89 296 C 92 298 94 296 95 294 C 98 274 99 252 99 230 C 97 230 95 230 93 232 Z'],
  'panturrilha': ['M 62 310 C 59 328 62 346 67 362 C 73 366 79 366 84 362 C 88 346 90 326 90 310 C 84 315 70 315 62 310 Z'],
};

const Map<String, List<String>> _formasCostas = {
  'trapezio': ['M 100 52 C 90 54 78 58 66 63 C 70 76 84 92 100 104 Z'],
  'ombro': ['M 52 68 C 45 72 42 84 42 98 C 43 104 48 108 54 108 C 57 98 58 86 62 74 C 62 68 58 66 52 68 Z'],
  'dorsal': ['M 99 108 C 90 102 78 94 66 96 C 62 114 66 140 78 160 C 86 166 94 168 99 168 Z'],
  'lombar': ['M 99 170 C 92 170 84 168 79 162 C 80 174 82 186 85 198 C 90 200 96 200 99 198 Z'],
  'triceps': ['M 56 98 C 49 108 45 124 43 136 C 47 142 54 142 58 136 C 60 122 60 108 58 98 Z'],
  'antebraco': ['M 44 142 C 40 158 36 176 33 194 C 35 200 40 200 42 196 C 46 180 50 162 53 146 C 50 146 47 145 44 142 Z'],
  'gluteo': ['M 99 200 C 88 198 72 200 61 210 C 56 224 62 240 78 246 C 88 248 96 244 99 240 Z'],
  'posterior': ['M 98 248 C 88 246 72 248 60 256 C 58 272 60 288 64 298 C 71 302 80 302 86 298 C 92 280 96 262 98 248 Z'],
  'panturrilha': ['M 62 308 C 58 322 61 340 67 356 C 72 364 80 364 85 356 C 89 340 91 322 90 308 C 84 314 68 314 62 308 Z'],
};

const Map<String, String> rotulosMusculo = {
  'peito': 'Peito',
  'ombro': 'Ombros',
  'trapezio': 'Trapézio',
  'dorsal': 'Dorsais (costas)',
  'lombar': 'Lombar',
  'biceps': 'Bíceps',
  'triceps': 'Tríceps',
  'antebraco': 'Antebraço',
  'abdomen': 'Abdômen',
  'obliquos': 'Oblíquos',
  'quadriceps': 'Quadríceps',
  'posterior': 'Posterior de coxa',
  'gluteo': 'Glúteos',
  'panturrilha': 'Panturrilha',
};

/// Converte o nome de um grupo do treino em ids de músculos do desenho.
List<String> musculosDoGrupo(String grupo) {
  final n = norm(grupo);
  bool tem(String t) => n.contains(t);
  if (tem('peit')) return ['peito'];
  if (tem('costa') || tem('dorsal')) return ['dorsal', 'trapezio'];
  if (tem('ombro') || tem('delto')) return ['ombro'];
  if (tem('antebrac')) return ['antebraco'];
  if (tem('bicep')) return ['biceps'];
  if (tem('tricep')) return ['triceps'];
  if (tem('brac')) return ['biceps', 'triceps', 'antebraco'];
  if (tem('quadric')) return ['quadriceps'];
  if (tem('posterior') || tem('isquio')) return ['posterior'];
  if (tem('glute')) return ['gluteo'];
  if (tem('panturr') || tem('gemeo')) return ['panturrilha'];
  if (tem('perna') || tem('coxa') || tem('inferior')) {
    return ['quadriceps', 'posterior', 'gluteo', 'panturrilha'];
  }
  if (tem('abdom') || tem('core')) return ['abdomen', 'obliquos'];
  if (tem('lombar')) return ['lombar'];
  if (tem('trapez')) return ['trapezio'];
  return const [];
}

Path _svg(String d, {bool espelho = false}) {
  final t = d.split(' ');
  final p = Path();
  double x(String s) {
    final v = double.parse(s);
    return espelho ? 200 - v : v;
  }

  double y(String s) => double.parse(s);
  var i = 0;
  while (i < t.length) {
    final c = t[i];
    if (c == 'Z') {
      p.close();
      i += 1;
    } else if (c == 'M') {
      p.moveTo(x(t[i + 1]), y(t[i + 2]));
      i += 3;
    } else if (c == 'L') {
      p.lineTo(x(t[i + 1]), y(t[i + 2]));
      i += 3;
    } else if (c == 'C') {
      p.cubicTo(x(t[i + 1]), y(t[i + 2]), x(t[i + 3]), y(t[i + 4]),
          x(t[i + 5]), y(t[i + 6]));
      i += 7;
    } else {
      i += 1;
    }
  }
  return p;
}

class _Geo {
  final List<Path> silhueta;
  final Map<String, List<Path>> musculos;
  _Geo(this.silhueta, this.musculos);
}

_Geo _montar(Map<String, List<String>> formas) {
  final sil = <Path>[];
  for (final d in _silhueta) {
    sil.add(_svg(d));
    sil.add(_svg(d, espelho: true));
  }
  final mus = <String, List<Path>>{};
  formas.forEach((k, ds) {
    final lista = <Path>[];
    for (final d in ds) {
      lista.add(_svg(d));
      lista.add(_svg(d, espelho: true));
    }
    mus[k] = lista;
  });
  return _Geo(sil, mus);
}

final _Geo _geoFrente = _montar(_formasFrente);
final _Geo _geoCostas = _montar(_formasCostas);

/// Escala de cor do mapa de calor: azul -> roxo -> rosa.
Color corIntensidade(double v) {
  const a = Color(0xFF2E8BFF);
  const b = Color(0xFF8A5CFF);
  const c = Color(0xFFFF3D8B);
  final x = v.clamp(0.0, 1.0);
  return x < .5 ? Color.lerp(a, b, x * 2)! : Color.lerp(b, c, (x - .5) * 2)!;
}

class CorpoMuscular extends StatelessWidget {
  final bool frente;
  final Map<String, double> intensidade;
  final String? destaque;
  final ValueChanged<String>? aoTocar;
  const CorpoMuscular({
    super.key,
    required this.frente,
    required this.intensidade,
    this.destaque,
    this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    final geo = frente ? _geoFrente : _geoCostas;
    return AspectRatio(
      aspectRatio: 0.5,
      child: LayoutBuilder(
        builder: (context, box) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: aoTocar == null
                ? null
                : (d) {
                    final p = Offset(d.localPosition.dx * 200 / box.maxWidth,
                        d.localPosition.dy * 400 / box.maxHeight);
                    for (final e in geo.musculos.entries) {
                      for (final path in e.value) {
                        if (path.contains(p)) {
                          aoTocar!(e.key);
                          return;
                        }
                      }
                    }
                  },
            child: CustomPaint(
              size: Size.infinite,
              painter: _CorpoPainter(geo, intensidade, destaque),
            ),
          );
        },
      ),
    );
  }
}

class _CorpoPainter extends CustomPainter {
  final _Geo geo;
  final Map<String, double> intensidade;
  final String? destaque;
  _CorpoPainter(this.geo, this.intensidade, this.destaque);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 400);

    // sombra suave sob o corpo
    final sombra = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (final p in geo.silhueta) {
      canvas.drawPath(p.shift(const Offset(0, 2)), sombra);
    }

    // silhueta
    final corpo = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF5B6479), Color(0xFF39404F)],
      ).createShader(const Rect.fromLTWH(0, 0, 200, 400));
    final borda = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF8D97AD);
    for (final p in geo.silhueta) {
      canvas.drawPath(p, corpo);
    }
    for (final p in geo.silhueta) {
      canvas.drawPath(p, borda);
    }

    // músculos
    final fino = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = const Color(0x66FFFFFF);
    geo.musculos.forEach((id, paths) {
      final v = (intensidade[id] ?? 0).clamp(0.0, 1.0);
      final ativo = v > 0;
      final base = ativo ? corIntensidade(v) : const Color(0xFF7D889C);
      for (final p in paths) {
        if (ativo) {
          canvas.drawPath(
            p,
            Paint()
              ..color = base.withOpacity(.55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
          );
        }
        final b = p.getBounds();
        final claro = Color.lerp(base, Colors.white, ativo ? .28 : .16)!;
        final escuro = Color.lerp(base, Colors.black, .30)!;
        canvas.drawPath(
          p,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [claro, base, escuro],
              stops: const [0, .45, 1],
            ).createShader(b),
        );
        canvas.drawPath(p, fino);
      }
      if (destaque == id) {
        final dest = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white;
        for (final p in paths) {
          canvas.drawPath(p, dest);
        }
      }
    });
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CorpoPainter old) => true;
}
