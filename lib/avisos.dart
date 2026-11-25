import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'state.dart';
import 'telas.dart';
import 'cardio.dart';
import 'desempenho.dart';
import 'edicao.dart';
import 'extras.dart';
import 'nutri_modelo.dart';
import 'nutricao.dart' show PerfilTela;
import 'passos.dart' show AcademiaTela;

class Aviso {
  final IconData icone;
  final String titulo, texto;
  final bool urgente;
  final Widget Function()? destino;
  const Aviso(this.icone, this.titulo, this.texto,
      {this.urgente = false, this.destino});
}

/// Avisos inteligentes do dia, calculados com os dados do app.
List<Aviso> gerarAvisos() {
  final h = DateTime.now();
  final hoje = DateTime(h.year, h.month, h.day);
  final k = chaveData(hoje);
  final out = <Aviso>[];

  // Treino
  final treino = app.treinoNo(hoje);
  final feito = app.feitos.contains(k) || app.fezAtividade(hoje);
  if (treino != null && !feito) {
    out.add(Aviso(
      Icons.fitness_center,
      'Treino de hoje',
      '${treino.nome}${treino.foco.isEmpty ? '' : ' • ${treino.foco}'}. Bora treinar?',
      urgente: true,
      destino: () => TreinoTela(dia: treino, data: hoje),
    ));
  } else if (feito) {
    out.add(const Aviso(Icons.check_circle_outline, 'Treino concluído',
        'Você já treinou hoje. Bom trabalho! 💪'));
  } else {
    out.add(Aviso(Icons.bedtime_outlined, 'Dia de descanso',
        'Sem treino hoje. Que tal um cardio leve?',
        destino: () => const CardioTela()));
  }

  // Semana
  final st = calcular(const Periodo('semana'));
  if (app.plano.isNotEmpty) {
    out.add(Aviso(Icons.calendar_month_outlined, 'Sua semana',
        '${st.completos} de ${app.plano.length} treinos concluídos nesta semana.'));
  }

  // Água
  final ml = app.agua[k] ?? 0;
  final meta = app.metaAgua;
  if (h.hour >= 12 && ml < meta * 0.5) {
    out.add(Aviso(Icons.water_drop_outlined, 'Hidrate-se',
        '$ml de $meta ml hoje. Faltam ${meta - ml} ml.',
        urgente: true));
  } else {
    out.add(Aviso(Icons.water_drop_outlined, 'Água', '$ml de $meta ml hoje.'));
  }

  // Nutrição
  final m = app.metas;
  if (m == null) {
    out.add(Aviso(Icons.restaurant_menu, 'Calcule sua meta',
        'Informe seus dados para o app calcular seu TMB e suas metas.',
        destino: () => const PerfilTela()));
  } else {
    final tot = app.totalDia(k);
    if (tot.kcal == 0 && h.hour >= 10) {
      out.add(const Aviso(Icons.restaurant_menu, 'Registre suas refeições',
          'Você ainda não registrou nada hoje.',
          urgente: true));
    } else {
      final rest = m.kcal - tot.kcal;
      final txt = rest >= 0
          ? 'Faltam ${fmtD(rest)} kcal para a sua meta (${fmtD(tot.kcal)} de ${fmtD(m.kcal)}).'
          : 'Você passou ${fmtD(-rest)} kcal da meta de ${fmtD(m.kcal)} kcal.';
      out.add(Aviso(Icons.restaurant_menu, 'Nutrição', txt));
    }
  }

  // Passos
  if (app.passosAtivo) {
    out.add(Aviso(Icons.directions_walk, 'Passos',
        '${app.passos[k] ?? 0} de ${app.metaPassos} passos hoje.'));
  } else {
    out.add(const Aviso(Icons.directions_walk, 'Passos',
        'Ative a permissão de atividade física para contar seus passos.'));
  }

  // Academia
  if (app.academia == null) {
    out.add(Aviso(Icons.place_outlined, 'Escolha sua academia',
        'Defina onde você treina.',
        destino: () => const AcademiaTela()));
  }
  return out;
}

/// Sininho com bolinha quando há avisos importantes.
class BotaoSino extends StatelessWidget {
  const BotaoSino({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final tem = gerarAvisos().any((a) => a.urgente);
        return IconButton(
          tooltip: 'Avisos',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AvisosTela()),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none),
              if (tem)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFF4D7D), shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class AvisosTela extends StatelessWidget {
  const AvisosTela({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Avisos', style: titulo(28))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final l = gerarAvisos();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              const Text(
                'Resumo inteligente do seu dia. Os avisos importantes aparecem com a barra colorida.',
                style: TextStyle(color: kMudo),
              ),
              const SizedBox(height: 12),
              for (final a in l)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Vidro(
                    padding: const EdgeInsets.all(16),
                    raio: 22,
                    onTap: a.destino == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => a.destino!()),
                            ),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 46,
                          decoration: BoxDecoration(
                            color: a.urgente ? const Color(0xFFFF4D7D) : kAzul,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(a.icone, color: a.urgente ? const Color(0xFFFF4D7D) : kAzul),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(a.texto,
                                  style: const TextStyle(color: kMudo)),
                            ],
                          ),
                        ),
                        if (a.destino != null)
                          const Icon(Icons.chevron_right, color: kMudo),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'Notificações no celular (com o app fechado) ainda não estão ativas.',
                style: TextStyle(color: kMudo, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Menu dos três pontinhos.
Widget menuTresPontos(BuildContext context) {
  void ir(Widget w) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));
  Future<void> copiar(String t, String msg) async {
    await Clipboard.setData(ClipboardData(text: t));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  return PopupMenuButton<String>(
    tooltip: 'Mais opções',
    icon: const Icon(Icons.more_vert),
    onSelected: (v) {
      switch (v) {
        case 'historico':
          ir(const HistoricoTela());
          break;
        case 'plano':
          ir(const MeuPlanoTela());
          break;
        case 'editar':
          ir(const EditarPlanoTela());
          break;
        case 'resumo':
          const p = Periodo('semana');
          final st = calcular(p);
          copiar(
            'Resumo da semana (${p.rotulo})\n'
            'Treinos: ${st.treinos}\n'
            'Séries: ${st.series}\n'
            'Volume: ${st.volume.round()} kg\n'
            'Tempo: ${fmtTempo(st.seg)}',
            'Resumo da semana copiado!',
          );
          break;
        case 'exportar':
          copiar(app.exportar(), 'Dados copiados! Cole em um app de notas.');
          break;
        case 'privacidade':
          ir(const PrivacidadeTela());
          break;
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'historico', child: Text('Histórico de treinos')),
      PopupMenuItem(value: 'plano', child: Text('Meu plano')),
      PopupMenuItem(value: 'editar', child: Text('Editar plano')),
      PopupMenuItem(value: 'resumo', child: Text('Copiar resumo da semana')),
      PopupMenuItem(value: 'exportar', child: Text('Exportar meus dados')),
      PopupMenuItem(value: 'privacidade', child: Text('Privacidade e dados')),
    ],
  );
}
