import 'package:flutter/material.dart';
import 'state.dart';
import 'telas.dart';

const _nomesDiaSemana = {
  1: 'Segunda-feira',
  2: 'Terça-feira',
  3: 'Quarta-feira',
  4: 'Quinta-feira',
  5: 'Sexta-feira',
  6: 'Sábado',
  7: 'Domingo',
};

/// Abre a biblioteca para escolher um exercício. Devolve null se cancelar.
Future<Exercicio?> escolherExercicio(BuildContext context) {
  return Navigator.push<Exercicio>(
    context,
    MaterialPageRoute(builder: (_) => const BibliotecaTela(selecionar: true)),
  );
}

/// Troca o exercício de um item mantendo séries/repetições. true = mudou.
Future<bool> trocarExercicio(BuildContext context, Item it) async {
  final e = await escolherExercicio(context);
  if (e == null) return false;
  it.exId = e.id;
  it.nome = e.nome;
  it.grupo = e.grupo;
  return true;
}

Future<bool> editarSeriesReps(BuildContext context, Item it) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogoSeries(it: it),
  );
  return r == true;
}

class _DialogoSeries extends StatefulWidget {
  final Item it;
  const _DialogoSeries({required this.it});
  @override
  State<_DialogoSeries> createState() => _DialogoSeriesEstado();
}

class _DialogoSeriesEstado extends State<_DialogoSeries> {
  late final TextEditingController _s, _r;
  @override
  void initState() {
    super.initState();
    _s = TextEditingController(text: '${widget.it.series}');
    _r = TextEditingController(text: widget.it.reps);
  }

