import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

String norm(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  var t = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    t = t.replaceAll(from[i], to[i]);
  }
  return t
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String chaveData(DateTime d) => '${d.year}-${d.month}-${d.day}';

class Exercicio {
  final String id, nome, grupo, equip;
  final List<String> apelidos;
  final bool custom;
  Exercicio({
    required this.id,
    required this.nome,
    required this.grupo,
    this.equip = '',
    this.apelidos = const [],
    this.custom = false,
  });
  factory Exercicio.fromJson(Map<String, dynamic> j) => Exercicio(
        id: j['id'] as String,
        nome: j['nome'] as String,
        grupo: j['grupo'] as String,
        equip: (j['equip'] ?? '') as String,
        apelidos: List<String>.from(j['apelidos'] ?? []),
        custom: (j['custom'] ?? false) as bool,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'grupo': grupo,
        'equip': equip,
        'apelidos': apelidos,
        'custom': custom,
      };
}

class Item {
  String exId;
  final String nome, grupo, reps;
  final int series;
  Item({
    required this.exId,
    required this.nome,
    required this.grupo,
    required this.series,
    required this.reps,
  });
  factory Item.fromJson(Map<String, dynamic> j) => Item(
        exId: j['exId'] as String,
        nome: j['nome'] as String,
        grupo: j['grupo'] as String,
        series: j['series'] as int,
        reps: j['reps'] as String,
      );
  Map<String, dynamic> toJson() => {
        'exId': exId,
        'nome': nome,
        'grupo': grupo,
        'series': series,
        'reps': reps,
      };
}

