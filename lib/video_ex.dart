import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'state.dart';
import 'telas.dart';

/// Vídeos de execução ficam em assets/videos/<id-do-exercicio>.mp4
/// (conta feminina usa f_<id>.mp4 se existir). Sem arquivo = sem vídeo.
Future<Set<String>>? _carregando;

Future<Set<String>> _idsComVideo() {
  _carregando ??= AssetManifest.loadFromAssetBundle(rootBundle).then((m) => m
      .listAssets()
      .where((a) => a.startsWith('assets/videos/') && a.endsWith('.mp4'))
      .map((a) => a.substring(14, a.length - 4))
      .toSet());
  return _carregando!;
}

/// Caminho do vídeo do exercício, ou null se não existir.
/// Se o id do treino não tiver vídeo (ex.: exercício criado a partir do PDF),
/// procura na biblioteca um exercício com o mesmo nome que tenha vídeo.
String? _arquivoVideo(String exId, Set<String> ids, [String nome = '']) {
  var id = exId;
  if (!ids.contains(id) && !ids.contains('f_$id') && nome.isNotEmpty) {
    final n = norm(nome);
    for (final e in app.lib) {
      if (norm(e.nome) == n && (ids.contains(e.id) || ids.contains('f_${e.id}'))) {
        id = e.id;
        break;
      }
    }
  }
  if (app.fotosFemininas && ids.contains('f_$id')) {
    return 'assets/videos/f_$id.mp4';
  }
  if (ids.contains(id)) return 'assets/videos/$id.mp4';
  return null;
}

/// Vídeo do exercício: toca sozinho, sem som e em loop. Toque pausa/retoma.
class VideoExercicio extends StatelessWidget {
  final String exId, nome;
  final double altura, abaixo;
  const VideoExercicio(
      {super.key,
      required this.exId,
      this.nome = '',
      this.altura = 260,
      this.abaixo = 0});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: _idsComVideo(),
      builder: (context, snap) {
        final ids = snap.data;
        if (ids == null) return const SizedBox.shrink();
        final arq = _arquivoVideo(exId, ids, nome);
        if (arq == null) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: abaixo),
          child: _PlayerLoop(key: ValueKey(arq), arquivo: arq, altura: altura),
        );
      },
    );
  }
}

class _PlayerLoop extends StatefulWidget {
  final String arquivo;
  final double altura;
  const _PlayerLoop({super.key, required this.arquivo, required this.altura});
  @override
  State<_PlayerLoop> createState() => _PlayerLoopEstado();
}

class _PlayerLoopEstado extends State<_PlayerLoop> {
  late final VideoPlayerController _c;
  bool _pronto = false, _erro = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.asset(
      widget.arquivo,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _c.initialize().then((_) async {
      await _c.setLooping(true);
      await _c.setVolume(0);
      await _c.play();
      if (mounted) setState(() => _pronto = true);
    }).catchError((_) {
      if (mounted) setState(() => _erro = true);
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_erro) return const SizedBox.shrink();
    if (!_pronto) {
      return Container(
        height: widget.altura,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final tocando = _c.value.isPlaying;
    // Tamanho padrão: quadrado, qualquer vídeo é recortado (cover) para caber.
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.altura),
        child: AspectRatio(
          aspectRatio: 1,
          child: GestureDetector(
            onTap: () => tocando ? _c.pause() : _c.play(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _c.value.size.width,
                      height: _c.value.size.height,
                      child: VideoPlayer(_c),
                    ),
                  ),
                  if (!tocando)
                    Container(
                      color: Colors.black38,
                      child: const Icon(Icons.play_arrow_rounded,
                          size: 64, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão pequeno "Ver execução" (só aparece se o exercício tem vídeo).
class BotaoVerExecucao extends StatelessWidget {
  final String exId, nome;
  const BotaoVerExecucao({super.key, required this.exId, required this.nome});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: _idsComVideo(),
      builder: (context, snap) {
        final ids = snap.data;
        if (ids == null || _arquivoVideo(exId, ids, nome) == null) {
          return const SizedBox.shrink();
        }
        return OutlinedButton.icon(
          style: estiloContornoMini,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: kSuperf,
            builder: (c) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: titulo(28)),
                    const SizedBox(height: 14),
                    VideoExercicio(exId: exId, nome: nome, altura: 420),
                  ],
                ),
              ),
            ),
          ),
          icon: const Icon(Icons.play_circle_outline, size: 16),
          label: const Text('Ver execução'),
        );
      },
    );
  }
}
