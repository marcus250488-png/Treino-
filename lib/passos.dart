import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'state.dart';
import 'telas.dart';
import 'nutri_modelo.dart';

// ============================================================
// Permissões (pede uma vez, com explicação)
// ============================================================
Future<void> pedirPermissoesInicial(BuildContext context) async {
  final p = await SharedPreferences.getInstance();
  if (p.getBool('perm_pedidas') ?? false) return;
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Permissões do app'),
      content: const Text(
        'Para funcionar por completo, o app precisa de:\n\n'
        '• Localização: para você escolher a sua academia pelo GPS.\n'
        '• Atividade física: para contar os seus passos.\n\n'
        'Você pode mudar isso depois nas configurações do celular.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Agora não')),
        TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Permitir')),
      ],
    ),
  );
  await p.setBool('perm_pedidas', true);
  if (ok != true) return;
  try {
    if (await Geolocator.checkPermission() == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  } catch (_) {}
  await app.iniciarPassos(pedir: true);
}

/// Pede, uma vez, para o app não ser fechado pelo Android com a tela apagada
/// (assim o treino em andamento continua de onde parou).
Future<void> pedirBateriaUmaVez(BuildContext context) async {
  final p = await SharedPreferences.getInstance();
  if (p.getBool('perm_bateria') ?? false) return;
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Manter o app ativo no treino'),
      content: const Text(
        'A tela do app já fica ligada enquanto ele está aberto.\n\n'
        'Para o Android não fechar o app quando você bloqueia a tela no meio do '
        'treino, permita que ele rode sem restrição de bateria.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Agora não')),
        TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Permitir')),
      ],
    ),
  );
  await p.setBool('perm_bateria', true);
  if (ok != true) return;
  try {
    await Permission.ignoreBatteryOptimizations.request();
  } catch (_) {}
}

// ============================================================
// Card de passos (tela inicial)
// ============================================================
class PassosCard extends StatelessWidget {
  const PassosCard({super.key});

  Future<void> _editarMeta(BuildContext context) async {
    final c = TextEditingController(text: '${app.metaPassos}');
    final v = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Meta diária de passos'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Passos por dia'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final n = int.tryParse(c.text.trim());
              Navigator.pop(d, (n != null && n >= 500) ? n : null);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (v != null) await app.setMetaPassos(v);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => ValueListenableBuilder<int>(
        valueListenable: app.passosHoje,
        builder: (context, _, __) {
          final passos = app.passos[chaveData(DateTime.now())] ?? 0;
          final meta = app.metaPassos;
          final prog = meta > 0 ? (passos / meta).clamp(0.0, 1.0).toDouble() : 0.0;
          final peso = app.pesoAtual ?? 70;
          final alt = app.alturaAtual;
          final passoM = alt != null ? alt * 0.415 / 100 : 0.75;
          final km = passos * passoM / 1000;
          final kcal = passos * 0.04 * (peso / 70);
          final min = passos / 100;
          return Vidro(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_walk, color: kAzul),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Passos de hoje', style: titulo(26))),
                    if (!app.passosAtivo)
                      TextButton(
                        onPressed: () => app.iniciarPassos(pedir: true),
                        child: const Text('Ativar'),
                      ),
                  ],
                ),
                if (!app.passosAtivo)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(
                      app.erroPassos ??
                          'Ative a permissão de atividade física para contar os passos.',
                      style: const TextStyle(color: kMudo, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 6),
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: titulo(54),
                      children: [
                        TextSpan(text: '$passos'),
                        TextSpan(
                          text: ' / $meta',
                          style: titulo(26).copyWith(color: kMudo),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: prog,
                    minHeight: 8,
                    backgroundColor: branco(.1),
                    color: kAzul,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _editarMeta(context),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Editar meta'),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _mini(Icons.schedule, '${fmtD(min)} min', 'Tempo'),
                      _mini(Icons.local_fire_department_outlined,
                          fmtD(kcal), 'Kcal'),
                      _mini(Icons.place_outlined, fmtD(km, 2), 'km'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _mini(IconData ic, String v, String r) => Column(
        children: [
          Icon(ic, color: const Color(0xFFFF4D7D), size: 22),
          const SizedBox(height: 4),
          Text(v, style: titulo(24)),
          Text(r, style: const TextStyle(color: kMudo, fontSize: 12)),
        ],
      );
}

// ============================================================
// Escolher a academia (GPS + OpenStreetMap)
// ============================================================
class _Academia {
  final String nome;
  final double lat, lon, dist;
  const _Academia(this.nome, this.lat, this.lon, this.dist);
}

class AcademiaTela extends StatefulWidget {
  const AcademiaTela({super.key});
  @override
  State<AcademiaTela> createState() => _AcademiaEstado();
}

class _AcademiaEstado extends State<AcademiaTela> {
  bool _carregando = true;
  String? _erro;
  bool _negadoParaSempre = false;
  List<_Academia> _lista = [];
  final _manual = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _carregando = true;
      _erro = null;
      _negadoParaSempre = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _carregando = false;
          _erro = 'Ative o GPS (localização) do celular e tente de novo.';
        });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _carregando = false;
          _negadoParaSempre = perm == LocationPermission.deniedForever;
          _erro = 'Sem permissão de localização. Você pode digitar o nome da academia abaixo.';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final r = await _overpass(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _lista = r;
        _carregando = false;
        _erro = r.isEmpty
            ? 'Não encontrei academias num raio de 5 km. Digite o nome abaixo.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro =
            'Não consegui buscar as academias agora (GPS ou internet). Você pode digitar o nome abaixo.';
      });
    }
  }