class Dia {
  final String nome;
  final int weekday;
  String foco;
  final List<Item> itens;
  Dia({
    required this.nome,
    required this.weekday,
    this.foco = '',
    required this.itens,
  });
  factory Dia.fromJson(Map<String, dynamic> j) => Dia(
        nome: j['nome'] as String,
        weekday: j['weekday'] as int,
        foco: (j['foco'] ?? '') as String,
        itens: (j['itens'] as List)
            .map((e) => Item.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
  Map<String, dynamic> toJson() => {
        'nome': nome,
        'weekday': weekday,
        'foco': foco,
        'itens': itens.map((e) => e.toJson()).toList(),
      };
}

class Sessao {
  final String data, dia;
  final int seg, series, seriesTotal;
  final double volume;
  final bool completo;
  Sessao({
    required this.data,
    required this.dia,
    required this.seg,
    required this.series,
    required this.seriesTotal,
    required this.volume,
    required this.completo,
  });
  factory Sessao.fromJson(Map<String, dynamic> j) => Sessao(
        data: j['data'] as String,
        dia: j['dia'] as String,
        seg: j['seg'] as int,
        series: j['series'] as int,
        seriesTotal: j['seriesTotal'] as int,
        volume: (j['volume'] as num).toDouble(),
        completo: j['completo'] as bool,
      );
  Map<String, dynamic> toJson() => {
        'data': data,
        'dia': dia,
        'seg': seg,
        'series': series,
        'seriesTotal': seriesTotal,
        'volume': volume,
        'completo': completo,
      };
}

class Avaliacao {
  final String data;
  final Map<String, double> v;
  Avaliacao({required this.data, required this.v});
  factory Avaliacao.fromJson(Map<String, dynamic> j) => Avaliacao(
        data: j['data'] as String,
        v: (j['v'] as Map)
            .map((k, x) => MapEntry(k as String, (x as num).toDouble())),
      );
  Map<String, dynamic> toJson() => {'data': data, 'v': v};
}

/// Média de repetições de textos como "12" ou "8-12".
double repsMedio(String r) {
  final n = RegExp(r'\d+')
      .allMatches(r)
      .map((m) => int.parse(m.group(0)!))
      .toList();
  if (n.isEmpty) return 0;
  return n.reduce((a, b) => a + b) / n.length;
}

// ---------- Correspondência com a biblioteca ----------
const _stop = {'na', 'no', 'de', 'da', 'do', 'com', 'e', 'a', 'o', 'em', 'para'};

Set<String> _tok(String s) =>
    norm(s).split(' ').where((t) => t.isNotEmpty && !_stop.contains(t)).toSet();

double _jac(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  return a.intersection(b).length / a.union(b).length;
}

class Achado {
  final Exercicio? ex;
  final double score;
  Achado(this.ex, this.score);
}

Achado melhor(String consulta, List<Exercicio> lib) {
  final q = _tok(consulta);
  Exercicio? best;
  var bs = 0.0;
  for (final e in lib) {
    var s = _jac(q, _tok(e.nome));
    for (final a in e.apelidos) {
      final sa = _jac(q, _tok(a));
      if (sa > s) s = sa;
    }
    if (s > bs) {
      bs = s;
      best = e;
    }
  }
  return Achado(best, bs);
}

// ---------- Leitura do texto do PDF ----------
const _nomesDia = {
  1: 'Segunda-feira',
  2: 'Terça-feira',
  3: 'Quarta-feira',
  4: 'Quinta-feira',
  5: 'Sexta-feira',
  6: 'Sábado',
  7: 'Domingo',
};

int _weekday(String n) {
  if (n.startsWith('segunda')) return 1;
  if (n.startsWith('terca')) return 2;
  if (n.startsWith('quarta')) return 3;
  if (n.startsWith('quinta')) return 4;
  if (n.startsWith('sexta')) return 5;
  if (n.startsWith('sabado')) return 6;
  return 7;
}

List<Dia> lerPlano(String bruto, List<Exercicio> lib) {
  final texto = bruto
      .replaceAll(RegExp(r'PLANO DE TREINO.*?P[áa]gina\s*\d+'), '\n')
      .replaceAll('•', '\n•');
  final diaRe =
      RegExp(r'^(segunda|terca|quarta|quinta|sexta|sabado|domingo)( feira)?$');
  final exRe = RegExp(
      r'^[•\-\*]\s*(.+?)\s*[—–-]\s*(\d+)\s*[x×X]\s*(\d+(?:\s*[–-]\s*\d+)?)');
  final dias = <Dia>[];
  Dia? atual;
  var grupo = '';
  for (final l in texto.split(RegExp(r'\r?\n'))) {
    final line = l.trim();
    if (line.isEmpty) continue;
    final n = norm(line);
    if (n.startsWith('orientacoes gerais')) break;
    if (diaRe.hasMatch(n)) {
      final wd = _weekday(n);
      atual = Dia(nome: _nomesDia[wd]!, weekday: wd, itens: []);
      dias.add(atual);
      grupo = '';
      continue;
    }
    if (atual == null) continue;
    if (n.startsWith('foco')) {
      atual.foco = line.replaceFirst(RegExp(r'^[Ff]oco:\s*'), '');
      continue;
    }
    final m = exRe.firstMatch(line);
    if (m != null) {
      final nome = m.group(1)!.trim();
      final r = melhor(nome, lib);
      atual.itens.add(Item(
        exId: (r.ex != null && r.score >= 0.6) ? r.ex!.id : '',
        nome: nome,
        grupo: grupo.isEmpty ? 'Outros' : grupo,
        series: int.parse(m.group(2)!),
        reps: m.group(3)!.replaceAll(RegExp(r'\s'), ''),
      ));
      continue;
    }
    if (line == line.toUpperCase() && RegExp(r'[A-ZÀ-Ú]').hasMatch(line)) {
      final t = line.toLowerCase();
      grupo = t[0].toUpperCase() + t.substring(1);
    }
  }
  return dias.where((d) => d.itens.isNotEmpty).toList();
}

// ---------- Estado do app ----------
class AppState extends ChangeNotifier {
  List<Exercicio> lib = [];
  List<Dia> plano = [];
  Set<String> feitos = {};
  Map<String, String> cargas = {};
  Map<String, String> obs = {};
  List<Sessao> sessoes = [];
  List<Avaliacao> avaliacoes = [];
  Map<String, int> agua = {};
  int metaAgua = 2500;
  double? metaPeso;
  int descanso = 75;
  late SharedPreferences _p;

  // Conta Google (opcional: o app funciona sem login)
  final GoogleSignIn _g = GoogleSignIn(scopes: ['email']);
  String? nome, email, foto;
  bool pulouLogin = false;
  bool get logado => email != null;
  String get primeiroNome =>
      (nome == null || nome!.trim().isEmpty) ? '' : nome!.trim().split(' ').first;

  void _guardarConta(GoogleSignInAccount? c) {
    nome = c?.displayName;
    email = c?.email;
    foto = c?.photoUrl;
    if (c == null) {
      _p.remove('g_nome');
      _p.remove('g_email');
      _p.remove('g_foto');
    } else {
      _p.setString('g_nome', nome ?? '');
      _p.setString('g_email', email ?? '');
      _p.setString('g_foto', foto ?? '');
    }
  }

  /// Retorna null se deu certo, ou a mensagem de erro.
  Future<String?> entrar() async {
    try {
      final c = await _g.signIn();
      if (c == null) return 'Login cancelado';
      _guardarConta(c);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Não consegui entrar com o Google: $e';
    }
  }

  Future<void> sair() async {
    try {
      await _g.signOut();
    } catch (_) {}
    _guardarConta(null);
    pulouLogin = true;
    await _p.setBool('pulou_login', true);
    notifyListeners();
  }

  Future<void> pularLogin() async {
    pulouLogin = true;
    await _p.setBool('pulou_login', true);
    notifyListeners();
  }

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    final base =
        jsonDecode(await rootBundle.loadString('assets/exercicios.json'))
            as List;
    lib = base
        .map((e) => Exercicio.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final c = _p.getString('custom');
    if (c != null) {
      lib.addAll((jsonDecode(c) as List).map(
          (e) => Exercicio.fromJson(Map<String, dynamic>.from(e as Map))));
    }
    final pl = _p.getString('plano');
    if (pl != null) {
      plano = (jsonDecode(pl) as List)
          .map((e) => Dia.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    feitos = (_p.getStringList('feitos') ?? []).toSet();
    descanso = _p.getInt('descanso') ?? 75;
    metaAgua = _p.getInt('meta_agua') ?? 2500;
    metaPeso = _p.getDouble('meta_peso');
    final ss = _p.getString('sessoes');
    if (ss != null) {
      sessoes = (jsonDecode(ss) as List)
          .map((e) => Sessao.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final av = _p.getString('avaliacoes');
    if (av != null) {
      avaliacoes = (jsonDecode(av) as List)
          .map((e) => Avaliacao.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final ag = _p.getString('agua');
    if (ag != null) agua = Map<String, int>.from(jsonDecode(ag) as Map);
    final ob = _p.getString('obs');
    if (ob != null) obs = Map<String, String>.from(jsonDecode(ob) as Map);
    pulouLogin = _p.getBool('pulou_login') ?? false;
    final ge = _p.getString('g_email');
    if (ge != null && ge.isNotEmpty) {
      email = ge;
      nome = _p.getString('g_nome');
      final gf = _p.getString('g_foto');
      foto = (gf == null || gf.isEmpty) ? null : gf;
      // Atualiza foto/nome em segundo plano sem travar a abertura do app
      _g.signInSilently().then((c) {
        if (c != null) {
          _guardarConta(c);
          notifyListeners();
        }
      }).catchError((_) {});
    }
    final cg = _p.getString('cargas');
    if (cg != null) {
      cargas = Map<String, String>.from(jsonDecode(cg) as Map);
    }
  }

  Exercicio? ex(String id) {
    for (final e in lib) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Treino exatamente do dia da semana de [d] (null = dia de descanso).
  Dia? treinoNo(DateTime d) {
    for (final x in plano) {
      if (x.weekday == d.weekday) return x;
    }
    return null;
  }

  Dia? treinoDe(DateTime d) {
    if (plano.isEmpty) return null;
    for (final x in plano) {
      if (x.weekday == d.weekday) return x;
    }
    for (final x in plano) {
      if (x.weekday > d.weekday) return x;
    }
    return plano.first;
  }

  Future<void> _salvarCustom() => _p.setString(
      'custom', jsonEncode(lib.where((e) => e.custom).map((e) => e.toJson()).toList()));

  Future<void> addCustom(String nome, String grupo) async {
    lib.add(Exercicio(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      nome: nome,
      grupo: grupo.isEmpty ? 'Outros' : grupo,
      custom: true,
    ));
    await _salvarCustom();
    notifyListeners();
  }

  Future<void> salvarPlano(List<Dia> dias) async {
    var n = 0;
    for (final d in dias) {
      for (final it in d.itens) {
        if (it.exId.isEmpty) {
          final id = 'c_${DateTime.now().microsecondsSinceEpoch}_${n++}';
          lib.add(Exercicio(
              id: id, nome: it.nome, grupo: it.grupo, custom: true));
          it.exId = id;
        }
      }
    }
    plano = dias;
    await _salvarCustom();
    await _p.setString(
        'plano', jsonEncode(plano.map((d) => d.toJson()).toList()));
    notifyListeners();
  }

  Future<void> concluirDia(DateTime d) async {
    feitos.add(chaveData(d));
    await _p.setStringList('feitos', feitos.toList());
    notifyListeners();
  }

  Future<void> setObs(String id, String v) async {
    if (v.trim().isEmpty) {
      obs.remove(id);
    } else {
      obs[id] = v;
    }
    await _p.setString('obs', jsonEncode(obs));
  }

  Future<void> setDescanso(int s) async {
    descanso = s;
    await _p.setInt('descanso', s);
    notifyListeners();
  }

  Future<void> addSessao(Sessao s) async {
    sessoes.add(s);
    await _p.setString(
        'sessoes', jsonEncode(sessoes.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> addAvaliacao(Map<String, double> v) async {
    avaliacoes.add(Avaliacao(data: DateTime.now().toIso8601String(), v: v));
    await _p.setString(
        'avaliacoes', jsonEncode(avaliacoes.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> setMetaPeso(double v) async {
    metaPeso = v;
    await _p.setDouble('meta_peso', v);
    notifyListeners();
  }

  Future<void> setMetaAgua(int ml) async {
    metaAgua = ml;
    await _p.setInt('meta_agua', ml);
    notifyListeners();
  }

  Future<void> addAgua(DateTime d, int ml) async {
    final k = chaveData(d);
    final novo = (agua[k] ?? 0) + ml;
    agua[k] = novo < 0 ? 0 : novo;
    await _p.setString('agua', jsonEncode(agua));
    notifyListeners();
  }

  String exportar() => JsonEncoder.withIndent('  ').convert({
        'exportado_em': DateTime.now().toIso8601String(),
        'conta': {'nome': nome, 'email': email},
        'plano': plano.map((d) => d.toJson()).toList(),
        'sessoes': sessoes.map((e) => e.toJson()).toList(),
        'avaliacoes': avaliacoes.map((e) => e.toJson()).toList(),
        'agua_ml_por_dia': agua,
        'meta_agua_ml': metaAgua,
        'meta_peso': metaPeso,
        'descanso_s': descanso,
        'cargas': cargas,
        'observacoes': obs,
        'dias_concluidos': feitos.toList(),
      });

  Future<void> setCarga(String id, String v) async {
    cargas[id] = v;
    await _p.setString('cargas', jsonEncode(cargas));
  }
}

final app = AppState();
