import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'state.dart';
import 'telas.dart';
import 'nutri_modelo.dart';
import 'dart:async';
import 'busca_alimentos.dart';
import 'onda_agua.dart';

double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

const _corProt = Color(0xFF4C8DFF);
const _corCarb = Color(0xFFFFB020);
const _corGord = Color(0xFFFF4D7D);
const _letras = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

/// Retângulo selecionável com borda fina (mesmo estilo dos cartões).
class _Pill extends StatelessWidget {
  final String texto;
  final bool sel;
  final bool expandir;
  final VoidCallback onTap;
  const _Pill(
      {required this.texto,
      required this.sel,
      required this.onTap,
      this.expandir = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            vertical: 10, horizontal: expandir ? 2 : 14),
        alignment: expandir ? Alignment.center : null,
        decoration: BoxDecoration(
          color: sel ? kAzul.withOpacity(0.30) : branco(.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? kAzul : branco(.14)),
        ),
        child: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }
}

String _macrosTexto(Macros m) =>
    '${fmtD(m.kcal)} kcal • P ${fmtD(m.p)} • C ${fmtD(m.c)} • G ${fmtD(m.g)}';

Refeicao _refPorId(String id) =>
    kRefeicoes.firstWhere((r) => r.id == id, orElse: () => kRefeicoes.last);

// ============================================================
// Tela principal da aba Nutrição
// ============================================================
class NutricaoTela extends StatefulWidget {
  const NutricaoTela({super.key});
  @override
  State<NutricaoTela> createState() => _NutricaoEstado();
}

class _NutricaoEstado extends State<NutricaoTela> {
  late DateTime _dia;

  @override
  void initState() {
    super.initState();
    final h = DateTime.now();
    _dia = DateTime(h.year, h.month, h.day);
  }

  String get _k => chaveData(_dia);

