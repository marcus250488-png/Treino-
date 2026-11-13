import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'state.dart';
import 'telas.dart';
import 'edicao.dart';

// ---------- Utilidades ----------
String _d2(int n) => n.toString().padLeft(2, '0');

String fmtTempo(int s) {
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final x = s % 60;
  return h > 0 ? '$h:${_d2(m)}:${_d2(x)}' : '${_d2(m)}:${_d2(x)}';
}

String fmtDataIso(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_d2(d.day)}/${_d2(d.month)}/${d.year} ${_d2(d.hour)}:${_d2(d.minute)}';
}

String fmtNum(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');

double? lerNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

InputDecoration campo(String rotulo, {String? sufixo}) => InputDecoration(
      labelText: rotulo,
      suffixText: sufixo,
      filled: true,
      fillColor: branco(.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

Widget _resumo(String valor, String rotulo) => Column(
      children: [
        Text(valor, style: titulo(30)),
        Text(rotulo, style: const TextStyle(color: kMudo, fontSize: 12)),
      ],
    );

Future<double?> pedirNumero(BuildContext context, String rotulo,
    {String sufixo = '', String inicial = ''}) {
  return showDialog<double?>(
    context: context,
    builder: (c) =>
        _DialogoNumero(rotulo: rotulo, sufixo: sufixo, inicial: inicial),
  );
}

class _DialogoNumero extends StatefulWidget {
  final String rotulo, sufixo, inicial;
  const _DialogoNumero(
      {required this.rotulo, required this.sufixo, required this.inicial});
  @override
  State<_DialogoNumero> createState() => _DialogoNumeroEstado();
}

class _DialogoNumeroEstado extends State<_DialogoNumero> {
  late final TextEditingController _c;
  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.inicial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rotulo),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: campo(widget.rotulo, sufixo: widget.sufixo),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(context, lerNum(_c.text)),
            child: const Text('Salvar')),
      ],
    );
  }
}

// ---------- Histórico de treinos ----------
class HistoricoTela extends StatelessWidget {
  const HistoricoTela({super.key});

