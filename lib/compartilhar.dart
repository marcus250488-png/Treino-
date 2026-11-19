import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'extras.dart' show fmtNum, fmtTempo;
import 'fotos.dart';
import 'state.dart';
import 'telas.dart';

Dia? _diaDoNome(String n) {
  for (final d in app.plano) {
    if (d.nome == n) return d;
  }
  return null;
}

String _cargaTexto(List<double> c) {
  if (c.isEmpty) return '';
  if (c.every((x) => x == c.first)) {
    final n = c.length;
    return c.first > 0 ? '$n × ${fmtNum(c.first)} kg' : '$n × peso corporal';
  }
  return '${c.map(fmtNum).join(' / ')} kg';
}

/// Cartão 9:16 (1080 x 1920) para story do Instagram e status do WhatsApp.
class CartaoTreino extends StatelessWidget {
  final Sessao sessao;
  const CartaoTreino({super.key, required this.sessao});

  Widget _stat(String valor, String rotulo) => Expanded(
        child: Column(
          children: [
            Text(valor, style: titulo(84)),
            Text(rotulo, style: const TextStyle(color: kMudo, fontSize: 30)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(sessao.data) ?? DateTime.now();
    final data =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final dia = _diaDoNome(sessao.dia);
    final foto = dia == null ? null : fotoDoDia(dia);
    final kcal = sessao.kcal ?? (sessao.seg / 60 * 6.5).round();
    final exercicios =
        (sessao.detalhes ?? const <Map<String, dynamic>>[]).take(7).toList();

    return SizedBox(
      width: 1080,
      height: 1920,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (foto != null)
            Image.asset(
              fotoAsset(foto),
              fit: BoxFit.cover,
              alignment: Alignment(foto.ax, foto.ay),
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF0B0B0D)),
            )
          else
            const ColoredBox(color: Color(0xFF0B0B0D)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 0.75],
                colors: [
                  Color(0x66000000),
                  Color(0xE6000000),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MEU TREINO',
                    style: TextStyle(
                        color: kAzul,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8)),
                const SizedBox(height: 50),
                Text(sessao.rotulo, style: titulo(130)),
                if (dia != null && dia.foco.isNotEmpty)
                  Text(dia.foco,
                      style: const TextStyle(color: kMudo, fontSize: 44)),
                const SizedBox(height: 8),
                Text(data,
                    style: const TextStyle(color: kMudo, fontSize: 36)),
                const Spacer(),
                Row(
                  children: [
                    _stat(fmtTempo(sessao.seg), 'tempo'),
                    _stat('${sessao.series}/${sessao.seriesTotal}', 'séries'),
                    _stat('${sessao.volume.round()}', 'kg volume'),
                    _stat('$kcal', 'kcal'),
                  ],
                ),
                const SizedBox(height: 70),
                for (final m in exercicios)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${m['nome']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 40, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 20),
                        Text(
                            _cargaTexto([
                              for (final x
                                  in (m['cargas'] as List? ?? const []))
                                (x as num).toDouble(),
                            ]),
                            style:
                                const TextStyle(color: kMudo, fontSize: 36)),
                      ],
                    ),
                  ),
                const Spacer(),
                const Text('Feito com Meu treino',
                    style: TextStyle(color: kMudo, fontSize: 30)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pré-visualização do cartão com botão para enviar a imagem (WhatsApp, Instagram etc.).
class CompartilharTela extends StatefulWidget {
  final Sessao sessao;
  const CompartilharTela({super.key, required this.sessao});
  @override
  State<CompartilharTela> createState() => _CompartilharEstado();
}

class _CompartilharEstado extends State<CompartilharTela> {
  final _chave = GlobalKey();
  bool _enviando = false;

  Future<void> _compartilhar() async {
    setState(() => _enviando = true);
    try {
      final limite = _chave.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final imagem = await limite.toImage(pixelRatio: 1);
      final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final arq = File(
          '${dir.path}/treino_${DateTime.now().millisecondsSinceEpoch}.png');
      await arq.writeAsBytes(dados!.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(arq.path, mimeType: 'image/png')],
        text: 'Treino de hoje: ${widget.sessao.rotulo}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui gerar a imagem: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Compartilhar', style: titulo(28))),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: RepaintBoundary(
                      key: _chave,
                      child: CartaoTreino(sessao: widget.sessao),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: FilledButton.icon(
              style: estiloPrimario,
              onPressed: _enviando ? null : _compartilhar,
              icon: const Icon(Icons.ios_share),
              label: Text(_enviando ? 'Gerando...' : 'Compartilhar'),
            ),
          ),
        ],
      ),
    );
  }
}