  void _push(Widget w) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Nutrição', style: titulo(36))),
                  IconButton(
                    tooltip: 'Como a meta é calculada',
                    onPressed: _info,
                    icon: const Icon(Icons.info_outline),
                  ),
                  IconButton(
                    tooltip: 'Meus dados e metas',
                    onPressed: () => _push(const PerfilTela()),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _semana(),
              const SizedBox(height: 14),
              if (app.metas == null) ...[_configurar(), const SizedBox(height: 14)],
              _agua(),
              const SizedBox(height: 14),
              _resumo(),
              const SizedBox(height: 14),
              _alimentacao(),
              const SizedBox(height: 14),
              _receitasCard(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _atalho(Icons.menu_book_outlined, 'Meu cardápio',
                        'Monte suas refeições fixas', const CardapioTela()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _atalho(Icons.egg_alt_outlined, 'Meus alimentos',
                        'Ver e editar macros', const BuscarAlimentoTela()),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _info() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Como a meta é calculada'),
        content: const SingleChildScrollView(
          child: Text(
            'TMB (taxa metabólica basal) é o que o corpo gasta em repouso. '
            'O app usa a fórmula de Mifflin-St Jeor com seu sexo, idade, altura e peso.\n\n'
            'Multiplicando pela sua atividade física, chega-se ao gasto diário. '
            'A meta ajusta esse valor ao seu objetivo: perder gordura (-20%), manter ou ganhar massa (+10%).\n\n'
            'As calorias dos alimentos são aproximadas (tabelas TACO/USDA). '
            'Se o rótulo do seu produto for diferente, edite o alimento em "Meus alimentos" e tudo é recalculado.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Entendi')),
        ],
      ),
    );
  }

  Widget _semana() {
    final h = DateTime.now();
    final hoje = DateTime(h.year, h.month, h.day);
    final seg = hoje.subtract(Duration(days: hoje.weekday - 1));
    final meta = app.metas?.kcal ?? 0;
    return Vidro(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      raio: 26,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(child: _diaSemana(seg.add(Duration(days: i)), meta)),
        ],
      ),
    );
  }

  Widget _diaSemana(DateTime d, double meta) {
    final sel = chaveData(d) == _k;
    final consumido = app.totalDia(chaveData(d)).kcal;
    final prog = meta > 0 ? (consumido / meta).clamp(0.0, 1.0).toDouble() : 0.0;
    final passou = meta > 0 && consumido > meta * 1.05;
    return GestureDetector(
      onTap: () => setState(() => _dia = d),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? kAzul : Colors.transparent,
            ),
            child: Text(_letras[d.weekday - 1],
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : kMudo)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 38,
            height: 38,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: prog,
                    strokeWidth: 4,
                    backgroundColor: branco(.12),
                    color: passou ? _corGord : kAzul,
                  ),
                ),
                Text('${d.day}',
                    style: const TextStyle(fontSize: 11, color: kMudo)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _configurar() {
    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calcule sua meta diária', style: titulo(28)),
          const SizedBox(height: 6),
          const Text(
            'Informe seus dados (sexo, idade, altura, peso e nível de atividade) para o app calcular seu TMB e suas metas de calorias e macros.',
            style: TextStyle(color: kMudo),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: estiloPrimario,
            onPressed: () => _push(const PerfilTela()),
            child: const Text('Informar meus dados'),
          ),
        ],
      ),
    );
  }

  Widget _agua() {
    final ml = app.agua[_k] ?? 0;
    final meta = app.metaAgua;
    final prog = meta > 0 ? (ml / meta).clamp(0.0, 1.0).toDouble() : 0.0;
    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: kAzul),
              const SizedBox(width: 10),
              Text('Consumo de água', style: titulo(26)),
            ],
          ),
          const SizedBox(height: 12),
          Center(child: Text('$ml ml', style: titulo(54))),
          Center(
            child: Text('Meta diária: $meta ml',
                style: const TextStyle(color: kMudo)),
          ),
          const SizedBox(height: 10),
          OndaAgua(prog: prog),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                onPressed: () => app.addAgua(_dia, -250),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: FilledButton.icon(
                  style: estiloPrimario,
                  onPressed: () => app.addAgua(_dia, 250),
                  icon: const Icon(Icons.add),
                  label: const Text('250 ml'),
                ),
              ),
              IconButton(
                onPressed: () => app.addAgua(_dia, 500),
                icon: const Icon(Icons.local_drink_outlined),
                tooltip: '+500 ml',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resumo() {
    final tot = app.totalDia(_k);
    final m = app.metas;
    final gastas = app.kcalGastas(_dia);
    final meta = m?.kcal ?? 0;
    final rest = meta - tot.kcal;
    final passou = meta > 0 && rest < 0;
    final prog = meta > 0 ? (tot.kcal / meta).clamp(0.0, 1.0).toDouble() : 0.0;
    final h = DateTime.now();
    final hoje = DateTime(h.year, h.month, h.day);
    final passado = _dia.isBefore(hoje);
    return Vidro(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_menu, color: kAzul),
              const SizedBox(width: 10),
              Expanded(
                child: Text(passado ? 'Resultado do dia' : 'Resumo nutricional',
                    style: titulo(26)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: 240,
              height: 175,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(240, 175),
                    painter: _ArcoPainter(prog, passou ? _corGord : kAzul),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            meta > 0
                                ? fmtD(rest.abs())
                                : fmtD(tot.kcal),
                            style: titulo(46)),
                        Text(
                            meta > 0
                                ? (passou ? 'kcal acima' : 'kcal restantes')
                                : 'kcal consumidas',
                            style: const TextStyle(color: kMudo)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _mini(fmtD(tot.kcal), 'Consumidas'),
              _mini(meta > 0 ? fmtD(meta) : '--', 'Meta'),
              _mini(fmtD(gastas), 'Gastas (treino)'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(child: _macro('Proteínas', tot.p, m?.p, _corProt)),
                const SizedBox(width: 12),
                Expanded(child: _macro('Carboidratos', tot.c, m?.c, _corCarb)),
                const SizedBox(width: 12),
                Expanded(child: _macro('Gordura', tot.g, m?.g, _corGord)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(_status(tot, m, passado),
              style: const TextStyle(fontSize: 14, height: 1.35)),
        ],
      ),
    );
  }

  String _status(Macros tot, Metas? m, bool passado) {
    if (m == null) {
      return 'Informe seus dados para ver quanto falta ou passou da sua meta.';
    }
    if (tot.kcal == 0) {
      return passado
          ? 'Nada registrado neste dia.'
          : 'Registre suas refeições para acompanhar o dia.';
    }
    final rest = m.kcal - tot.kcal;
    final pRest = m.p - tot.p;
    final prefixo = passado ? 'Fechamento: ' : '';
    if (rest.abs() <= m.kcal * 0.05) {
      return '${prefixo}meta de calorias atingida! 🎯';
    }
    if (rest > 0) {
      final extra = pRest > 5 ? ' Ainda faltam ${fmtD(pRest)} g de proteína.' : '';
      return '${prefixo}faltam ${fmtD(rest)} kcal para a sua meta.$extra';
    }
    return '${prefixo}você passou ${fmtD(-rest)} kcal da meta de ${fmtD(m.kcal)} kcal.';
  }

  Widget _mini(String v, String r) => Column(
        children: [
          Text(v, style: titulo(28)),
          Text(r, style: const TextStyle(color: kMudo, fontSize: 12)),
        ],
      );

  Widget _macro(String nome, double v, double? meta, Color cor) {
    final prog =
        (meta != null && meta > 0) ? (v / meta).clamp(0.0, 1.0).toDouble() : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nome, style: const TextStyle(color: kMudo, fontSize: 12)),
        const SizedBox(height: 4),
        Text('${fmtD(v)}/${meta == null ? '--' : fmtD(meta)}g',
            style: titulo(22)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: prog,
            minHeight: 6,
            backgroundColor: branco(.12),
            color: cor,
          ),
        ),
      ],
    );
  }

  Widget _alimentacao() {
    final metaKcal = app.metas?.kcal ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSuperf, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.apple, color: Colors.white70),
          const SizedBox(width: 10),
          Text('Alimentação', style: titulo(26)),
          const Spacer(),
          Text('Meu cardápio', style: TextStyle(color: kMudo, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        const Text('Prévia sincronizada com as refeições do seu cardápio', style: TextStyle(color: kMudo, fontSize: 12)),
        const SizedBox(height: 14),
        for (final r in kRefeicoes)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: _cartaoRef(r, metaKcal)),
      ]),
    );
  }

  Widget _cartaoRef(Refeicao r, double metaKcal) {
    final itens = app.entradasCardapio(r.id);
    final planejado = app.totalCardapio(r.id);
    final concluida = app.refeicaoConcluida(_k, r.id);
    final consumido = app.totalRef(_k, r.id);
    final alvo = metaKcal * r.pct;
    final txtEscuro = titulo(20).copyWith(color: Colors.black87);
    return Container(
      decoration: BoxDecoration(color: r.cor, borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => _push(RefeicaoTela(refId: r.id, dia: _dia)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.nome, style: txtEscuro),
                if (r.horario.isNotEmpty) Text(r.horario, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                Text('${fmtD(planejado.kcal)} kcal no cardápio • ${itens.length} itens', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ])),
              Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(.45), shape: BoxShape.circle),
                child: Icon(concluida ? Icons.check_rounded : Icons.add, color: Colors.black87)),
            ]),
          ),
        ),
        if (itens.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in itens.take(4))
                Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('• ${app.nomeEntrada(e)}  ·  ${app.qtdEntrada(e)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontSize: 11))),
              if (itens.length > 4) Text('+ ${itens.length - 4} itens', style: const TextStyle(color: Colors.black54, fontSize: 11)),
            ]),
          )
        else
          const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('Nenhum alimento cadastrado no cardápio', style: TextStyle(color: Colors.black54, fontSize: 11))),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            Expanded(child: Text(concluida
              ? 'Registrado hoje • ${fmtD(consumido.kcal)} kcal'
              : 'Meta da refeição: ${fmtD(alvo)} kcal', style: const TextStyle(color: Colors.black54, fontSize: 11))),
            TextButton.icon(
              onPressed: concluida || itens.isEmpty ? null : () async {
                await app.concluirRefeicao(_k, r.id);
              },
              icon: Icon(concluida ? Icons.check_circle : Icons.restaurant, size: 17),
              label: Text(concluida ? 'Já realizada' : 'Já fiz'),
              style: TextButton.styleFrom(foregroundColor: Colors.black87, disabledForegroundColor: Colors.black54, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _receitasCard() {
    return GestureDetector(
      onTap: () => _push(ReceitasTela(dia: _dia)),
      child: Container(
        height: 190,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kSuperf,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              top: 0,
              child: Image.asset(
                'assets/nutri/receitas.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.centerLeft,
                width: 190,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant, color: Colors.white70),
                      const SizedBox(width: 10),
                      Text('Receitas fitness', style: titulo(26)),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(
                    width: 170,
                    child: Text(
                      'Refeições saudáveis e práticas, com macros calculados.',
                      style: TextStyle(color: kMudo, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: kAzul, width: 2),
                    ),
                    child: const Text('Ver receitas'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _atalho(IconData ic, String t, String s, Widget destino) {
    return Vidro(
      padding: const EdgeInsets.all(16),
      raio: 24,
      onTap: () => _push(destino),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ic, color: kAzul),
          const SizedBox(height: 8),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(s, style: const TextStyle(color: kMudo, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ArcoPainter extends CustomPainter {
  final double prog;
  final Color cor;
  _ArcoPainter(this.prog, this.cor);
  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, 110);
    const raio = 100.0;
    final rect = Rect.fromCircle(center: centro, radius: raio);
    const inicio = math.pi * 0.8;
    const total = math.pi * 1.4;
    final fundo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(.12);
    canvas.drawArc(rect, inicio, total, false, fundo);
    if (prog > 0) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..color = cor;
      canvas.drawArc(rect, inicio, total * prog, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcoPainter old) =>
      old.prog != prog || old.cor != cor;
}

// ============================================================
// Uma refeição do dia
// ============================================================
class RefeicaoTela extends StatelessWidget {
  final String refId;
  final DateTime dia;
  const RefeicaoTela({super.key, required this.refId, required this.dia});

  String get _k => chaveData(dia);

  @override
  Widget build(BuildContext context) {
    final r = _refPorId(refId);
    return Scaffold(
      appBar: AppBar(title: Text(r.nome, style: titulo(28))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final entradas = app.entradasDe(_k, refId);
          final tot = app.totalRef(_k, refId);
          final alvo = (app.metas?.kcal ?? 0) * r.pct;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: r.cor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alvo > 0
                          ? '${fmtD(tot.kcal)} de ${fmtD(alvo)} kcal'
                          : '${fmtD(tot.kcal)} kcal',
                      style: titulo(30).copyWith(color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Proteína ${fmtD(tot.p)} g • Carbo ${fmtD(tot.c)} g • Gordura ${fmtD(tot.g)} g',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (entradas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nada registrado aqui ainda. Adicione alimentos, receitas ou use o seu cardápio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMudo),
                  ),
                ),
              for (var i = 0; i < entradas.length; i++)
                _linha(context, entradas[i], i),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: estiloPrimario,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BuscarAlimentoTela(
                      titulo: 'Adicionar em ${r.nome}',
                      onAdd: (e) => app.addEntrada(_k, refId, e),
                    ),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar alimento'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: estiloContorno.copyWith(side: const WidgetStatePropertyAll(BorderSide(color: kAzul, width: 1.2))),
                onPressed: () async {
                  final e = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ReceitasTela(dia: dia, selecionar: true)),
                  );
                  if (e != null) await app.addEntrada(_k, refId, e);
                },
                icon: const Icon(Icons.restaurant),
                label: const Text('Adicionar receita'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: estiloContorno,
                onPressed: app.entradasCardapio(refId).isEmpty
                    ? null
                    : () async {
                        await app.usarCardapio(_k, refId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Cardápio adicionado!')));
                        }
                      },
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(app.entradasCardapio(refId).isEmpty
                    ? 'Usar meu cardápio (vazio)'
                    : 'Usar meu cardápio'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _linha(BuildContext context, Map e, int i) {
    final m = app.macrosEntrada(e);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: branco(.07),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _editarQtd(context, e, i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.nomeEntrada(e),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(app.qtdEntrada(e),
                          style: const TextStyle(color: kMudo, fontSize: 12)),
                      Text(_macrosTexto(m),
                          style: const TextStyle(color: kMudo, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remover',
                  onPressed: () => app.removerEntrada(_k, refId, i),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editarQtd(BuildContext context, Map e, int i) async {
    final q = await pedirQuantidadeEntrada(context, e);
    if (q != null) await app.setQtdEntrada(_k, refId, i, q);
  }
}

/// Pergunta a nova quantidade de uma entrada (alimento em g ou receita em porções).
Future<double?> pedirQuantidadeEntrada(BuildContext context, Map e) async {
  if (e['t'] == 'r') {
    final c = TextEditingController(
        text: fmtD((e['q'] as num).toDouble(), 1));
    final r = await showDialog<double>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Porções'),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantidade de porções'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                final v = _num(c.text);
                Navigator.pop(d, (v != null && v > 0) ? v : null);
              },
              child: const Text('Salvar')),
        ],
      ),
    );
    return r;
  }
  final a = app.alimento(e['id'] as String);
  if (a == null) return null;
  return pedirQuantidade(context, a, inicial: (e['q'] as num).toDouble());
}

// ============================================================
// Quantidade de um alimento (gramas ou unidade)
// ============================================================
Future<double?> pedirQuantidade(BuildContext context, Alimento a,
    {double? inicial}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _QtdDialog(a: a, inicial: inicial),
  );
}

class _QtdDialog extends StatefulWidget {
  final Alimento a;
  final double? inicial;
  const _QtdDialog({required this.a, this.inicial});
  @override
  State<_QtdDialog> createState() => _QtdEstado();
}

class _QtdEstado extends State<_QtdDialog> {
  bool _un = false;
  late final TextEditingController _c;

  bool get _temUn => widget.a.ug > 0 && widget.a.un.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(
        text: widget.inicial != null ? fmtD(widget.inicial!, 1) : '100');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _gramas {
    final v = _num(_c.text) ?? 0;
    return _un ? v * widget.a.ug : v;
  }

  void _alternar(bool un) {
    final v = _num(_c.text) ?? 0;
    setState(() {
      if (un && !_un) {
        _c.text = fmtD(v / widget.a.ug, 1);
      } else if (!un && _un) {
        _c.text = fmtD(v * widget.a.ug, 1);
      }
      _un = un;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final m = a.porGramas(_gramas);
    return AlertDialog(
      title: Text(a.nome),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_temUn)
            Wrap(
              spacing: 8,
              children: [
                _Pill(
                    texto: 'Gramas',
                    sel: !_un,
                    onTap: () => _alternar(false)),
                _Pill(texto: a.un, sel: _un, onTap: () => _alternar(true)),
              ],
            ),
          TextField(
            controller: _c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: _un ? 'Quantidade (${a.un})' : 'Quantidade (g)'),
          ),
          const SizedBox(height: 12),
          Text('${fmtD(_gramas)} g', style: const TextStyle(color: kMudo)),
          Text(_macrosTexto(m),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            final g = _gramas;
            Navigator.pop(context, g > 0 ? g : null);
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

// ============================================================
// Buscar / gerenciar alimentos
// ============================================================
class BuscarAlimentoTela extends StatefulWidget {
  final String titulo;
  final void Function(Map<String, dynamic>)? onAdd;
  const BuscarAlimentoTela({super.key, this.titulo = 'Meus alimentos', this.onAdd});
  @override
  State<BuscarAlimentoTela> createState() => _BuscarEstado();
}

class _BuscarEstado extends State<BuscarAlimentoTela> {
  String q = '';
  String filtro = 'Todos';

  String _categoria(Alimento a) {
    final n = norm(a.nome);
    if (['banana','maca','maçã','pera','laranja','mamao','mamão','manga','uva','morango','abacaxi','abacate','melancia','melão','kiwi','goiaba','acerola','coco'].any((x) => n.contains(norm(x)))) return 'Frutas';
    if (a.p >= a.c && a.p >= a.g) return 'Proteínas';
    if (a.g >= a.p && a.g >= a.c) return 'Gorduras';
    return 'Carboidratos';
  }

  List<Alimento> _filtrar() {
    final n = norm(q);
    final l = app.alimentos
        .where((a) => (n.isEmpty || norm(a.nome).contains(n)) && (filtro == 'Todos' || _categoria(a) == filtro))
        .toList();
    l.sort((a, b) => norm(a.nome).compareTo(norm(b.nome)));
    return l;
  }

  Future<void> _novo() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AlimentoEditTela()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo, style: titulo(26))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final lista = _filtrar();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => q = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar alimento',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: branco(.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Criar alimento',
                      onPressed: _novo,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                child: Row(children: [
                  for (final cat in ['Todos', 'Proteínas', 'Carboidratos', 'Gorduras', 'Frutas'])
                    Padding(
                      padding: const EdgeInsets.only(right: 9),
                      child: GestureDetector(
                        onTap: () => setState(() => filtro = cat),
                        child: filtro == cat
                            ? AnelBrilho(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: kAzul.withOpacity(.16),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Text(cat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: branco(.10),
                                  border: Border.all(color: branco(.24)),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(cat, style: const TextStyle(color: Colors.white)),
                              ),
                      ),
                    ),
                ]),
              ),
              if (widget.onAdd != null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Toque em um alimento para adicionar. O lápis edita os macros.',
                      style: TextStyle(color: kMudo, fontSize: 12),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 40),
                  itemCount: lista.length,
                  itemBuilder: (context, i) => _item(lista[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _item(Alimento a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: branco(.06),
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(a.nome),
          subtitle: Text(
            '${fmtD(a.kcal)} kcal • P ${fmtD(a.p, 1)} • C ${fmtD(a.c, 1)} • G ${fmtD(a.g, 1)}  (100 g)',
            style: const TextStyle(color: kMudo, fontSize: 12),
          ),
          trailing: IconButton(
            tooltip: 'Editar alimento',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AlimentoEditTela(alimento: a)),
            ),
            icon: Icon(
              Icons.edit_note,
              color: (a.custom || app.alimentoEditado(a.id)) ? kAzul : kMudo,
            ),
          ),
          onTap: () async {
            if (widget.onAdd == null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AlimentoEditTela(alimento: a)),
              );
              return;
            }
            final g = await pedirQuantidade(context, a);
            if (g != null) {
              widget.onAdd!({'t': 'a', 'id': a.id, 'q': g});
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${a.nome} adicionado'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }
}

// ============================================================
// Criar / editar alimento (macros por 100 g)
// ============================================================
class AlimentoEditTela extends StatefulWidget {
  final Alimento? alimento;
  const AlimentoEditTela({super.key, this.alimento});
  @override
  State<AlimentoEditTela> createState() => _AlimEditEstado();
}

class _AlimEditEstado extends State<AlimentoEditTela> {
  late final TextEditingController _nome, _kcal, _p, _c, _g, _un, _ug;
  final _busca = TextEditingController();
  Timer? _deb;
  bool _buscando = false;
  String? _erroBusca;
  List<ResultadoOnline> _res = [];

  @override
  void initState() {
    super.initState();
    final a = widget.alimento;
    String f(double? v) => v == null ? '' : fmtD(v, 1);
    _nome = TextEditingController(text: a?.nome ?? '');
    _kcal = TextEditingController(text: f(a?.kcal));
    _p = TextEditingController(text: f(a?.p));
    _c = TextEditingController(text: f(a?.c));
    _g = TextEditingController(text: f(a?.g));
    _un = TextEditingController(text: a?.un ?? '');
    _ug = TextEditingController(text: (a != null && a.ug > 0) ? f(a.ug) : '');
  }

  @override
  void dispose() {
    _deb?.cancel();
    _busca.dispose();
    for (final c in [_nome, _kcal, _p, _c, _g, _un, _ug]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _campo(TextEditingController c, String rotulo,
      {bool numero = true, String? sufixo}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: numero
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: rotulo,
          suffixText: sufixo,
          filled: true,
          fillColor: branco(.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  void _aoDigitarBusca(String v) {
    _deb?.cancel();
    final q = v.trim();
    if (q.length < 3) {
      setState(() {
        _res = [];
        _erroBusca = null;
        _buscando = false;
      });
      return;
    }
    setState(() => _buscando = true);
    _deb = Timer(const Duration(milliseconds: 700), () => _buscarOnline(q));
  }

  Future<void> _buscarOnline(String q) async {
    try {
      final r = await buscarAlimentosOnline(q);
      if (!mounted || _busca.text.trim() != q) return;
      setState(() {
        _res = r;
        _erroBusca = r.isEmpty ? 'Nenhum resultado para "$q".' : null;
        _buscando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _res = [];
        _erroBusca = 'Não consegui buscar. Verifique a internet.';
        _buscando = false;
      });
    }
  }

  void _usarResultado(ResultadoOnline r) {
    setState(() {
      _nome.text = r.marca.isEmpty ? r.nome : '${r.nome} (${r.marca})';
      _kcal.text = fmtD(r.kcal, 1);
      _p.text = fmtD(r.p, 1);
      _c.text = fmtD(r.c, 1);
      _g.text = fmtD(r.g, 1);
      if (r.porcaoG != null) {
        _un.text = 'porção';
        _ug.text = fmtD(r.porcaoG!, 1);
      }
      _res = [];
      _erroBusca = null;
      _busca.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Valores por 100 g preenchidos. Confira e salve.')));
  }

  Widget _buscaOnline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _busca,
          onChanged: _aoDigitarBusca,
          decoration: InputDecoration(
            hintText: 'Buscar na internet (ex.: iogurte grego)',
            prefixIcon: const Icon(Icons.travel_explore),
            suffixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            filled: true,
            fillColor: branco(.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_erroBusca != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8),
            child: Text(_erroBusca!,
                style: const TextStyle(color: kMudo, fontSize: 12)),
          ),
        for (final r in _res)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: branco(.07),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _usarResultado(r),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.nome,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (r.marca.isNotEmpty)
                        Text(r.marca,
                            style:
                                const TextStyle(color: kMudo, fontSize: 12)),
                      Text(
                        '${fmtD(r.kcal)} kcal • P ${fmtD(r.p, 1)} • C ${fmtD(r.c, 1)} • G ${fmtD(r.g, 1)}  (100 g)',
                        style: const TextStyle(color: kMudo, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _previaPorcao() {
    final ug = _num(_ug.text) ?? 0;
    final kcal = _num(_kcal.text);
    if (ug <= 0 || kcal == null) return const SizedBox.shrink();
    final f = ug / 100;
    final un = _un.text.trim().isEmpty ? '1 unidade' : '1 ${_un.text.trim()}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Vidro(
        padding: const EdgeInsets.all(14),
        raio: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Por porção: $un (${fmtD(ug, 1)} g)',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${fmtD(kcal * f)} kcal • P ${fmtD((_num(_p.text) ?? 0) * f, 1)} g • C ${fmtD((_num(_c.text) ?? 0) * f, 1)} g • G ${fmtD((_num(_g.text) ?? 0) * f, 1)} g',
              style: const TextStyle(color: kMudo),
            ),
          ],
        ),
      ),
    );
  }

  void _calcularKcal() {
    final p = _num(_p.text) ?? 0;
    final c = _num(_c.text) ?? 0;
    final g = _num(_g.text) ?? 0;
    setState(() => _kcal.text = fmtD(p * 4 + c * 4 + g * 9, 1));
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final kcal = _num(_kcal.text);
    if (nome.isEmpty || kcal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Informe o nome e as calorias.')));
      return;
    }
    final a = widget.alimento;
    final novo = Alimento(
      id: a?.id ?? 'a_${DateTime.now().microsecondsSinceEpoch}',
      nome: nome,
      kcal: kcal,
      p: _num(_p.text) ?? 0,
      c: _num(_c.text) ?? 0,
      g: _num(_g.text) ?? 0,
      un: _un.text.trim(),
      ug: _num(_ug.text) ?? 0,
      custom: a?.custom ?? true,
    );
    await app.salvarAlimento(novo);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir alimento?'),
        content: const Text(
            'Registros que usam este alimento passarão a mostrar "Alimento removido".'),
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
    if (ok == true) {
      await app.excluirAlimento(widget.alimento!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alimento;
    return Scaffold(
      appBar: AppBar(
          title: Text(a == null ? 'Novo alimento' : 'Editar alimento',
              style: titulo(26))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (widget.alimento == null) _buscaOnline(),
          _campo(_nome, 'Nome', numero: false),
          const Text('Valores por 100 g (ou 100 ml)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _campo(_kcal, 'Calorias', sufixo: 'kcal'),
          _campo(_p, 'Proteínas', sufixo: 'g'),
          _campo(_c, 'Carboidratos', sufixo: 'g'),
          _campo(_g, 'Gorduras', sufixo: 'g'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _calcularKcal,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Calcular calorias pelos macros'),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Porção de referência (opcional)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _campo(_un, 'Nome da unidade (ex.: fatia, unidade)', numero: false),
          _campo(_ug, 'Peso de 1 unidade', sufixo: 'g'),
          _previaPorcao(),
          const Text(
            'Ao salvar, todos os registros, receitas e cardápios que usam este alimento são recalculados automaticamente.',
            style: TextStyle(color: kMudo, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: estiloPrimario,
            onPressed: _salvar,
            child: const Text('Salvar'),
          ),
          if (a != null && !a.custom && app.alimentoEditado(a.id)) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: estiloContorno,
              onPressed: () async {
                await app.restaurarAlimento(a.id);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Restaurar valores originais'),
            ),
          ],
          if (a != null && a.custom) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: estiloContorno,
              onPressed: _excluir,
              child: const Text('Excluir alimento',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Receitas
// ============================================================
class ReceitasTela extends StatefulWidget {
  final DateTime dia;
  final bool selecionar;
  const ReceitasTela({super.key, required this.dia, this.selecionar = false});
  @override
  State<ReceitasTela> createState() => _ReceitasEstado();
}

class _ReceitasEstado extends State<ReceitasTela> {
  String _cat = 'todas';
  static const _cats = <List<String>>[
    ['todas', 'Todas'],
    ['cafe', 'Café'],
    ['almoco', 'Almoço'],
    ['lanche', 'Lanche'],
    ['jantar', 'Jantar'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Receitas fitness', style: titulo(28))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final l = app.receitas
              .where((r) => _cat == 'todas' || r.cat == _cat)
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              Row(
                children: [
                  for (var i = 0; i < _cats.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i == _cats.length - 1 ? 0 : 6),
                        child: _Pill(
                          texto: _cats[i][1],
                          sel: _cat == _cats[i][0],
                          expandir: true,
                          onTap: () => setState(() => _cat = _cats[i][0]),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (final r in l) _cartao(r),
            ],
          );
        },
      ),
    );
  }

  Widget _cartao(Receita r) {
    final m = app.macrosReceita(r);
    final ref = _refPorId(r.cat);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Vidro(
        padding: const EdgeInsets.all(16),
        raio: 22,
        onTap: () async {
          final e = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (_) => ReceitaDetalheTela(
                  receita: r, dia: widget.dia, selecionar: widget.selecionar),
            ),
          );
          if (e != null && widget.selecionar && context.mounted) {
            Navigator.pop(context, e);
          }
        },
        child: Row(
          children: [
            Container(
              width: 10,
              height: 54,
              decoration: BoxDecoration(
                color: ref.cor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.nome,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${fmtD(m.kcal)} kcal • ${r.min} min',
                      style: const TextStyle(color: kMudo, fontSize: 12)),
                  Text(
                      'P ${fmtD(m.p)} g • C ${fmtD(m.c)} g • G ${fmtD(m.g)} g',
                      style: const TextStyle(color: kMudo, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kMudo),
          ],
        ),
      ),
    );
  }
}

class ReceitaDetalheTela extends StatefulWidget {
  final Receita receita;
  final DateTime dia;
  final bool selecionar;
  const ReceitaDetalheTela(
      {super.key,
      required this.receita,
      required this.dia,
      this.selecionar = false});
  @override
  State<ReceitaDetalheTela> createState() => _ReceitaDetalheEstado();
}

class _ReceitaDetalheEstado extends State<ReceitaDetalheTela> {
  double _porcoes = 1;
  late String _ref;

  @override
  void initState() {
    super.initState();
    _ref = kRefeicoes.any((r) => r.id == widget.receita.cat)
        ? widget.receita.cat
        : 'outros';
  }

  Future<void> _adicionar() async {
    final e = <String, dynamic>{'t': 'r', 'id': widget.receita.id, 'q': _porcoes};
    if (widget.selecionar) {
      Navigator.pop(context, e);
      return;
    }
    await app.addEntrada(chaveData(widget.dia), _ref, e);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Adicionado em ${_refPorId(_ref).nome}')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receita;
    final m = app.macrosReceita(r) * _porcoes;
    return Scaffold(
      appBar: AppBar(title: Text('Receita', style: titulo(28))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(r.nome, style: titulo(34)),
          const SizedBox(height: 4),
          Text('${r.min} min • valores por ${fmtD(_porcoes, 1)} ${_porcoes == 1 ? 'porção' : 'porções'}',
              style: const TextStyle(color: kMudo)),
          const SizedBox(height: 14),
          Vidro(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _mini(fmtD(m.kcal), 'kcal'),
                _mini('${fmtD(m.p)} g', 'proteína'),
                _mini('${fmtD(m.c)} g', 'carbo'),
                _mini('${fmtD(m.g)} g', 'gordura'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Ingredientes', style: titulo(26)),
          const SizedBox(height: 6),
          for (final i in r.ing)
            Builder(builder: (context) {
              final a = app.alimento(i.id);
              final g = i.g * _porcoes;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(child: Text(a?.nome ?? 'Alimento removido')),
                    Text('${fmtD(g)} g',
                        style: const TextStyle(color: kMudo)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 70,
                      child: Text(
                          a == null
                              ? '--'
                              : '${fmtD(a.porGramas(g).kcal)} kcal',
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: kMudo, fontSize: 12)),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 14),
          Text('Modo de preparo', style: titulo(26)),
          const SizedBox(height: 6),
          Text(r.modo, style: const TextStyle(color: kMudo, height: 1.35)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Porções', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: _porcoes > 0.5
                    ? () => setState(() => _porcoes -= 0.5)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(fmtD(_porcoes, 1), style: titulo(26)),
              IconButton(
                onPressed: () => setState(() => _porcoes += 0.5),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          if (!widget.selecionar) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rf in kRefeicoes)
                  _Pill(
                    texto: rf.nome,
                    sel: _ref == rf.id,
                    onTap: () => setState(() => _ref = rf.id),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: estiloPrimario,
            onPressed: _adicionar,
            icon: const Icon(Icons.add),
            label: Text(widget.selecionar ? 'Usar esta receita' : 'Adicionar ao dia'),
          ),
        ),
      ),
    );
  }

  Widget _mini(String v, String r) => Column(
        children: [
          Text(v, style: titulo(26)),
          Text(r, style: const TextStyle(color: kMudo, fontSize: 12)),
        ],
      );
}

// ============================================================
// Meu cardápio (refeições fixas)
// ============================================================
class CardapioTela extends StatefulWidget {
  const CardapioTela({super.key});

  @override
  State<CardapioTela> createState() => _CardapioTelaEstado();
}

class _CardapioTelaEstado extends State<CardapioTela> {
  @override
  void initState() {
    super.initState();
    app.carregarCardapioPadrao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Meu cardápio', style: titulo(28))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              Vidro(
                padding: const EdgeInsets.all(16),
                raio: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.track_changes, color: kAzul),
                      const SizedBox(width: 8),
                      Text('Plano alimentar sugerido', style: titulo(19)),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                      'Cardápio inicial configurado para cerca de 2.500 kcal/dia, distribuído em cinco refeições principais. A seção Outros fica disponível para extras. As quantidades são editáveis e os macros são calculados pelos alimentos cadastrados.',
                      style: TextStyle(color: kMudo, height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Treino às 6h • Café da manhã às 7h30 (pós-treino). Toque em um alimento para ajustar a quantidade ou no X para removê-lo.',
                      style: TextStyle(color: kMudo, fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final r in kRefeicoes) _secao(context, r),
            ],
          );
        },
      ),
    );
  }

  Widget _secao(BuildContext context, Refeicao r) {
    final itens = app.entradasCardapio(r.id);
    final tot = app.totalCardapio(r.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Vidro(
        padding: const EdgeInsets.all(16),
        raio: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: r.cor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.nome, style: titulo(24)),
                      if (r.horario.isNotEmpty)
                        Text(r.horario, style: const TextStyle(color: kMudo, fontSize: 11)),
                    ],
                  ),
                ),
                Text('${fmtD(tot.kcal)} kcal',
                    style: const TextStyle(color: kMudo)),
              ],
            ),
            if (itens.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text(
                    'P ${fmtD(tot.p)} g • C ${fmtD(tot.c)} g • G ${fmtD(tot.g)} g',
                    style: const TextStyle(color: kMudo, fontSize: 12)),
              ),
            for (var i = 0; i < itens.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final q = await pedirQuantidadeEntrada(context, itens[i]);
                  if (q != null) await app.setQtdCardapio(r.id, i, q);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.nomeEntrada(itens[i])),
                            Text(
                                '${app.qtdEntrada(itens[i])} • ${fmtD(app.macrosEntrada(itens[i]).kcal)} kcal',
                                style: const TextStyle(
                                    color: kMudo, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => app.removerCardapio(r.id, i),
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: estiloContornoFino,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BuscarAlimentoTela(
                          titulo: 'Cardápio: ${r.nome}',
                          onAdd: (e) => app.addCardapio(r.id, e),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Alimento'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: estiloContornoFino,
                    onPressed: () async {
                      final e = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceitasTela(
                              dia: DateTime.now(), selecionar: true),
                        ),
                      );
                      if (e != null) await app.addCardapio(r.id, e);
                    },
                    icon: const Icon(Icons.restaurant, size: 18),
                    label: const Text('Receita'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Meus dados e metas (TMB)
// ============================================================
class PerfilTela extends StatefulWidget {
  const PerfilTela({super.key});
  @override
  State<PerfilTela> createState() => _PerfilEstado();
}

class _PerfilEstado extends State<PerfilTela> {
  String? _sexo;
  DateTime? _nasc;
  int _ativ = 2, _obj = 1;
  late final TextEditingController _altura, _peso, _manual;

  static const _ativTxt = [
    'Sedentário — pouco ou nenhum exercício',
    'Leve — treino 1 a 3x por semana',
    'Moderado — treino 3 a 5x por semana',
    'Intenso — treino 6 a 7x por semana',
    'Muito intenso — treino pesado todo dia',
  ];
  static const _objTxt = ['Perder gordura', 'Manter peso', 'Ganhar massa'];

  @override
  void initState() {
    super.initState();
    final p = app.perfil;
    _sexo = p['sexo'] as String?;
    _nasc = DateTime.tryParse('${p['nasc'] ?? ''}');
    _ativ = (p['ativ'] as num?)?.toInt() ?? 2;
    _obj = (p['obj'] as num?)?.toInt() ?? 1;
    final alt = app.alturaAtual;
    final pes = app.pesoAtual;
    _altura = TextEditingController(text: alt == null ? '' : fmtD(alt, 1));
    _peso = TextEditingController(text: pes == null ? '' : fmtD(pes, 1));
    final man = (p['kcal_manual'] as num?)?.toDouble();
    _manual = TextEditingController(text: man == null ? '' : fmtD(man));
  }

  @override
  void dispose() {
    _altura.dispose();
    _peso.dispose();
    _manual.dispose();
    super.dispose();
  }

  Metas? get _metas => app.calcularMetas(
        sexo: _sexo,
        nasc: _nasc,
        altura: _num(_altura.text),
        peso: _num(_peso.text),
        ativ: _ativ,
        obj: _obj,
        manual: _num(_manual.text),
      );

  Future<void> _escolherNasc() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _nasc ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _nasc = d);
  }

  Future<void> _salvar() async {
    if (_metas == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preencha sexo, nascimento, altura e peso.')));
      return;
    }
    await app.salvarPerfil({
      ...app.perfil,
      'sexo': _sexo,
      'nasc': _nasc!.toIso8601String(),
      'altura': _num(_altura.text),
      'peso': _num(_peso.text),
      'ativ': _ativ,
      'obj': _obj,
      'kcal_manual': _num(_manual.text),
    });
    if (mounted) Navigator.pop(context);
  }

  Widget _campo(TextEditingController c, String rotulo, String sufixo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: rotulo,
          suffixText: sufixo,
          filled: true,
          fillColor: branco(.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _metas;
    return Scaffold(
      appBar: AppBar(title: Text('Meus dados', style: titulo(28))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const Text(
            'Usamos esses dados para calcular seu TMB e suas metas diárias. O peso e a altura já vêm das suas avaliações, quando existem.',
            style: TextStyle(color: kMudo),
          ),
          const SizedBox(height: 14),
          const Text('Sexo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Pill(
                  texto: 'Masculino',
                  sel: _sexo == 'm',
                  expandir: true,
                  onTap: () => setState(() => _sexo = 'm'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pill(
                  texto: 'Feminino',
                  sel: _sexo == 'f',
                  expandir: true,
                  onTap: () => setState(() => _sexo = 'f'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: estiloContorno,
            onPressed: _escolherNasc,
            icon: const Icon(Icons.cake_outlined),
            label: Text(_nasc == null
                ? 'Data de nascimento'
                : '${_nasc!.day.toString().padLeft(2, '0')}/${_nasc!.month.toString().padLeft(2, '0')}/${_nasc!.year}'),
          ),
          const SizedBox(height: 14),
          _campo(_altura, 'Altura', 'cm'),
          _campo(_peso, 'Peso', 'kg'),
          const Text('Nível de atividade',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (var i = 0; i < _ativTxt.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _ativ = i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _ativ == i
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: _ativ == i ? kAzul : kMudo,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_ativTxt[i])),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          const Text('Objetivo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < _objTxt.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: i == _objTxt.length - 1 ? 0 : 8),
                    child: _Pill(
                      texto: _objTxt[i],
                      sel: _obj == i,
                      expandir: true,
                      onTap: () => setState(() => _obj = i),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _campo(_manual, 'Meta de calorias personalizada (opcional)', 'kcal'),
          if (m != null)
            Vidro(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suas metas', style: titulo(26)),
                  const SizedBox(height: 8),
                  Text('TMB (em repouso): ${fmtD(m.tmb)} kcal'),
                  Text('Gasto diário estimado: ${fmtD(m.gasto)} kcal'),
                  const SizedBox(height: 6),
                  Text('Meta: ${fmtD(m.kcal)} kcal por dia',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                      'Proteína ${fmtD(m.p)} g • Carbo ${fmtD(m.c)} g • Gordura ${fmtD(m.g)} g',
                      style: const TextStyle(color: kMudo)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: estiloPrimario,
            onPressed: _salvar,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