  Future<void> _excluir(BuildContext context, Sessao s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir este treino?'),
        content: Text(
            '${s.dia} • ${fmtDataIso(s.data)}\n\nEle sai do histórico e das estatísticas. Isso não pode ser desfeito.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) await app.excluirSessao(s);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Histórico', style: titulo(28))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final l = app.sessoes.reversed.toList();
          if (l.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum treino registrado ainda. Conclua um treino para ele aparecer aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMudo),
                ),
              ),
            );
          }
          final tempo = l.fold<int>(0, (s, e) => s + e.seg);
          final vol = l.fold<double>(0, (s, e) => s + e.volume);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Vidro(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _resumo('${l.length}', 'treinos'),
                    _resumo(fmtTempo(tempo), 'tempo total'),
                    _resumo('${vol.round()}', 'kg de volume'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final s in l)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Vidro(
                    padding: const EdgeInsets.all(14),
                    raio: 22,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.dia, style: titulo(24)),
                              Text(fmtDataIso(s.data),
                                  style: const TextStyle(color: kMudo)),
                              const SizedBox(height: 4),
                              Text(
                                  '${s.series} de ${s.seriesTotal} séries • ${fmtTempo(s.seg)} • ${s.volume.round()} kg',
                                  style: const TextStyle(color: kMudo)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: s.completo
                                ? kAzul
                                : const Color.fromRGBO(255, 193, 7, .25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(s.completo ? 'Completo' : 'Parcial',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        IconButton(
                          tooltip: 'Excluir treino',
                          onPressed: () => _excluir(context, s),
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Evolução (avaliação física + gráfico) ----------
// ---------- Hábitos (água) ----------
class HabitosTela extends StatelessWidget {
  const HabitosTela({super.key});

  Future<void> _outro(BuildContext context) async {
    final v = await pedirNumero(context, 'Quantidade de água', sufixo: 'ml');
    if (v != null && v > 0) await app.addAgua(DateTime.now(), v.round());
  }

  Future<void> _meta(BuildContext context) async {
    final v = await pedirNumero(context, 'Meta diária de água',
        sufixo: 'ml', inicial: '${app.metaAgua}');
    if (v != null && v >= 500) await app.setMetaAgua(v.round());
  }

  @override
  Widget build(BuildContext context) {
    const letras = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final hoje = DateTime.now();
        final ml = app.agua[chaveData(hoje)] ?? 0;
        final p = (ml / app.metaAgua).clamp(0.0, 1.0).toDouble();
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text('Hábitos', style: titulo(34)),
              const SizedBox(height: 12),
              Vidro(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Água de hoje', style: titulo(26)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _meta(context),
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text('meta ${app.metaAgua} ml'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 170,
                      height: 170,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 170,
                            height: 170,
                            child: CircularProgressIndicator(
                              value: p,
                              strokeWidth: 12,
                              color: kAzul,
                              backgroundColor: branco(.1),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$ml ml', style: titulo(40)),
                              Text('${(p * 100).round()}% da meta',
                                  style: const TextStyle(color: kMudo)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final v in [150, 250, 500]) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: estiloContorno,
                              onPressed: () => app.addAgua(hoje, v),
                              child: Text('+$v'),
                            ),
                          ),
                          if (v != 500) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: estiloContorno,
                            onPressed: () => _outro(context),
                            child: const Text('Outro valor'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: estiloContorno,
                            onPressed: () => app.addAgua(hoje, -250),
                            child: const Text('−250 (corrigir)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Vidro(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Últimos 7 dias', style: titulo(26)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (var i = 6; i >= 0; i--)
                            _barra(hoje.subtract(Duration(days: i)), letras),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _barra(DateTime d, List<String> letras) {
    final ml = app.agua[chaveData(d)] ?? 0;
    final f = (ml / app.metaAgua).clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: 4 + 80 * f,
          decoration: BoxDecoration(
            color: ml >= app.metaAgua ? kAzul : branco(.3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 6),
        Text(letras[d.weekday % 7],
            style: const TextStyle(color: kMudo, fontSize: 12)),
      ],
    );
  }
}

// ---------- Mais ----------
class MaisTela extends StatelessWidget {
  final void Function(int) irPara;
  const MaisTela({super.key, required this.irPara});

  Widget _item(IconData i, String t, String sub, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: branco(.06),
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: Icon(i, color: kAzul),
          title: Text(t),
          subtitle: Text(sub, style: const TextStyle(color: kMudo)),
          trailing: const Icon(Icons.chevron_right, color: kMudo),
          onTap: onTap,
        ),
      ),
    );
  }

  void _abrir(BuildContext context, Widget w) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Future<void> _sair(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sair da conta Google?'),
        content: const Text('Seus treinos e registros continuam no celular.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sair')),
        ],
      ),
    );
    if (ok == true) await app.sair();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text('Mais', style: titulo(34)),
              const SizedBox(height: 12),
              _item(Icons.add_circle_outline, 'Treino livre',
                  'Monte e faça um treino fora do plano',
                  () => _abrir(context, const TreinoLivreTela())),
              _item(Icons.edit_outlined, 'Editar plano de treino',
                  'Trocar, reordenar e excluir exercícios',
                  () => _abrir(context, const EditarPlanoTela())),
              _item(Icons.history, 'Histórico de treinos',
                  '${app.sessoes.length} treino(s) registrado(s)',
                  () => _abrir(context, const HistoricoTela())),
              _item(Icons.picture_as_pdf_outlined, 'Importar treino (PDF)',
                  'Atualize sua ficha de treino',
                  () => abrirImportar(context, irPara)),
              _item(Icons.tune, 'Configurações', 'Descanso entre séries',
                  () => _abrir(context, const ConfigTela())),
              _item(Icons.privacy_tip_outlined, 'Privacidade e dados',
                  'O que fica salvo e exportação',
                  () => _abrir(context, const PrivacidadeTela())),
              if (app.logado)
                _item(Icons.logout, 'Sair da conta Google', app.email ?? '',
                    () => _sair(context))
              else
                _item(Icons.login, 'Entrar com Google',
                    'Mostrar sua foto e seu nome', () async {
                  final msg = ScaffoldMessenger.of(context);
                  final e = await app.entrar();
                  if (e != null) msg.showSnackBar(SnackBar(content: Text(e)));
                }),
            ],
          ),
        );
      },
    );
  }
}