  @override
  void dispose() {
    _s.dispose();
    _r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Séries e repetições'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _s,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Séries'),
          ),
          TextField(
            controller: _r,
            decoration: const InputDecoration(
                labelText: 'Repetições', hintText: 'ex.: 10-12'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            final s = int.tryParse(_s.text.trim());
            final r = _r.text.replaceAll(RegExp(r'\s'), '');
            if (s != null && s > 0) widget.it.series = s;
            if (r.isNotEmpty) widget.it.reps = r;
            Navigator.pop(context, true);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Lista de exercícios com arrastar para reordenar, trocar e excluir.
class ListaItensEditavel extends StatelessWidget {
  final List<Item> itens;
  final VoidCallback onChanged;
  const ListaItensEditavel(
      {super.key, required this.itens, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (a, b) {
        if (b > a) b--;
        final it = itens.removeAt(a);
        itens.insert(b, it);
        onChanged();
      },
      children: [
        for (var i = 0; i < itens.length; i++)
          Padding(
            key: ObjectKey(itens[i]),
            padding: const EdgeInsets.only(bottom: 8),
            child: _linha(context, i),
          ),
      ],
    );
  }

  Widget _linha(BuildContext context, int i) {
    final it = itens[i];
    final nome = app.ex(it.exId)?.nome ?? it.nome;
    return Material(
      color: branco(.07),
      borderRadius: BorderRadius.circular(18),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: i,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Icon(Icons.drag_handle, color: kMudo),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                if (await trocarExercicio(context, it)) onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(it.grupo,
                            style:
                                const TextStyle(color: kMudo, fontSize: 12)),
                        const SizedBox(width: 6),
                        const Icon(Icons.swap_horiz, size: 14, color: kAzul),
                        const Text(' trocar',
                            style: TextStyle(color: kAzul, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              if (await editarSeriesReps(context, it)) onChanged();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text('${it.series}×${it.reps}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          IconButton(
            tooltip: 'Excluir exercício',
            onPressed: () {
              itens.removeAt(i);
              onChanged();
            },
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

Future<void> adicionarExercicioA(
    BuildContext context, List<Item> itens, VoidCallback onChanged) async {
  final e = await escolherExercicio(context);
  if (e == null) return;
  itens.add(Item(
      exId: e.id, nome: e.nome, grupo: e.grupo, series: 3, reps: '10-12'));
  onChanged();
}

// ---------- Editar um dia do plano ----------
class EditarDiaTela extends StatefulWidget {
  final Dia dia;
  const EditarDiaTela({super.key, required this.dia});
  @override
  State<EditarDiaTela> createState() => _EditarDiaEstado();
}

class _EditarDiaEstado extends State<EditarDiaTela> {
  late final TextEditingController _foco;

  @override
  void initState() {
    super.initState();
    _foco = TextEditingController(text: widget.dia.foco);
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  void _mudou() {
    setState(() {});
    app.atualizarPlano();
  }

  @override
  Widget build(BuildContext context) {
    final dia = widget.dia;
    return Scaffold(
      appBar: AppBar(title: Text('Editar ${dia.nome}', style: titulo(26))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          TextField(
            controller: _foco,
            onChanged: (v) {
              dia.foco = v;
              app.atualizarPlano();
            },
            decoration: InputDecoration(
              labelText: 'Foco do dia',
              filled: true,
              fillColor: branco(.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Segure e arraste ≡ para reordenar. Toque no nome para trocar o exercício.',
            style: TextStyle(color: kMudo, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ListaItensEditavel(itens: dia.itens, onChanged: _mudou),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: estiloContorno,
            onPressed: () => adicionarExercicioA(context, dia.itens, _mudou),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar exercício'),
          ),
        ],
      ),
    );
  }
}

// ---------- Editar o plano inteiro ----------
class EditarPlanoTela extends StatelessWidget {
  const EditarPlanoTela({super.key});

  Future<void> _novoDia(BuildContext context) async {
    final usados = app.plano.map((d) => d.weekday).toSet();
    final livres = [for (var i = 1; i <= 7; i++) if (!usados.contains(i)) i];
    if (livres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos os dias já têm treino.')));
      return;
    }
    final wd = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Qual dia da semana?'),
        children: [
          for (final w in livres)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, w),
              child: Text(_nomesDiaSemana[w]!),
            ),
        ],
      ),
    );
    if (wd == null) return;
    final d = Dia(nome: _nomesDiaSemana[wd]!, weekday: wd, itens: []);
    await app.adicionarDia(d);
    if (!context.mounted) return;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => EditarDiaTela(dia: d)));
  }

  Future<void> _excluir(BuildContext context, Dia d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Excluir ${d.nome}?'),
        content: const Text('O treino desse dia será removido do plano.'),
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
    if (ok == true) await app.removerDia(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar plano', style: titulo(28))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final dias = [...app.plano]
            ..sort((a, b) => a.weekday.compareTo(b.weekday));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              const Text('Toque em um dia para editar seus exercícios.',
                  style: TextStyle(color: kMudo)),
              const SizedBox(height: 12),
              for (final d in dias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Vidro(
                    padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                    raio: 22,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EditarDiaTela(dia: d)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.nome, style: titulo(24)),
                              Text(
                                d.foco.isEmpty
                                    ? '${d.itens.length} exercícios'
                                    : '${d.foco} • ${d.itens.length} exercícios',
                                style: const TextStyle(color: kMudo),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Excluir dia',
                          onPressed: () => _excluir(context, d),
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                        ),
                        const Icon(Icons.chevron_right, color: kMudo),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: estiloContorno,
                onPressed: () => _novoDia(context),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar dia'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: estiloContorno,
                onPressed: () => abrirImportar(
                    context,
                    (_) =>
                        Navigator.of(context).popUntil((r) => r.isFirst)),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Importar novo PDF'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Treino livre ----------
class TreinoLivreTela extends StatefulWidget {
  const TreinoLivreTela({super.key});
  @override
  State<TreinoLivreTela> createState() => _TreinoLivreEstado();
}

class _TreinoLivreEstado extends State<TreinoLivreTela> {
  final Dia livre =
      Dia(nome: 'Treino livre', weekday: DateTime.now().weekday, itens: []);

  void _mudou() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Treino livre', style: titulo(28))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text(
            'Monte um treino na hora, fora do seu plano. Ele entra no histórico, mas não marca o treino do dia.',
            style: TextStyle(color: kMudo),
          ),
          const SizedBox(height: 14),
          ListaItensEditavel(itens: livre.itens, onChanged: _mudou),
          OutlinedButton.icon(
            style: estiloContorno,
            onPressed: () => adicionarExercicioA(context, livre.itens, _mudou),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar exercício'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: estiloPrimario,
            onPressed: livre.itens.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => RunTela(dia: livre, livre: true)),
                    ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Começar'),
          ),
        ),
      ),
    );
  }
}
