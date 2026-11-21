import 'package:flutter/material.dart';
import 'state.dart';
import 'extras.dart';

class SonoCalendarioTela extends StatefulWidget {
  const SonoCalendarioTela({super.key});
  @override
  State<SonoCalendarioTela> createState() => _SonoCalendarioTelaState();
}

class _SonoCalendarioTelaState extends State<SonoCalendarioTela> {
  DateTime mes = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime dia = DateTime.now();
  String chave(DateTime d) => chaveData(d);
  Map<String, dynamic>? registro(DateTime d) {
    for (final x in app.sono) {
      if (x['data'] == chave(d)) return x;
    }
    return null;
  }

  int? minutos(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final n = int.parse(m.group(2)!);
    return h < 24 && n < 60 ? h * 60 + n : null;
  }

  String duracao(int m) => '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}min';
  int duracaoRegistro(Map<String, dynamic> r) => (r['duracao'] as num?)?.toInt() ?? 0;
  int numero(Map<String, dynamic>? r, String k) => (r?[k] as num?)?.toInt() ?? 0;
  bool marcado(Map<String, dynamic>? r, String k) => r?[k] == true;

  Future<void> editar() async {
    final atual = registro(dia);
    final dormir = TextEditingController(text: '${atual?['dormir'] ?? '22:00'}');
    final acordar = TextEditingController(text: '${atual?['acordar'] ?? '06:00'}');
    final latencia = TextEditingController(text: '${atual?['latencia'] ?? 15}');
    final despertares = TextEditingController(text: '${atual?['despertares'] ?? 0}');
    final tempoAcordado = TextEditingController(text: '${atual?['tempoAcordado'] ?? 0}');
    final cochilo = TextEditingController(text: '${atual?['cochilo'] ?? 0}');
    final notas = TextEditingController(text: '${atual?['notas'] ?? ''}');
    int qualidade = numero(atual, 'qualidade') == 0 ? 3 : numero(atual, 'qualidade');
    int estresse = numero(atual, 'estresse') == 0 ? 3 : numero(atual, 'estresse');
    bool cafeina = marcado(atual, 'cafeina');
    bool telas = marcado(atual, 'telas');
    bool refeicaoTardia = marcado(atual, 'refeicaoTardia');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: const Text('Diário completo do sono'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: dormir, decoration: const InputDecoration(labelText: 'Horário que foi dormir (HH:mm)'), keyboardType: TextInputType.datetime),
                TextField(controller: acordar, decoration: const InputDecoration(labelText: 'Horário que acordou (HH:mm)'), keyboardType: TextInputType.datetime),
                TextField(controller: latencia, decoration: const InputDecoration(labelText: 'Minutos para pegar no sono'), keyboardType: TextInputType.number),
                TextField(controller: despertares, decoration: const InputDecoration(labelText: 'Quantas vezes acordou durante a noite'), keyboardType: TextInputType.number),
                TextField(controller: tempoAcordado, decoration: const InputDecoration(labelText: 'Minutos acordado durante a noite'), keyboardType: TextInputType.number),
                TextField(controller: cochilo, decoration: const InputDecoration(labelText: 'Cochilos durante o dia (minutos)'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                Text('Qualidade do sono: $qualidade/5'),
                Slider(value: qualidade.toDouble(), min: 1, max: 5, divisions: 4, onChanged: (v) => setDialog(() => qualidade = v.round())),
                Text('Nível de estresse: $estresse/5'),
                Slider(value: estresse.toDouble(), min: 1, max: 5, divisions: 4, onChanged: (v) => setDialog(() => estresse = v.round())),
                CheckboxListTile(contentPadding: EdgeInsets.zero,title: const Text('Consumiu cafeína à tarde/noite'),value: cafeina,onChanged: (v) => setDialog(() => cafeina = v ?? false)),
                CheckboxListTile(contentPadding: EdgeInsets.zero,title: const Text('Usou telas antes de dormir'),value: telas,onChanged: (v) => setDialog(() => telas = v ?? false)),
                CheckboxListTile(contentPadding: EdgeInsets.zero,title: const Text('Fez refeição pesada perto de dormir'),value: refeicaoTardia,onChanged: (v) => setDialog(() => refeicaoTardia = v ?? false)),
                TextField(controller: notas, maxLines: 3, decoration: const InputDecoration(labelText: 'Observações do dia', alignLabelWithHint: true)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salvar registro')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final a = minutos(dormir.text), b = minutos(acordar.text);
      final la = int.tryParse(latencia.text) ?? -1;
      final de = int.tryParse(despertares.text) ?? -1;
      final ta = int.tryParse(tempoAcordado.text) ?? -1;
      final co = int.tryParse(cochilo.text) ?? -1;
      if (a == null || b == null || [la, de, ta, co].any((v) => v < 0) || la > 1440 || ta > 1440 || co > 1440) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confira os horários e informe números válidos (zero ou maior).')));
      } else {
        var total = b - a;
        if (total <= 0) total += 1440;
        final sonoLiquido = (total - la - ta).clamp(0, 1440);
        await app.salvarSono({
          'data': chave(dia), 'dormir': dormir.text.trim(), 'acordar': acordar.text.trim(),
          'duracao': total, 'sonoLiquido': sonoLiquido, 'latencia': la,
          'despertares': de, 'tempoAcordado': ta, 'cochilo': co,
          'qualidade': qualidade, 'estresse': estresse, 'cafeina': cafeina,
          'telas': telas, 'refeicaoTardia': refeicaoTardia, 'notas': notas.text.trim(),
        });
      }
    }
    for (final x in [dormir, acordar, latencia, despertares, tempoAcordado, cochilo, notas]) { x.dispose(); }
  }

  List<Map<String, dynamic>> registrosUltimos(int dias) {
    final limite = DateTime.now().subtract(Duration(days: dias - 1));
    return app.sono.where((r) {
      final d = dataDaChave('${r['data']}');
      return d != null && !d.isBefore(DateTime(limite.year, limite.month, limite.day)) && !d.isAfter(DateTime.now());
    }).toList();
  }

  double media(List<Map<String, dynamic>> lista, String campo) {
    if (lista.isEmpty) return 0;
    return lista.fold<int>(0, (s, r) => s + ((r[campo] as num?)?.toInt() ?? 0)) / lista.length;
  }

  Widget resumoCard(String titulo, String valor, IconData icone) => Expanded(
    child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Icon(icone, color: kAzul), const SizedBox(height: 5),
      Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
    ]))),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) {
      final primeiro = DateTime(mes.year, mes.month, 1);
      final offset = primeiro.weekday % 7;
      final diasMes = DateTime(mes.year, mes.month + 1, 0).day;
      final totalCelulas = ((offset + diasMes + 6) ~/ 7) * 7;
      final r = registro(dia);
      final ultimos7 = registrosUltimos(7);
      final ultimos30 = registrosUltimos(30);
      final mediaSono = media(ultimos7, 'sonoLiquido');
      final mediaQualidade = media(ultimos7, 'qualidade');
      final mesNome = const ['Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'][mes.month - 1];
      return Scaffold(
        appBar: AppBar(title: const Text('Sono e calendário'), actions: [
          IconButton(tooltip: 'Ir para hoje', onPressed: () => setState(() { dia = DateTime.now(); mes = DateTime(DateTime.now().year, DateTime.now().month); }), icon: const Icon(Icons.today)),
        ]),
        body: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 120), children: [
          Row(children: [
            resumoCard('Média de sono (7 dias)', mediaSono == 0 ? '--' : duracao(mediaSono.round()), Icons.bedtime),
            resumoCard('Qualidade média', mediaQualidade == 0 ? '--' : '${mediaQualidade.toStringAsFixed(1)}/5', Icons.star),
            resumoCard('Registros (30 dias)', '${ultimos30.length}', Icons.calendar_month),
          ]),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Evolução dos últimos 7 registros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (ultimos7.isEmpty) const Text('Registre seu sono diariamente para visualizar sua evolução.')
            else ...ultimos7.reversed.map((x) {
              final mins = (x['sonoLiquido'] as num?)?.toInt() ?? (x['duracao'] as num?)?.toInt() ?? 0;
              final dt = dataDaChave('${x['data']}');
              return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                SizedBox(width: 48, child: Text(dt == null ? '--' : '${dt.day}/${dt.month}', style: const TextStyle(fontSize: 12))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: (mins / 540).clamp(0.0, 1.0), minHeight: 10))),
                const SizedBox(width: 8), SizedBox(width: 65, child: Text(duracao(mins), textAlign: TextAlign.end, style: const TextStyle(fontSize: 12))),
              ]));
            }),
          ]))),
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            Row(children: [
              IconButton(onPressed: () => setState(() => mes = DateTime(mes.year, mes.month - 1)), icon: const Icon(Icons.chevron_left)),
              Expanded(child: Text('$mesNome ${mes.year}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => setState(() => mes = DateTime(mes.year, mes.month + 1)), icon: const Icon(Icons.chevron_right)),
            ]),
            Row(children: ['D','S','T','Q','Q','S','S'].map((x) => Expanded(child: Center(child: Text(x, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white60))))).toList()),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: totalCelulas,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.05),
              itemBuilder: (c, i) {
                final n = i - offset + 1;
                if (n < 1 || n > diasMes) return const SizedBox();
                final dt = DateTime(mes.year, mes.month, n);
                final key = chave(dt), sel = key == chave(dia), sono = registro(dt);
                final treino = app.fezAtividade(dt), nutri = app.totalDia(key).kcal > 0, passos = (app.passos[key] ?? 0) > 0;
                return InkWell(onTap: () => setState(() => dia = dt), child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: sel ? kAzul.withOpacity(.28) : branco(.04), borderRadius: BorderRadius.circular(9), border: Border.all(color: sel ? kAzul : branco(.08))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$n', style: TextStyle(fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                    Wrap(spacing: 2, children: [
                      if (treino) const Icon(Icons.fitness_center, size: 10, color: Colors.greenAccent),
                      if (sono != null) const Icon(Icons.bedtime, size: 10, color: Colors.lightBlueAccent),
                      if (nutri) const Icon(Icons.restaurant, size: 10, color: Colors.orangeAccent),
                      if (passos) const Icon(Icons.directions_walk, size: 10, color: Colors.purpleAccent),
                    ]),
                  ]),
                ));
              },
            ),
            const SizedBox(height: 8),
            const Wrap(spacing: 12, runSpacing: 6, children: [
              _Legenda(cor: Colors.greenAccent, texto: 'Treino'), _Legenda(cor: Colors.lightBlueAccent, texto: 'Sono'),
              _Legenda(cor: Colors.orangeAccent, texto: 'Nutrição'), _Legenda(cor: Colors.purpleAccent, texto: 'Passos'),
            ]),
          ]))),
          Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 6), child: Text('Resumo de ${dia.day}/${dia.month}/${dia.year}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r == null ? 'Sono ainda não registrado' : 'Sono líquido: ${duracao(numero(r, 'sonoLiquido') == 0 ? numero(r, 'duracao') : numero(r, 'sonoLiquido'))}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (r != null) ...[
              Text('${r['dormir']} → ${r['acordar']}  •  Qualidade ${r['qualidade']}/5'),
              Text('Latência: ${numero(r, 'latencia')} min  •  Despertares: ${numero(r, 'despertares')}  •  Acordado: ${numero(r, 'tempoAcordado')} min'),
              Text('Cochilos: ${numero(r, 'cochilo')} min  •  Estresse: ${r['estresse'] ?? 3}/5'),
              Text('Cafeína: ${marcado(r, 'cafeina') ? 'Sim' : 'Não'}  •  Telas: ${marcado(r, 'telas') ? 'Sim' : 'Não'}  •  Refeição tardia: ${marcado(r, 'refeicaoTardia') ? 'Sim' : 'Não'}'),
              if ('${r['notas'] ?? ''}'.trim().isNotEmpty) Text('Observações: ${r['notas']}'),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton.icon(onPressed: editar, icon: const Icon(Icons.edit), label: Text(r == null ? 'Registrar sono' : 'Editar registro')),
              if (r != null) TextButton.icon(onPressed: () => app.excluirSono(chave(dia)), icon: const Icon(Icons.delete_outline), label: const Text('Excluir')),
            ]),
          ]))),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Resumo do dia', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Treinos/cardio: ${app.sessoesDoDia(dia).length}'),
            Text('Nutrição: ${app.totalDia(chave(dia)).kcal.round()} kcal'),
            Text('Passos: ${app.passos[chave(dia)] ?? 0}'),
          ]))),
          const Padding(padding: EdgeInsets.all(8), child: Text('Use os registros para observar padrões. As associações entre sono, treino, alimentação e hábitos não comprovam causa e efeito.', style: TextStyle(color: Colors.white60, fontSize: 12))),
        ]),
      );
    },
  );
}

class _Legenda extends StatelessWidget {
  final Color cor;
  final String texto;
  const _Legenda({required this.cor, required this.texto});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
    const SizedBox(width: 4), Text(texto, style: const TextStyle(fontSize: 11, color: Colors.white70)),
  ]);
}