class ConfigTela extends StatelessWidget {
  const ConfigTela({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configurações', style: titulo(28))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Vidro(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Descanso entre séries', style: titulo(26)),
                  const SizedBox(height: 4),
                  Text('${app.descanso} segundos',
                      style: const TextStyle(color: kMudo)),
                  Slider(
                    min: 30,
                    max: 180,
                    divisions: 10,
                    value: app.descanso.toDouble().clamp(30.0, 180.0),
                    onChanged: (v) => app.setDescanso(v.round()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacidadeTela extends StatelessWidget {
  const PrivacidadeTela({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Privacidade e dados', style: titulo(28))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Vidro(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('O que fica salvo',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Seu treino importado, histórico de treinos, avaliações físicas, água, cargas e anotações ficam somente neste celular. Nada é enviado para servidores.',
                  style: TextStyle(color: kMudo),
                ),
                SizedBox(height: 14),
                Text('Conta Google',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Usada só para mostrar seu nome, e-mail e foto no app. O login é opcional.',
                  style: TextStyle(color: kMudo),
                ),
                SizedBox(height: 14),
                Text('Dados de saúde',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'Peso e medidas são opcionais e servem só para acompanhar sua evolução. O app não faz diagnóstico médico.',
                  style: TextStyle(color: kMudo),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: estiloPrimario,
            onPressed: () async {
              final msg = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: app.exportar()));
              msg.showSnackBar(const SnackBar(
                  content: Text(
                      'Dados copiados (JSON). Cole em um app de notas para guardar.')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Exportar meus dados'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Meu Plano de Treino (detalhes)
// ============================================================
class MeuPlanoTela extends StatelessWidget {
  const MeuPlanoTela({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final totalTreinos = app.sessoes.where((s) => s.completo).length;
        final totalPlano = app.plano.isEmpty ? 5 * 5 : app.plano.length * 5; // 5 semanas
        final pct = totalPlano == 0 ? 0.0 : (totalTreinos / totalPlano).clamp(0.0, 1.0);
        final diasAtivos = app.feitos.length;
        final frequencia = app.plano.length;

        // A jornada começa na segunda-feira da primeira semana registrada.
        final datasRegistradas = app.feitos
            .map(dataDaChave)
            .whereType<DateTime>()
            .toList()
          ..sort();
        final referencia = app.inicioPlano ??
            (datasRegistradas.isEmpty ? DateTime.now() : datasRegistradas.first);
        final inicioJornada = DateTime(
          referencia.year,
          referencia.month,
          referencia.day,
        ).subtract(Duration(days: referencia.weekday - 1));
        final semanaAtual = (DateTime.now().difference(inicioJornada).inDays ~/ 7 + 1)
            .clamp(1, 5).toInt();
        final semanas = List.generate(5, (i) {
          final ini = inicioJornada.add(Duration(days: i * 7));
          final fim = ini.add(const Duration(days: 7));
          return app.feitos.where((k) {
            final d = dataDaChave(k);
            return d != null && !d.isBefore(ini) && d.isBefore(fim);
          }).length;
        });

        return Scaffold(
          appBar: AppBar(
            title: Text('Meu plano', style: titulo(28)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // Boas-vindas
              Vidro(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.primeiroNome.isEmpty
                          ? 'Bem-vindo ao seu plano de treino!'
                          : 'Bem-vindo ao seu plano de treino, ${app.primeiroNome}!',
                      style: titulo(26),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Você irá visualizar todas as informações sobre seu programa. Ele terá duração total de 30 dias e foi criado para ajudar você a alcançar seu objetivo principal.',
                      style: TextStyle(color: kMudo, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _infoChip(Icons.fitness_center, '$frequencia Treinos', 'Por semana')),
                        const SizedBox(width: 10),
                        Expanded(child: _infoChip(Icons.location_on_outlined, 'Academia', 'Local')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _infoChip(Icons.timer_outlined, '5 Semanas', 'Duração')),
                        const SizedBox(width: 10),
                        Expanded(child: _infoChip(Icons.trending_up, 'Iniciante', 'Nível')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: estiloContorno,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditarPlanoTela()),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Editar meu plano de treino'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Jornada
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0050E6), Color(0xFF1A6CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sua jornada de 5 semanas',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: Colors.white)),
                          SizedBox(height: 6),
                          Text(
                            'É aqui onde tudo começa! Você visualizará quais dias têm treinos, dias de descanso e quantos treinos já foram realizados.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('🚀', style: TextStyle(fontSize: 42)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Progresso geral
              Vidro(
                child: Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 90,
                                height: 90,
                                child: CircularProgressIndicator(
                                  value: pct,
                                  strokeWidth: 9,
                                  color: kAzul,
                                  backgroundColor: branco(.12),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${(pct * 100).round()}%', style: titulo(22)),
                                  const Text('Concluído',
                                      style: TextStyle(color: kMudo, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Treinos realizados', style: titulo(20)),
                              Text('$totalTreinos de $totalPlano',
                                  style: const TextStyle(color: kMudo)),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  color: kAzul,
                                  backgroundColor: branco(.12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _miniStat('Frequência', '${frequencia}x sem'),
                                  _miniStat('Dias ativos', '$diasAtivos'),
                                  _miniStat('Recorde', '${diasAtivos > 0 ? diasAtivos : 0} dias'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Semanas
              Text('Sua jornada', style: titulo(26)),
              const SizedBox(height: 12),
              for (var s = 1; s <= 5; s++) ...[
                _semanaCard(context, s, s == semanaAtual, semanas[s - 1].clamp(0, 5)),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String title, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: branco(.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: kAzul, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(sub, style: const TextStyle(color: kMudo, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(label, style: const TextStyle(color: kMudo, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _semanaCard(BuildContext context, int num, bool atual, int feitos) {
    final total = app.plano.isEmpty ? 5 : app.plano.length;
    final registradas = app.feitos.map(dataDaChave).whereType<DateTime>().toList()..sort();
    final referencia = app.inicioPlano ??
        (registradas.isEmpty ? DateTime.now() : registradas.first);
    final inicio = DateTime(referencia.year, referencia.month, referencia.day)
        .subtract(Duration(days: referencia.weekday - 1))
        .add(Duration(days: (num - 1) * 7));
    final dias = List.generate(7, (i) => inicio.add(Duration(days: i)));
    const nomes = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Container(
      decoration: BoxDecoration(
        color: branco(.065),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: atual ? kAzul : branco(.13), width: atual ? 1.6 : 1),
        boxShadow: atual
            ? [BoxShadow(color: kAzul.withOpacity(.12), blurRadius: 18, spreadRadius: 1)]
            : const [],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('jornada-semana-$num'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          maintainState: true,
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: feitos >= total && total > 0 ? kAzul : branco(.10),
              border: Border.all(color: kAzul, width: 1.8),
            ),
            child: Text('$num', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          title: Row(
            children: [
              Text('Semana $num', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (atual) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: kAzul, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Em andamento', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          subtitle: Text('$feitos/$total treinos realizados', style: const TextStyle(color: kMudo, fontSize: 12)),
          trailing: Icon(feitos >= total && total > 0 ? Icons.check_circle : Icons.keyboard_arrow_down_rounded,
              color: feitos >= total && total > 0 ? kAzul : kMudo),
          children: [
            const Divider(color: Colors.white12, height: 12),
            for (var i = 0; i < dias.length; i++)
              _linhaDiaJornada(context, dias[i], nomes[i]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${_dataCurta(inicio)} – ${_dataCurta(inicio.add(const Duration(days: 6)))}',
                  style: const TextStyle(color: kMudo, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaDiaJornada(BuildContext context, DateTime data, String nome) {
    final treino = app.treinoNo(data);
    final concluido = app.feitos.contains(chaveData(data));
    final hoje = DateUtils.isSameDay(data, DateTime.now());
    final tituloDia = treino?.nome ?? 'Dia de descanso';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(color: hoje ? kAzul.withOpacity(.22) : branco(.06), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(nome, style: const TextStyle(color: kMudo, fontSize: 10)),
              Text('${data.day}', style: TextStyle(fontWeight: FontWeight.w800, color: hoje ? Colors.white : kMudo)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tituloDia, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(treino == null ? 'Recuperação e descanso' : (treino.foco.isEmpty ? '${treino.itens.length} exercícios' : treino.foco),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMudo, fontSize: 11)),
            ]),
          ),
          if (concluido)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF28C76F), size: 21)
          else if (treino != null)
            IconButton(
              tooltip: 'Abrir treino',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TreinoTela(dia: treino))),
              icon: const Icon(Icons.play_circle_fill_rounded, color: kAzul, size: 25),
            )
          else
            const Icon(Icons.bedtime_outlined, color: kMudo, size: 19),
        ],
      ),
    );
  }

  String _dataCurta(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
