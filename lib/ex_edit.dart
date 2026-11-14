import 'package:flutter/material.dart';
import 'state.dart';
import 'telas.dart';

/// Tela para editar tudo de um exercício da biblioteca.
class ExercicioEditTela extends StatefulWidget {
  final Exercicio exercicio;
  const ExercicioEditTela({super.key, required this.exercicio});
  @override
  State<ExercicioEditTela> createState() => _ExEditEstado();
}

class _ExEditEstado extends State<ExercicioEditTela> {
  late final TextEditingController _nome, _grupo, _equip, _apelidos;

  @override
  void initState() {
    super.initState();
    final e = widget.exercicio;
    _nome = TextEditingController(text: e.nome);
    _grupo = TextEditingController(text: e.grupo);
    _equip = TextEditingController(text: e.equip);
    _apelidos = TextEditingController(text: e.apelidos.join(', '));
  }

  @override
  void dispose() {
    _nome.dispose();
    _grupo.dispose();
    _equip.dispose();
    _apelidos.dispose();
    super.dispose();
  }

  List<String> get _grupos {
    final s = <String>{};
    for (final e in app.lib) {
      if (e.grupo.trim().isNotEmpty) s.add(e.grupo);
    }
    final l = s.toList()..sort();
    return l;
  }

  Widget _campo(TextEditingController c, String rotulo, {String? dica}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: rotulo,
          hintText: dica,
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

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe o nome.')));
      return;
    }
    final apelidos = _apelidos.text
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    await app.editarExercicio(
      widget.exercicio,
      nome: nome,
      grupo: _grupo.text.trim().isEmpty ? 'Outros' : _grupo.text.trim(),
      equip: _equip.text.trim(),
      apelidos: apelidos,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir exercício?'),
        content: const Text(
            'Ele sai da biblioteca. Treinos que já usam esse exercício continuam com o nome salvo.'),
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
      await app.excluirExercicio(widget.exercicio.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercicio;
    return Scaffold(
      appBar: AppBar(title: Text('Editar exercício', style: titulo(26))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _campo(_nome, 'Nome'),
          _campo(_grupo, 'Grupo muscular'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final g in _grupos)
                ActionChip(
                  label: Text(g, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _grupo.text = g),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _campo(_equip, 'Equipamento', dica: 'ex.: Máquina, Barra, Halter'),
          _campo(_apelidos, 'Outros nomes (separe por vírgula)',
              dica: 'ex.: supino, bench press'),
          const Text(
            'Ao salvar, os treinos que usam este exercício também são atualizados.',
            style: TextStyle(color: kMudo, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: estiloPrimario,
            onPressed: _salvar,
            child: const Text('Salvar'),
          ),
          if (!e.custom && app.exOver.containsKey(e.id)) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: estiloContorno,
              onPressed: () async {
                await app.restaurarExercicio(e.id);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Restaurar original'),
            ),
          ],
          if (e.custom) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: estiloContorno,
              onPressed: _excluir,
              child: const Text('Excluir exercício',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ],
      ),
    );
  }
}
