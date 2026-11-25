import 'dart:ui';
import 'package:flutter/material.dart';
import 'state.dart';
const _coachAzul = Color(0xFF0050E6);
const _coachMudo = Color(0xFFA1A1A6);
TextStyle _coachTitulo(double size) => TextStyle(
  fontSize: size, fontWeight: FontWeight.w800, color: Colors.white,
);

/// Atalho animado do treinador adaptativo na capa do treino do dia.
class CoachIaBotao extends StatefulWidget {
  final Dia dia;
  final DateTime data;
  const CoachIaBotao({super.key, required this.dia, required this.data});

  @override
  State<CoachIaBotao> createState() => _CoachIaBotaoState();
}

class _CoachIaBotaoState extends State<CoachIaBotao>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _abrir() {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Fechar Coach IA',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(.72),
      transitionDuration: const Duration(milliseconds: 620),
      pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
        child: _CoachPainel(dia: widget.dia, data: widget.data),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curva = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 9 * animation.value,
            sigmaY: 9 * animation.value,
          ),
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .10),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: ScaleTransition(
                scale: Tween<double>(begin: .68, end: 1).animate(curva),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return GestureDetector(
          onTap: _abrir,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.all(3 + 2 * t),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1677FF).withOpacity(.18 + .25 * t),
                  blurRadius: 10 + 13 * t,
                  spreadRadius: 1 + 2 * t,
                ),
              ],
            ),
            child: Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xE6101B31),
                border: Border.all(
                  color: Color.lerp(const Color(0xFF347EFF),
                      Colors.white, .18 * t)!,
                  width: 1.15,
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF79B5FF), size: 25),
            ),
          ),
        );
      },
    );
  }
}

class _CoachPainel extends StatelessWidget {
  final Dia dia;
  final DateTime data;
  const _CoachPainel({required this.dia, required this.data});

  String _normalizar(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  List<Map<String, dynamic>> _ultimosDados(Item item) {
    final nome = _normalizar(item.nome);
    final candidatos = app.sessoes
        .where((s) => s.completo && !s.cardio && s.detalhes != null)
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    for (final sessao in candidatos) {
      for (final detalhe in sessao.detalhes!) {
        if (_normalizar('${detalhe['nome'] ?? ''}') == nome) {
          final cargas = ((detalhe['cargas'] as List?) ?? const [])
              .whereType<num>()
              .map((v) => v.toDouble())
              .toList();
          if (cargas.isNotEmpty) {
            return [
              {
                'cargas': cargas,
                'data': sessao.data,
                'rpe': (detalhe['rpe'] ?? '').toString(),
              }
            ];
          }
        }
      }
    }
    return const [];
  }

  String _dataCurta(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return 'data não disponível';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  Widget _linhaExercicio(Item item, int index) {
    final dados = _ultimosDados(item);
    final nome = item.nome;
    final cargas = dados.isEmpty
        ? <double>[]
        : (dados.first['cargas'] as List<double>);
    final rpe = dados.isEmpty ? '' : (dados.first['rpe'] as String);
    final ultimaCarga = cargas.isEmpty ? null : cargas.last;
    final cargaTexto = ultimaCarga == null
        ? 'Sem carga registrada ainda'
        : 'Última carga: ${ultimaCarga.toStringAsFixed(
            ultimaCarga == ultimaCarga.roundToDouble() ? 0 : 1
          ).replaceAll('.', ',')} kg';
    return TweenAnimationBuilder<double>(
      key: ValueKey('${item.exId}-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 75),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.09)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _coachAzul.withOpacity(.18),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.fitness_center,
                  color: Color(0xFF75B2FF), size: 18),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    dados.isEmpty
                        ? '$cargaTexto • ${item.series} séries • ${item.reps}'
                        : '$cargaTexto • ${_dataCurta(dados.first['data'] as String)}',
                    style: const TextStyle(color: _coachMudo, fontSize: 12),
                  ),
                  if (rpe.isNotEmpty)
                    Text('Esforço registrado: $rpe',
                        style: const TextStyle(
                            color: Color(0xFF8CBFFF), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataLabel =
        '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.of(context).size.height * .88,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF142746), Color(0xFF17191F), Color(0xFF21151F)],
            ),
            border: Border.all(color: const Color(0xFF4A83E8).withOpacity(.55)),
            boxShadow: [
              BoxShadow(
                color: _coachAzul.withOpacity(.28),
                blurRadius: 35,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(29),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.28),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _coachAzul.withOpacity(.20),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                              color: const Color(0xFF5594FF), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                                color: _coachAzul.withOpacity(.3), blurRadius: 18)
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Color(0xFF8BC0FF), size: 29),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Seu treino de hoje', style: _coachTitulo(27)),
                            const Text('Coach IA • orientação de progressão',
                                style: TextStyle(color: _coachMudo, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.07),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dia.foco.isEmpty ? dia.nome : dia.foco,
                            style: _coachTitulo(23)),
                        const SizedBox(height: 4),
                        Text('$dataLabel • ${dia.itens.length} exercícios • '
                            '${dia.itens.fold<int>(0, (n, e) => n + e.series)} séries',
                            style: const TextStyle(color: _coachMudo, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: const [
                      Icon(Icons.insights_rounded,
                          color: Color(0xFF69A8FF), size: 21),
                      SizedBox(width: 8),
                      Text('Seu histórico e suas cargas',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (dia.itens.isEmpty)
                    const Text('Este treino ainda não tem exercícios cadastrados.',
                        style: TextStyle(color: _coachMudo))
                  else
                    ...dia.itens.asMap().entries.map(
                        (e) => _linhaExercicio(e.value, e.key)),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _coachAzul.withOpacity(.16),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                          color: const Color(0xFF438AFF).withOpacity(.7)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.trending_up_rounded,
                            color: Color(0xFF70B2FF), size: 25),
                        SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Seu lembrete de progressão',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              SizedBox(height: 5),
                              Text(
                                'Se você completar todas as séries dentro da faixa planejada, com boa técnica e sem precisar forçar além do necessário, considere aumentar um pequeno passo na próxima sessão. Se a execução piorar, mantenha a carga.',
                                style: TextStyle(
                                    color: Color(0xFFD2DDF0),
                                    height: 1.4,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'As cargas exibidas vêm dos seus treinos salvos. O Coach IA não inventa pesos nem altera seu plano automaticamente.',
                    style: TextStyle(color: _coachMudo, fontSize: 11, height: 1.35),
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
