import 'package:flutter/material.dart';
import 'state.dart';
import 'telas.dart';

const _verde = Color(0xFF30D158);
const _verdeFundo = Color(0xFF1B3A2A);

const _diasSemana = [
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
  'Domingo',
];
const _meses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// Barra de experiência com animação. [clara] = versão para fundo azul.
Widget barraXp(double v, {bool clara = false}) {
  final alvo = v.isNaN ? 0.0 : v.clamp(0.0, 1.0).toDouble();
  return TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: alvo),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (_, t, __) => Container(
      height: 12,
      decoration: BoxDecoration(
        color: clara ? branco(.22) : branco(.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: t,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: clara
                    ? [branco(.55), Colors.white]
                    : const [Color(0xFF1B2F6B), kAzul],
              ),
              // Sem contorno: preenchimento animado com gradiente.
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _pilulaNivel(int nivel, {Color? fundo}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: fundo ?? kAzul,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text('Nível $nivel',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
    );

/// Abre a caixa do dia e mostra o prêmio.
Future<void> abrirCaixaDoDia(BuildContext context) async {
  final dia = app.diaDaCaixa;
  final nivelAntes = nivelDoXp(app.xpTotal)[0];
  final xp = await app.abrirCaixa();
  if (xp == 0 || !context.mounted) return;
  final nivelDepois = nivelDoXp(app.xpTotal)[0];
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: kSuperf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 84,
            height: 84,
            decoration:
                const BoxDecoration(color: _verdeFundo, shape: BoxShape.circle),
            child: const Icon(Icons.card_giftcard, color: _verde, size: 42),
          ),
          const SizedBox(height: 16),
          Text('+$xp XP', style: titulo(52)),
          const SizedBox(height: 4),
          Text('Recompensa do dia $dia',
              style: const TextStyle(color: kMudo, fontSize: 15)),
          if (nivelDepois > nivelAntes) ...[
            const SizedBox(height: 14),
            _pilulaNivel(nivelDepois),
            const SizedBox(height: 6),
            const Text('Nível novo!',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Volte amanhã: o prêmio do dia ${dia + 1} é de ${app.premioDaCaixa(dia + 1)} XP.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMudo, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kAzul,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.pop(c),
              child: const Text('Show!'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Cartão "Nível do atleta" da tela Início.
class XpCard extends StatelessWidget {
  const XpCard({super.key});

  @override
  Widget build(BuildContext context) {
    final n = nivelDoXp(app.xpTotal);
    final nivel = n[0], xp = n[1], meta = n[2];
    final caixa = app.caixaDisponivel;
    return Material(
      color: branco(.07),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const XpTela()),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: branco(.14)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_outlined, color: kMudo, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Nível do atleta', style: titulo(26))),
                  _pilulaNivel(nivel),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right, color: kAzul),
                ],
              ),
              const SizedBox(height: 16),
              barraXp(meta == 0 ? 0 : xp / meta),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Experiência',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  Text('$xp/$meta XP',
                      style: const TextStyle(color: kMudo, fontSize: 15)),
                ],
              ),
              if (caixa) ...[
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => abrirCaixaDoDia(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _verdeFundo.withOpacity(.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard, color: _verde),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Caixa do dia disponível',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text('+${app.premioDaCaixa(app.diaDaCaixa)} XP',
                            style: const TextStyle(
                                color: _verde, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Histórico de XP: total, nível, missão da semana e eventos por dia.
class XpTela extends StatelessWidget {
  const XpTela({super.key});

  static String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _dataExtensa(DateTime d) =>
      '${_diasSemana[d.weekday - 1]}, ${d.day} ${_meses[d.month - 1]}';

  static IconData _icone(String tipo) {
    switch (tipo) {
      case 'treino':
        return Icons.fitness_center;
      case 'cardio':
        return Icons.directions_run;
      case 'missao':
        return Icons.track_changes;
      case 'caixa':
        return Icons.card_giftcard;
      case 'agua':
        return Icons.water_drop_outlined;
      case 'peso':
        return Icons.monitor_weight_outlined;
      case 'passos':
        return Icons.directions_walk;
      default:
        return Icons.bolt;
    }
  }

  static bool _destaque(String tipo) =>
      tipo == 'treino' ||
      tipo == 'cardio' ||
      tipo == 'missao' ||
      tipo == 'caixa';

  Widget _topo(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Material(
              color: kSuperf,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.chevron_left, size: 30),
                ),
              ),
            ),
            Expanded(
              child: Center(child: Text('Histórico de XP', style: titulo(30))),
            ),
            const SizedBox(width: 52),
          ],
        ),
      );

  Widget _resumo() {
    final n = nivelDoXp(app.xpTotal);
    final nivel = n[0], xp = n[1], meta = n[2];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0050E6), Color(0xFF002A80)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.bolt_outlined, color: Colors.white, size: 38),
              const SizedBox(width: 6),
              Text('${app.xpTotal}', style: titulo(68)),
              const Spacer(),
              _pilulaNivel(nivel, fundo: const Color(0xFF020B26)),
            ],
          ),
          Text('XP acumulado',
              style: TextStyle(color: branco(.85), fontSize: 17)),
          const SizedBox(height: 16),
          barraXp(meta == 0 ? 0 : xp / meta, clara: true),
          const SizedBox(height: 12),
          Text('$xp/$meta XP',
              style: TextStyle(color: branco(.85), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _missao() {
    final feitos = app.treinosNaSemana();
    final ok = app.missaoSemanalFeita;
    final prog = (feitos / kMissaoTreinos).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSuperf,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: _verdeFundo, shape: BoxShape.circle),
                child: const Icon(Icons.track_changes, color: _verde),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Missão semanal',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Treine ${kMissaoTreinos}x esta semana',
                        style: const TextStyle(color: kMudo, fontSize: 13)),
                  ],
                ),
              ),
              if (ok)
                const Icon(Icons.check_circle, color: _verde)
              else
                Text('+$kXpMissao XP',
                    style: const TextStyle(
                        color: _verde,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ok ? 1.0 : prog,
              minHeight: 8,
              color: _verde,
              backgroundColor: branco(.1),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              ok
                  ? 'Concluída esta semana'
                  : '${feitos > kMissaoTreinos ? kMissaoTreinos : feitos} de $kMissaoTreinos treinos',
              style: const TextStyle(color: kMudo, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linha(Map<String, dynamic> e, DateTime ts) {
    final tipo = '${e['tipo']}';
    final destaque = _destaque(tipo);
    final sub = '${e['sub'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: destaque ? _verdeFundo : branco(.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_icone(tipo),
                color: destaque ? _verde : branco(.8), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e['titulo']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(sub.isEmpty ? _hora(ts) : '${_hora(ts)} · $sub',
                    style: const TextStyle(color: kMudo, fontSize: 13)),
              ],
            ),
          ),
          Text('+${e['xp']}',
              style: titulo(26).copyWith(color: _verde)),
        ],
      ),
    );
  }

  Widget _comoGanhar() {
    Widget l(String t, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(t, style: const TextStyle(fontSize: 14))),
              Text(v,
                  style: const TextStyle(
                      color: _verde, fontWeight: FontWeight.w700)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: kSuperf,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Como ganhar XP', style: titulo(24)),
          const SizedBox(height: 6),
          l('Treino concluído (1 por dia)', '+$kXpTreino'),
          l('Cardio concluído (1 por dia)', '+$kXpCardio'),
          l('Missão semanal: treinar ${kMissaoTreinos}x', '+$kXpMissao'),
          l('Caixa do dia (cresce com a sequência)',
              '+${kXpCaixa.first} a +${kXpCaixa.last}'),
          l('Meta de passos batida', '+$kXpPassos'),
          l('Registrar água', '+$kXpAgua'),
          l('Atualizar o peso', '+$kXpPeso'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            // Agrupa por dia (mais recente primeiro).
            final itens = <MapEntry<DateTime, Map<String, dynamic>>>[];
            for (final e in app.xpLog) {
              final ts = DateTime.tryParse('${e['ts']}');
              if (ts != null) itens.add(MapEntry(ts, e));
            }
            itens.sort((a, b) => b.key.compareTo(a.key));
            final grupos = <String, List<MapEntry<DateTime, Map<String, dynamic>>>>{};
            for (final it in itens) {
              grupos.putIfAbsent(chaveData(it.key), () => []).add(it);
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _topo(context),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _resumo(),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _missao(),
                ),
                if (app.caixaDisponivel) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      style: estiloPrimario,
                      onPressed: () => abrirCaixaDoDia(context),
                      icon: const Icon(Icons.card_giftcard),
                      label: Text(
                          'Abrir caixa do dia  +${app.premioDaCaixa(app.diaDaCaixa)} XP'),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                if (grupos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kSuperf,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Ainda sem XP. Conclua um treino, registre água ou atualize o peso para começar a subir de nível.',
                        style: TextStyle(color: kMudo, height: 1.4),
                      ),
                    ),
                  )
                else
                  for (final g in grupos.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_dataExtensa(g.first.key),
                                style: titulo(24)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _verde,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '+${g.fold<int>(0, (t, x) => t + ((x.value['xp'] as num?)?.toInt() ?? 0))} XP',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: kSuperf,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < g.length; i++) ...[
                              if (i > 0)
                                Divider(height: 1, color: branco(.08)),
                              _linha(g[i].value, g[i].key),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _comoGanhar(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