  Future<List<_Academia>> _overpass(double lat, double lon) async {
    final q = '[out:json][timeout:20];('
        'node(around:5000,$lat,$lon)["leisure"="fitness_centre"];'
        'way(around:5000,$lat,$lon)["leisure"="fitness_centre"];'
        'node(around:5000,$lat,$lon)["amenity"="gym"];'
        'way(around:5000,$lat,$lon)["amenity"="gym"];'
        ');out center 60;';
    final r = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      headers: {'User-Agent': 'MeuTreino/1.0 (app pessoal de treino)'},
      body: {'data': q},
    ).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('Erro ${r.statusCode}');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final vistos = <String>{};
    final out = <_Academia>[];
    for (final e in (j['elements'] as List? ?? const [])) {
      final m = e as Map;
      final tags = m['tags'];
      if (tags is! Map) continue;
      final nome = ('${tags['name'] ?? ''}').trim();
      if (nome.isEmpty) continue;
      final centro = m['center'];
      final la = (m['lat'] ?? (centro is Map ? centro['lat'] : null)) as num?;
      final lo = (m['lon'] ?? (centro is Map ? centro['lon'] : null)) as num?;
      if (la == null || lo == null) continue;
      final chave = '${norm(nome)}_${la.toStringAsFixed(3)}_${lo.toStringAsFixed(3)}';
      if (!vistos.add(chave)) continue;
      final d = Geolocator.distanceBetween(
          lat, lon, la.toDouble(), lo.toDouble());
      out.add(_Academia(nome, la.toDouble(), lo.toDouble(), d));
    }
    out.sort((a, b) => a.dist.compareTo(b.dist));
    return out.take(25).toList();
  }

  String _dist(double m) =>
      m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  @override
  Widget build(BuildContext context) {
    final atual = app.academia?['nome'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text('Minha academia', style: titulo(28))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (atual != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Vidro(
                padding: const EdgeInsets.all(14),
                raio: 20,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: kAzul),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Atual: $atual',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await app.salvarAcademia(null);
                        if (mounted) setState(() {});
                      },
                      child: const Text('Remover'),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text('Academias perto de você',
                    style: titulo(26)),
              ),
              IconButton(
                tooltip: 'Buscar de novo',
                onPressed: _carregando ? null : _buscar,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_carregando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_erro!, style: const TextStyle(color: kMudo)),
                  if (_negadoParaSempre)
                    TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: const Text('Abrir configurações do app'),
                    ),
                ],
              ),
            ),
          for (final a in _lista)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: branco(.07),
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  leading: const Icon(Icons.fitness_center, color: kAzul),
                  title: Text(a.nome),
                  subtitle: Text('a ${_dist(a.dist)}',
                      style: const TextStyle(color: kMudo, fontSize: 12)),
                  trailing: a.nome == atual
                      ? const Icon(Icons.check_circle, color: kAzul)
                      : null,
                  onTap: () async {
                    await app.salvarAcademia(
                        {'nome': a.nome, 'lat': a.lat, 'lon': a.lon});
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ),
          const SizedBox(height: 14),
          Text('Não achou? Digite', style: titulo(24)),
          const SizedBox(height: 8),
          TextField(
            controller: _manual,
            decoration: InputDecoration(
              hintText: 'Nome da sua academia',
              filled: true,
              fillColor: branco(.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: estiloPrimario,
            onPressed: () async {
              final n = _manual.text.trim();
              if (n.isEmpty) return;
              await app.salvarAcademia({'nome': n});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Usar este nome'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Dados de locais do OpenStreetMap. Nem toda academia está cadastrada lá.',
            style: TextStyle(color: kMudo, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
