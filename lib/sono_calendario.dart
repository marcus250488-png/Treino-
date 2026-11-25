import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'state.dart';
import 'extras.dart';

class SonoCalendarioTela extends StatefulWidget {
  const SonoCalendarioTela({super.key});
  @override
  State<SonoCalendarioTela> createState() => _SonoCalendarioTelaState();
}

class _SonoCalendarioTelaState extends State<SonoCalendarioTela> {
  static const _sensor = MethodChannel('meutreino/sono');
  bool _monitorando = false;
  Map<String, dynamic> _sensores = {};
  @override
  void initState() { super.initState(); _lerMonitoramento(); }
  Future<void> _lerMonitoramento() async {
    try { final v = await _sensor.invokeMapMethod<String, dynamic>('status');
      if (mounted) setState(() { _sensores = v ?? {}; _monitorando = _sensores['ativo'] == true; });
    } catch (_) {}
  }
  Future<void> _alternarMonitoramento() async {
    try {
      if (_monitorando) {
        final v = await _sensor.invokeMapMethod<String, dynamic>('parar');
        if (mounted) setState(() { _sensores = v ?? {}; _monitorando = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monitoramento encerrado. Confira o resumo da sessão.')));
      } else {
        final v = await _sensor.invokeMapMethod<String, dynamic>('iniciar');
        if (mounted) setState(() { _sensores = v ?? {}; _monitorando = true; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monitoramento iniciado. Deixe o celular próximo à cama.')));
      }
    } on PlatformException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Não foi possível iniciar os sensores.')));
    } catch (_) {}
  }

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
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) {
          final w = minutos(dormir.text), a = minutos(acordar.text);
          var previsto = 0;
          if (w != null && a != null) { previsto = a - w; if (previsto <= 0) previsto += 1440; }
          final liquidoPrevisto = (previsto - (int.tryParse(latencia.text) ?? 0) - (int.tryParse(tempoAcordado.text) ?? 0)).clamp(0, 1440);
          Widget campo(String label, TextEditingController ctrl, {bool numero = false, String? sufixo}) =>
            TextField(controller: ctrl, keyboardType: numero ? TextInputType.number : TextInputType.datetime,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(labelText: label, suffixText: sufixo, filled: true,
                fillColor: Theme.of(c).colorScheme.surfaceContainerHighest.withOpacity(.38),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)));
          Widget secao(String titulo, IconData icone, List<Widget> filhos) => Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Theme.of(c).colorScheme.surfaceContainerHighest.withOpacity(.28),
              borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.06))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(icone, color: const Color(0xFF4C8DFF), size: 19), const SizedBox(width: 8),
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: .3))]),
              const SizedBox(height: 13), ...filhos,
            ]));
          Widget check(String label, bool value, ValueChanged<bool> change, IconData icon) => SwitchListTile(
            contentPadding: EdgeInsets.zero, dense: true, secondary: Icon(icon, size: 20, color: Colors.white70),
            title: Text(label, style: const TextStyle(fontSize: 14)), value: value, onChanged: change);
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 480, height: MediaQuery.of(c).size.height * .88,
              child: Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 18, 12, 14), child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF1A6CFF).withOpacity(.16), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.nightlight_round, color: Color(0xFF5B9AFF))),
                  const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Diário do sono', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('${dia.day.toString().padLeft(2,'0')}/${dia.month.toString().padLeft(2,'0')}/${dia.year} • Registre sua noite',
                      style: TextStyle(fontSize: 12, color: Theme.of(c).colorScheme.onSurfaceVariant)),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(c, false), icon: const Icon(Icons.close)),
                ])),
                Divider(height: 1, color: Colors.white.withOpacity(.08)),
                Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), children: [
                  secao('HORÁRIOS', Icons.schedule, [
                    Row(children: [
                      Expanded(child: campo('Foi dormir', dormir)),
                      const SizedBox(width: 10), Expanded(child: campo('Acordou', acordar)),
                    ]),
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF123B83), Color(0xFF17233C)]),
                      borderRadius: BorderRadius.circular(15)),
                      child: Row(children: [
                        const Icon(Icons.bedtime, color: Color(0xFF9CC4FF), size: 25), const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('TEMPO NA CAMA', style: TextStyle(fontSize: 10, letterSpacing: 1.1, color: Colors.white70)),
                          Text(previsto > 0 ? duracao(previsto) : 'Confira os horários',
                            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Text('SONO LÍQUIDO', style: TextStyle(fontSize: 9, color: Colors.white70)),
                          Text(previsto > 0 ? duracao(liquidoPrevisto) : '--',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ]),
                      ])),
                  ]),
                  secao('DURANTE A NOITE', Icons.bedtime_outlined, [
                    Row(children: [Expanded(child: campo('Para adormecer', latencia, numero: true, sufixo: 'min')),
                      const SizedBox(width: 9), Expanded(child: campo('Despertares', despertares, numero: true, sufixo: 'vezes'))]),
                    const SizedBox(height: 10),
                    Row(children: [Expanded(child: campo('Tempo acordado', tempoAcordado, numero: true, sufixo: 'min')),
                      const SizedBox(width: 9), Expanded(child: campo('Cochilos no dia', cochilo, numero: true, sufixo: 'min'))]),
                  ]),
                  secao('COMO VOCÊ SE SENTIU?', Icons.favorite_outline, [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Qualidade do sono', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('$qualidade/5', style: const TextStyle(color: Color(0xFF79AFFF), fontWeight: FontWeight.bold))]),
                    Slider(value: qualidade.toDouble(), min: 1, max: 5, divisions: 4,
                      onChanged: (v) => setDialog(() => qualidade = v.round())),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Nível de estresse', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('$estresse/5', style: const TextStyle(color: Color(0xFF79AFFF), fontWeight: FontWeight.bold))]),
                    Slider(value: estresse.toDouble(), min: 1, max: 5, divisions: 4,
                      onChanged: (v) => setDialog(() => estresse = v.round())),
                  ]),
                  secao('HÁBITOS E ROTINA', Icons.tune, [
                    check('Cafeína à tarde/noite', cafeina, (v) => setDialog(() => cafeina = v), Icons.coffee),
                    check('Usou telas antes de dormir', telas, (v) => setDialog(() => telas = v), Icons.phone_android),
                    check('Refeição pesada perto de dormir', refeicaoTardia, (v) => setDialog(() => refeicaoTardia = v), Icons.restaurant),
                  ]),
                  secao('OBSERVAÇÕES', Icons.notes, [
                    TextField(controller: notas, maxLines: 3, textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(hintText: 'Como foi seu dia? Algo afetou seu sono?',
                        filled: true, fillColor: Theme.of(c).colorScheme.surfaceContainerHighest.withOpacity(.38),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
                  ]),
                ])),
                Divider(height: 1, color: Colors.white.withOpacity(.08)),
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 14), child: Row(children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar'))),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: FilledButton.icon(
                    style: FilledButton.styleFrom(foregroundColor: Colors.white, iconColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.check), label: const Text('Salvar diário'))),
                ])),
              ]),
            ),
          );
        },
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
      Icon(icone, color: const Color(0xFF1A6CFF)), const SizedBox(height: 5),
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
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: const Color(0xFF3987FF).withOpacity(.25))),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF1769E8).withOpacity(.18), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.sensors, color: Color(0xFF65A5FF), size: 25)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Monitoramento pelo celular', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(_monitorando ? 'Sensores ativos • sessão em andamento' : 'Use os sensores disponíveis no aparelho', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ])),
                Container(width: 9, height: 9, decoration: BoxDecoration(color: _monitorando ? Colors.greenAccent : Colors.white30, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 7, runSpacing: 7, children: [
                _Legenda(cor: _sensores['acelerometro'] == true ? Colors.greenAccent : Colors.orangeAccent, texto: 'Movimento'),
                _Legenda(cor: _sensores['luz'] == true ? Colors.greenAccent : Colors.orangeAccent, texto: 'Luz'),
                _Legenda(cor: _sensores['proximidade'] == true ? Colors.greenAccent : Colors.orangeAccent, texto: 'Proximidade'),
              ]),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _alternarMonitoramento,
                icon: Icon(_monitorando ? Icons.stop_circle_outlined : Icons.nightlight_round),
                label: Text(_monitorando ? 'Encerrar monitoramento' : 'Iniciar monitoramento'),
                style: FilledButton.styleFrom(backgroundColor: _monitorando ? Colors.red.shade700 : const Color(0xFF1265E8), foregroundColor: Colors.white, iconColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              )),
              const SizedBox(height: 7),
              const Text('Analisa movimento e condições do ambiente. Não identifica fases REM ou sono profundo e não substitui avaliação médica.', style: TextStyle(fontSize: 11, color: Colors.white60)),
              if (_sensores['amostras'] != null) Text('Amostras de movimento: ${_sensores['amostras']} • Movimentos detectados: ${_sensores['movimentos'] ?? 0}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ])),
          ),
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
                  decoration: BoxDecoration(color: sel ? const Color(0xFF1A6CFF).withOpacity(.28) : Colors.white.withOpacity(.04), borderRadius: BorderRadius.circular(9), border: Border.all(color: sel ? const Color(0xFF1A6CFF) : Colors.white.withOpacity(.08))),
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
              FilledButton.icon(onPressed: editar, style: FilledButton.styleFrom(foregroundColor: Colors.white, iconColor: Colors.white), icon: const Icon(Icons.edit, color: Colors.white), label: Text(r == null ? 'Registrar sono' : 'Editar registro', style: const TextStyle(color: Colors.white))),
              if (r != null) TextButton.icon(onPressed: () => app.excluirSono(chave(dia)), icon: const Icon(Icons.delete_outline), label: const Text('Excluir')),
            ]),
          ]))),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Resumo do dia', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Treinos/cardio: ${app.sessoesDoDia(dia).length}'),
            Text('Nutrição: ${app.totalDia(chave(dia)).kcal.round()} kcal'),
            Text('Passos: ${app.passos[chave(dia)] ?? 0}'),
          ]))),
          const Padding(padding: EdgeInsets.fromLTRB(8, 2, 8, 8), child: Text('Seus registros de sono ficam salvos neste aparelho e continuam disponíveis ao reabrir o app. Para não perdê-los se trocar de celular ou reinstalar, faça uma exportação/backup dos dados em Configurações.\\n\\nUse os registros para observar padrões. As associações entre sono, treino, alimentação e hábitos não comprovam causa e efeito.', style: TextStyle(color: Colors.white60, fontSize: 12))),
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
