import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_config.dart';
import 'nutri_modelo.dart';

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

DateTime? dataDaChave(String valor) {
  final partes = valor.split('-');
  if (partes.length == 3) {
    final ano = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final dia = int.tryParse(partes[2]);
    if (ano != null && mes != null && dia != null) {
      try { return DateTime(ano, mes, dia); } catch (_) {}
    }
  }
  return DateTime.tryParse(valor);
}

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
  String nome, grupo, reps;
  int series;
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
  String? imagem; // null = automática
  final List<Item> itens;
  Dia({
    required this.nome,
    required this.weekday,
    this.foco = '',
    this.imagem,
    required this.itens,
  });
  factory Dia.fromJson(Map<String, dynamic> j) => Dia(
        nome: j['nome'] as String,
        weekday: j['weekday'] as int,
        foco: (j['foco'] ?? '') as String,
        imagem: j['imagem'] as String?,
        itens: (j['itens'] as List)
            .map((e) => Item.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
  Map<String, dynamic> toJson() => {
        'nome': nome,
        'weekday': weekday,
        'foco': foco,
        'imagem': imagem,
        'itens': itens.map((e) => e.toJson()).toList(),
      };
}

class Sessao {
  final String data, dia;
  final int seg, series, seriesTotal;
  final double volume;
  final bool completo;
  final bool livre;
  final String? tipo, modalidade; // tipo 'cardio' para sessões de cardio
  final double? km;
  final int? kcal, fc;
  Sessao({
    required this.data,
    required this.dia,
    required this.seg,
    required this.series,
    required this.seriesTotal,
    required this.volume,
    required this.completo,
    this.livre = false,
    this.tipo,
    this.modalidade,
    this.km,
    this.kcal,
    this.fc,
  });
  bool get cardio => tipo == 'cardio';
  String get resumoCardio {
    final partes = <String>['${(seg / 60).round()} min'];
    if (km != null && km! > 0) {
      partes.add('${km!.toStringAsFixed(2).replaceAll('.', ',')} km');
    }
    if (kcal != null) partes.add('$kcal kcal');
    if (fc != null && fc! > 0) partes.add('$fc bpm');
    return partes.join(' • ');
  }

  factory Sessao.fromJson(Map<String, dynamic> j) => Sessao(
        data: j['data'] as String,
        dia: j['dia'] as String,
        seg: j['seg'] as int,
        series: j['series'] as int,
        seriesTotal: j['seriesTotal'] as int,
        volume: (j['volume'] as num).toDouble(),
        completo: j['completo'] as bool,
        livre: (j['livre'] ?? false) as bool,
        tipo: j['tipo'] as String?,
        modalidade: j['modalidade'] as String?,
        km: (j['km'] as num?)?.toDouble(),
        kcal: (j['kcal'] as num?)?.toInt(),
        fc: (j['fc'] as num?)?.toInt(),
      );
  Map<String, dynamic> toJson() => {
        'data': data,
        'dia': dia,
        'seg': seg,
        'series': series,
        'seriesTotal': seriesTotal,
        'volume': volume,
        'completo': completo,
        'livre': livre,
        'tipo': tipo,
        'modalidade': modalidade,
        'km': km,
        'kcal': kcal,
        'fc': fc,
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
  List<Exercicio> _base = [];
  List<Dia> plano = [];
  DateTime? inicioPlano;
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

  // Nutrição
  List<Alimento> _alimBase = [];
  List<Alimento> alimentos = [];
  List<Receita> receitas = [];
  Map<String, dynamic> alimOver = {};
  Map<String, dynamic> exOver = {};
  Map<String, dynamic> perfil = {};
  Map<String, dynamic> diario = {}; // dia -> refeição -> [entradas]
  Map<String, dynamic> cardapio = {}; // refeição -> [entradas]

  // Conta Google + nuvem (Firebase). Cada conta tem seus próprios dados.
  final GoogleSignIn _g =
      GoogleSignIn(scopes: ['email'], serverClientId: kWebClientId);
  String? nome, email, foto, uid;
  bool pulouLogin = false;
  bool nuvemOk = false; // Firebase iniciou
  bool _nuvemPronta = false; // primeira sincronização concluída
  bool sincronizando = false;
  String? erroNuvem;
  DateTime? ultimaSync;
  Timer? _timerEnvio, _timerRetry;
  bool _aplicando = false;
  String _pre = ''; // prefixo local por conta
  String _k(String k) => '$_pre$k';

  bool get logado => email != null;
  String get primeiroNome =>
      (nome == null || nome!.trim().isEmpty) ? '' : nome!.trim().split(' ').first;

  DocumentReference<Map<String, dynamic>> _doc(String u) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(u)
      .collection('dados')
      .doc('estado');

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
    if (!nuvemOk) {
      return 'A nuvem não iniciou${erroNuvem == null ? '' : ': $erroNuvem'}';
    }
    try {
      final c = await _g.signIn();
      if (c == null) return 'Login cancelado';
      final a = await c.authentication;
      final cred = GoogleAuthProvider.credential(
          accessToken: a.accessToken, idToken: a.idToken);
      final r = await FirebaseAuth.instance.signInWithCredential(cred);
      final u = r.user;
      if (u == null) return 'Não consegui entrar com o Google.';
      _timerEnvio?.cancel();
      _nuvemPronta = false;
      uid = u.uid;
      await _p.setString('g_uid', u.uid);
      _pre = 'u_${u.uid}_';
      _carregarLocal();
      _guardarConta(c);
      await sincronizar();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Não consegui entrar com o Google: $e';
    }
  }

  Future<void> sair() async {
    _enviar(); // garante o último envio antes de sair
    try {
      await _g.signOut();
    } catch (_) {}
    try {
      if (nuvemOk) await FirebaseAuth.instance.signOut();
    } catch (_) {}
    _timerEnvio?.cancel();
    _timerRetry?.cancel();
    _guardarConta(null);
    uid = null;
    await _p.remove('g_uid');
    _pre = '';
    _nuvemPronta = false;
    pulouLogin = false; // volta para a tela de login (trocar de conta)
    await _p.setBool('pulou_login', false);
    _carregarLocal();
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
    _base = base
        .map((e) => Exercicio.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final nu = jsonDecode(await rootBundle.loadString('assets/nutricao.json'))
        as Map<String, dynamic>;
    _alimBase = (nu['alimentos'] as List)
        .map((e) => Alimento.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    receitas = (nu['receitas'] as List)
        .map((e) => Receita.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    try {
      await Firebase.initializeApp(options: kFirebaseOptions);
      nuvemOk = true;
    } catch (e) {
      erroNuvem = '$e';
    }
    pulouLogin = _p.getBool('pulou_login') ?? false;
    final ge = _p.getString('g_email');
    var u = _p.getString('g_uid');
    if (nuvemOk) u = FirebaseAuth.instance.currentUser?.uid ?? u;
    // Conta de versão antiga (sem nuvem): pede um novo login para sincronizar.
    if (ge != null && ge.isNotEmpty && u != null && u.isNotEmpty) {
      email = ge;
      uid = u;
      nome = _p.getString('g_nome');
      final gf = _p.getString('g_foto');
      foto = (gf == null || gf.isEmpty) ? null : gf;
      _pre = 'u_${u}_';
    }
    _carregarLocal();
    if (uid != null) {
      _g.signInSilently().then((c) {
        if (c != null) {
          _guardarConta(c);
          notifyListeners();
        }
      }).catchError((_) {});
      unawaited(sincronizar());
    }
  }

  // ---------- Leitura/gravação local (por conta) ----------
  Map<String, dynamic> _lerLocal() => {
        'plano': _p.getString(_k('plano')),
        'custom': _p.getString(_k('custom')),
        'feitos': _p.getStringList(_k('feitos')),
        'inicio_plano': _p.getString(_k('inicio_plano')),
        'descanso': _p.getInt(_k('descanso')),
        'meta_agua': _p.getInt(_k('meta_agua')),
        'meta_peso': _p.getDouble(_k('meta_peso')),
        'sessoes': _p.getString(_k('sessoes')),
        'avaliacoes': _p.getString(_k('avaliacoes')),
        'agua': _p.getString(_k('agua')),
        'obs': _p.getString(_k('obs')),
        'cargas': _p.getString(_k('cargas')),
        'ex_over': _p.getString(_k('ex_over')),
        'alim_over': _p.getString(_k('alim_over')),
        'alim_custom': _p.getString(_k('alim_custom')),
        'perfil': _p.getString(_k('perfil')),
        'diario': _p.getString(_k('diario')),
        'cardapio': _p.getString(_k('cardapio')),
      };

  Map<String, dynamic> _empacotar() => {
        'plano': jsonEncode(plano.map((d) => d.toJson()).toList()),
        'custom': jsonEncode(
            lib.where((e) => e.custom).map((e) => e.toJson()).toList()),
        'feitos': feitos.toList(),
        'inicio_plano': inicioPlano?.toIso8601String(),
        'descanso': descanso,
        'meta_agua': metaAgua,
        'meta_peso': metaPeso,
        'sessoes': jsonEncode(sessoes.map((e) => e.toJson()).toList()),
        'avaliacoes': jsonEncode(avaliacoes.map((e) => e.toJson()).toList()),
        'agua': jsonEncode(agua),
        'obs': jsonEncode(obs),
        'cargas': jsonEncode(cargas),
        'ex_over': jsonEncode(exOver),
        'alim_over': jsonEncode(alimOver),
        'alim_custom': jsonEncode(
            alimentos.where((a) => a.custom).map((a) => a.toJson()).toList()),
        'perfil': jsonEncode(perfil),
        'diario': jsonEncode(diario),
        'cardapio': jsonEncode(cardapio),
        'atualizado_em': DateTime.now().toIso8601String(),
      };

  List _lista(dynamic s) => (s is String && s.isNotEmpty)
      ? (jsonDecode(s) as List)
      : <dynamic>[];
  Map _mapa(dynamic s) => (s is String && s.isNotEmpty)
      ? (jsonDecode(s) as Map)
      : <dynamic, dynamic>{};

  /// Coloca os dados do mapa (local ou nuvem) nos campos do app.
  void _aplicar(Map<String, dynamic> d) {
    plano = _lista(d['plano'])
        .map((e) => Dia.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    exOver = Map<String, dynamic>.from(_mapa(d['ex_over']));
    alimOver = Map<String, dynamic>.from(_mapa(d['alim_over']));
    perfil = Map<String, dynamic>.from(_mapa(d['perfil']));
    diario = Map<String, dynamic>.from(_mapa(d['diario']));
    cardapio = Map<String, dynamic>.from(_mapa(d['cardapio']));
    lib = [
      ..._base.map(_comOverEx),
      ..._lista(d['custom'])
          .map((e) => Exercicio.fromJson(Map<String, dynamic>.from(e as Map))),
    ];
    alimentos = [
      ..._alimBase.map(_comOverAlim),
      ..._lista(d['alim_custom'])
          .map((e) => Alimento.fromJson(Map<String, dynamic>.from(e as Map))),
    ];
    feitos = ((d['feitos'] as List?) ?? const []).map((e) => '$e').toSet();
    final ini = d['inicio_plano'];
    inicioPlano = ini is String ? DateTime.tryParse(ini) : null;
    descanso = (d['descanso'] as num?)?.toInt() ?? 75;
    metaAgua = (d['meta_agua'] as num?)?.toInt() ?? 2500;
    metaPeso = (d['meta_peso'] as num?)?.toDouble();
    sessoes = _lista(d['sessoes'])
        .map((e) => Sessao.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    avaliacoes = _lista(d['avaliacoes'])
        .map((e) => Avaliacao.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    agua = Map<String, int>.from(
        _mapa(d['agua']).map((k, v) => MapEntry('$k', (v as num).toInt())));
    obs = Map<String, String>.from(
        _mapa(d['obs']).map((k, v) => MapEntry('$k', '$v')));
    cargas = Map<String, String>.from(
        _mapa(d['cargas']).map((k, v) => MapEntry('$k', '$v')));
    if (inicioPlano == null && (plano.isNotEmpty || feitos.isNotEmpty)) {
      final datas = feitos.map(dataDaChave).whereType<DateTime>().toList();
      if (datas.isNotEmpty) datas.sort();
      final b = datas.isNotEmpty ? datas.first : DateTime.now();
      inicioPlano = DateTime(b.year, b.month, b.day)
          .subtract(Duration(days: b.weekday - 1));
    }
  }

  void _carregarLocal() => _aplicar(_lerLocal());

  Future<void> _salvarTudoLocal() async {
    final m = _empacotar();
    await _p.setString(_k('plano'), m['plano'] as String);
    await _p.setString(_k('custom'), m['custom'] as String);
    await _p.setStringList(_k('feitos'), feitos.toList());
    if (inicioPlano != null) {
      await _p.setString(_k('inicio_plano'), inicioPlano!.toIso8601String());
    } else {
      await _p.remove(_k('inicio_plano'));
    }
    await _p.setInt(_k('descanso'), descanso);
    await _p.setInt(_k('meta_agua'), metaAgua);
    if (metaPeso != null) {
      await _p.setDouble(_k('meta_peso'), metaPeso!);
    } else {
      await _p.remove(_k('meta_peso'));
    }
    await _p.setString(_k('sessoes'), m['sessoes'] as String);
    await _p.setString(_k('avaliacoes'), m['avaliacoes'] as String);
    await _p.setString(_k('agua'), m['agua'] as String);
    await _p.setString(_k('obs'), m['obs'] as String);
    await _p.setString(_k('cargas'), m['cargas'] as String);
    await _p.setString(_k('ex_over'), m['ex_over'] as String);
    await _p.setString(_k('alim_over'), m['alim_over'] as String);
    await _p.setString(_k('alim_custom'), m['alim_custom'] as String);
    await _p.setString(_k('perfil'), m['perfil'] as String);
    await _p.setString(_k('diario'), m['diario'] as String);
    await _p.setString(_k('cardapio'), m['cardapio'] as String);
  }

  // ---------- Nuvem ----------
  void _agendarEnvio() {
    if (_aplicando || uid == null || !nuvemOk) return;
    _timerEnvio?.cancel();
    _timerEnvio = Timer(const Duration(seconds: 2), _enviar);
  }

  void _enviar() {
    final u = uid;
    if (u == null || !nuvemOk || !_nuvemPronta) return;
    try {
      _doc(u).set(_empacotar()).then((_) {
        ultimaSync = DateTime.now();
        erroNuvem = null;
      }).catchError((Object e) {
        erroNuvem = '$e';
      });
    } catch (e) {
      erroNuvem = '$e';
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _agendarEnvio();
  }

  /// Traz os dados da nuvem (ou envia os do aparelho se a conta é nova).
  Future<void> sincronizar() async {
    final u = uid;
    if (u == null || !nuvemOk) return;
    sincronizando = true;
    try {
      final snap =
          await _doc(u).get().timeout(const Duration(seconds: 20));
      final d = snap.data();
      _aplicando = true;
      if (snap.exists && d != null && d.isNotEmpty) {
        _aplicar(d);
        await _salvarTudoLocal();
      } else {
        await _adotarLegado();
      }
      _aplicando = false;
      _nuvemPronta = true;
      if (!(snap.exists && d != null && d.isNotEmpty)) _enviar();
      erroNuvem = null;
      ultimaSync = DateTime.now();
      _timerRetry?.cancel();
    } catch (e) {
      _aplicando = false;
      erroNuvem = '$e';
      _timerRetry?.cancel();
      _timerRetry = Timer(const Duration(seconds: 30), () => sincronizar());
    } finally {
      sincronizando = false;
    }
    notifyListeners();
  }

  /// Primeira conta a entrar neste aparelho leva os dados que já estavam nele.
  Future<void> _adotarLegado() async {
    final jaMigrou = _p.getBool('legado_migrado') ?? false;
    const chaves = [
      'plano', 'custom', 'feitos', 'inicio_plano', 'descanso', 'meta_agua',
      'meta_peso', 'sessoes', 'avaliacoes', 'agua', 'obs', 'cargas',
      'ex_over', 'alim_over', 'alim_custom', 'perfil', 'diario', 'cardapio'
    ];
    final temLegado = _p.getString('plano') != null ||
        _p.getString('sessoes') != null ||
        _p.getString('avaliacoes') != null;
    if (jaMigrou || !temLegado) return;
    final pre = _pre;
    _pre = '';
    _carregarLocal();
    _pre = pre;
    await _salvarTudoLocal();
    await _p.setBool('legado_migrado', true);
    for (final k in chaves) {
      await _p.remove(k);
    }
  }

  // ---------- Restaurar dados exportados ----------
  Future<String?> importar(String texto) async {
    try {
      final m = jsonDecode(texto.trim()) as Map<String, dynamic>;
      plano = ((m['plano'] as List?) ?? const [])
          .map((e) => Dia.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      sessoes = ((m['sessoes'] as List?) ?? const [])
          .map((e) => Sessao.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      avaliacoes = ((m['avaliacoes'] as List?) ?? const [])
          .map((e) => Avaliacao.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      agua = Map<String, int>.from(((m['agua_ml_por_dia'] as Map?) ?? const {})
          .map((k, v) => MapEntry('$k', (v as num).toInt())));
      metaAgua = (m['meta_agua_ml'] as num?)?.toInt() ?? metaAgua;
      metaPeso = (m['meta_peso'] as num?)?.toDouble();
      descanso = (m['descanso_s'] as num?)?.toInt() ?? descanso;
      cargas = Map<String, String>.from(((m['cargas'] as Map?) ?? const {})
          .map((k, v) => MapEntry('$k', '$v')));
      obs = Map<String, String>.from(((m['observacoes'] as Map?) ?? const {})
          .map((k, v) => MapEntry('$k', '$v')));
      feitos = ((m['dias_concluidos'] as List?) ?? const [])
          .map((e) => '$e')
          .toSet();
      lib = [..._base.map(_comOverEx), ...lib.where((e) => e.custom)];
      for (final d in plano) {
        for (final it in d.itens) {
          if (it.exId.isNotEmpty && ex(it.exId) == null) {
            lib.add(Exercicio(
                id: it.exId, nome: it.nome, grupo: it.grupo, custom: true));
          }
        }
      }
      if (m['perfil'] is Map) {
        perfil = Map<String, dynamic>.from(m['perfil'] as Map);
      }
      if (m['diario'] is Map) {
        diario = Map<String, dynamic>.from(m['diario'] as Map);
      }
      if (m['cardapio'] is Map) {
        cardapio = Map<String, dynamic>.from(m['cardapio'] as Map);
      }
      if (m['alimentos_editados'] is Map) {
        alimOver = Map<String, dynamic>.from(m['alimentos_editados'] as Map);
      }
      if (m['exercicios_editados'] is Map) {
        exOver = Map<String, dynamic>.from(m['exercicios_editados'] as Map);
        lib = [..._base.map(_comOverEx), ...lib.where((e) => e.custom)];
      }
      alimentos = [
        ..._alimBase.map(_comOverAlim),
        ...((m['alimentos_proprios'] as List?) ?? const []).map((e) =>
            Alimento.fromJson(Map<String, dynamic>.from(e as Map))),
      ];
      inicioPlano = null;
      final datas = feitos.map(dataDaChave).whereType<DateTime>().toList();
      if (datas.isNotEmpty) datas.sort();
      final b = datas.isNotEmpty ? datas.first : DateTime.now();
      inicioPlano = DateTime(b.year, b.month, b.day)
          .subtract(Duration(days: b.weekday - 1));
      await atualizarPlano();
      await _salvarTudoLocal();
      notifyListeners();
      return null;
    } catch (e) {
      return 'Texto inválido: $e';
    }
  }

  // ---------- Edições de exercícios ----------
  Exercicio _comOverEx(Exercicio e) {
    final o = exOver[e.id];
    if (o is Map) {
      return Exercicio.fromJson(
          {...Map<String, dynamic>.from(o), 'id': e.id, 'custom': false});
    }
    return e;
  }

  Future<void> editarExercicio(Exercicio e,
      {required String nome,
      required String grupo,
      required String equip,
      required List<String> apelidos}) async {
    final novo = Exercicio(
        id: e.id,
        nome: nome,
        grupo: grupo,
        equip: equip,
        apelidos: apelidos,
        custom: e.custom);
    final i = lib.indexWhere((x) => x.id == e.id);
    if (i >= 0) lib[i] = novo;
    if (!e.custom) exOver[e.id] = novo.toJson();
    for (final d in plano) {
      for (final it in d.itens) {
        if (it.exId == e.id) {
          it.nome = nome;
          it.grupo = grupo;
        }
      }
    }
    await _p.setString(_k('ex_over'), jsonEncode(exOver));
    await atualizarPlano();
  }

  Future<void> restaurarExercicio(String id) async {
    exOver.remove(id);
    final i = lib.indexWhere((x) => x.id == id);
    final b = _base.where((x) => x.id == id).toList();
    if (i >= 0 && b.isNotEmpty) {
      lib[i] = b.first;
      for (final d in plano) {
        for (final it in d.itens) {
          if (it.exId == id) {
            it.nome = b.first.nome;
            it.grupo = b.first.grupo;
          }
        }
      }
    }
    await _p.setString(_k('ex_over'), jsonEncode(exOver));
    await atualizarPlano();
  }

  Future<void> excluirExercicio(String id) async {
    lib.removeWhere((x) => x.id == id && x.custom);
    await atualizarPlano();
  }

  // ---------- Nutrição ----------
  Alimento _comOverAlim(Alimento a) {
    final o = alimOver[a.id];
    if (o is Map) {
      return Alimento.fromJson(
          {...Map<String, dynamic>.from(o), 'id': a.id, 'custom': false});
    }
    return a;
  }

  Alimento? alimento(String id) {
    for (final a in alimentos) {
      if (a.id == id) return a;
    }
    return null;
  }

  Receita? receita(String id) {
    for (final r in receitas) {
      if (r.id == id) return r;
    }
    return null;
  }

  bool alimentoEditado(String id) => alimOver.containsKey(id);

  Macros macrosReceita(Receita r) {
    var t = const Macros();
    for (final i in r.ing) {
      final a = alimento(i.id);
      if (a != null) t = t + a.porGramas(i.g);
    }
    return t;
  }

  Macros macrosEntrada(Map e) {
    final q = (e['q'] as num).toDouble();
    final id = e['id'] as String;
    if (e['t'] == 'r') {
      final r = receita(id);
      return r == null ? const Macros() : macrosReceita(r) * q;
    }
    final a = alimento(id);
    return a == null ? const Macros() : a.porGramas(q);
  }

  String nomeEntrada(Map e) {
    final id = e['id'] as String;
    if (e['t'] == 'r') return receita(id)?.nome ?? 'Receita removida';
    return alimento(id)?.nome ?? 'Alimento removido';
  }

  String qtdEntrada(Map e) {
    final q = (e['q'] as num).toDouble();
    if (e['t'] == 'r') {
      return '${fmtD(q, 1)} ${q == 1 ? 'porção' : 'porções'}';
    }
    final a = alimento(e['id'] as String);
    var t = '${fmtD(q)} g';
    if (a != null && a.ug > 0 && a.un.isNotEmpty) {
      t += ' (≈ ${fmtD(q / a.ug, 1)} ${a.un})';
    }
    return t;
  }

  List<dynamic> _lerDia(String dia, String ref) {
    final d = diario[dia];
    if (d is! Map) return const [];
    final l = d[ref];
    return l is List ? l : const [];
  }

  List<dynamic> _listaDia(String dia, String ref) {
    final d = (diario[dia] ??= <String, dynamic>{}) as Map;
    return (d[ref] ??= <dynamic>[]) as List<dynamic>;
  }

  List<Map> entradasDe(String dia, String ref) =>
      _lerDia(dia, ref).map((e) => e as Map).toList();

  Macros totalRef(String dia, String ref) {
    var t = const Macros();
    for (final e in _lerDia(dia, ref)) {
      t = t + macrosEntrada(e as Map);
    }
    return t;
  }

  Macros totalDia(String dia) {
    var t = const Macros();
    for (final r in kRefeicoes) {
      t = t + totalRef(dia, r.id);
    }
    return t;
  }

  Future<void> _salvarNutri() async {
    await _p.setString(_k('diario'), jsonEncode(diario));
    await _p.setString(_k('cardapio'), jsonEncode(cardapio));
    notifyListeners();
  }

  Future<void> addEntrada(String dia, String ref, Map<String, dynamic> e) async {
    _listaDia(dia, ref).add(e);
    await _salvarNutri();
  }

  Future<void> removerEntrada(String dia, String ref, int i) async {
    final l = _listaDia(dia, ref);
    if (i >= 0 && i < l.length) l.removeAt(i);
    await _salvarNutri();
  }

  Future<void> setQtdEntrada(String dia, String ref, int i, double q) async {
    final l = _listaDia(dia, ref);
    if (i >= 0 && i < l.length) (l[i] as Map)['q'] = q;
    await _salvarNutri();
  }

  List<dynamic> _listaCardapio(String ref) =>
      (cardapio[ref] ??= <dynamic>[]) as List<dynamic>;

  List<Map> entradasCardapio(String ref) {
    final l = cardapio[ref];
    return l is List ? l.map((e) => e as Map).toList() : <Map>[];
  }

  Macros totalCardapio(String ref) {
    var t = const Macros();
    for (final e in entradasCardapio(ref)) {
      t = t + macrosEntrada(e);
    }
    return t;
  }

  Future<void> addCardapio(String ref, Map<String, dynamic> e) async {
    _listaCardapio(ref).add(e);
    await _salvarNutri();
  }

  Future<void> removerCardapio(String ref, int i) async {
    final l = _listaCardapio(ref);
    if (i >= 0 && i < l.length) l.removeAt(i);
    await _salvarNutri();
  }

  Future<void> setQtdCardapio(String ref, int i, double q) async {
    final l = _listaCardapio(ref);
    if (i >= 0 && i < l.length) (l[i] as Map)['q'] = q;
    await _salvarNutri();
  }

  Future<void> usarCardapio(String dia, String ref) async {
    for (final e in entradasCardapio(ref)) {
      _listaDia(dia, ref).add(Map<String, dynamic>.from(e));
    }
    await _salvarNutri();
  }

  Future<void> _salvarAlimentos() async {
    await _p.setString(
        _k('alim_custom'),
        jsonEncode(
            alimentos.where((a) => a.custom).map((a) => a.toJson()).toList()));
    await _p.setString(_k('alim_over'), jsonEncode(alimOver));
    notifyListeners();
  }

  Future<void> salvarAlimento(Alimento a) async {
    final i = alimentos.indexWhere((x) => x.id == a.id);
    if (i < 0) {
      alimentos.add(a);
    } else if (alimentos[i].custom) {
      alimentos[i] = a;
    } else {
      alimOver[a.id] = a.toJson();
      alimentos[i] = a;
    }
    await _salvarAlimentos();
  }

  Future<void> restaurarAlimento(String id) async {
    alimOver.remove(id);
    final i = alimentos.indexWhere((x) => x.id == id);
    final b = _alimBase.where((x) => x.id == id).toList();
    if (i >= 0 && b.isNotEmpty) alimentos[i] = b.first;
    await _salvarAlimentos();
  }

  Future<void> excluirAlimento(String id) async {
    alimentos.removeWhere((a) => a.id == id && a.custom);
    await _salvarAlimentos();
  }

  Future<void> salvarPerfil(Map<String, dynamic> p) async {
    perfil = p;
    await _p.setString(_k('perfil'), jsonEncode(perfil));
    notifyListeners();
  }

  double? get pesoAtual {
    for (final a in avaliacoes.reversed) {
      final p = a.v['peso'];
      if (p != null && p > 0) return p;
    }
    return (perfil['peso'] as num?)?.toDouble();
  }

  double? get alturaAtual {
    final h = (perfil['altura'] as num?)?.toDouble();
    if (h != null && h > 0) return h;
    for (final a in avaliacoes.reversed) {
      final p = a.v['altura'];
      if (p != null && p > 0) return p;
    }
    return null;
  }

  Metas? calcularMetas(
      {required String? sexo,
      required DateTime? nasc,
      required double? altura,
      required double? peso,
      required int ativ,
      required int obj,
      double? manual}) {
    if (sexo == null || nasc == null || altura == null || peso == null) {
      return null;
    }
    final h = DateTime.now();
    var idade = h.year - nasc.year;
    if (h.month < nasc.month || (h.month == nasc.month && h.day < nasc.day)) {
      idade--;
    }
    final tmb = 10 * peso + 6.25 * altura - 5 * idade + (sexo == 'm' ? 5 : -161);
    final gasto = tmb * kFatoresAtividade[ativ.clamp(0, 4)];
    var kcal = gasto * kAjusteObjetivo[obj.clamp(0, 2)];
    if (manual != null && manual > 0) kcal = manual;
    final sp = kDivisaoMacros[obj.clamp(0, 2)];
    return Metas(tmb, gasto, kcal, kcal * sp[0] / 4, kcal * sp[1] / 4,
        kcal * sp[2] / 9);
  }

  Metas? get metas => calcularMetas(
        sexo: perfil['sexo'] as String?,
        nasc: DateTime.tryParse('${perfil['nasc'] ?? ''}'),
        altura: alturaAtual,
        peso: pesoAtual,
        ativ: (perfil['ativ'] as num?)?.toInt() ?? 2,
        obj: (perfil['obj'] as num?)?.toInt() ?? 1,
        manual: (perfil['kcal_manual'] as num?)?.toDouble(),
      );

  /// Calorias gastas no dia pelos treinos/cardios registrados (estimativa).
  double kcalGastas(DateTime d) {
    var t = 0.0;
    for (final s in sessoesDoDia(d)) {
      t += s.kcal != null ? s.kcal!.toDouble() : s.seg / 60 * 6.5;
    }
    return t;
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

  Future<void> _salvarCustom() => _p.setString(_k('custom'),
      jsonEncode(lib.where((e) => e.custom).map((e) => e.toJson()).toList()));

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

  Future<void> _garantirInicio() async {
    if (inicioPlano == null) {
      final agora = DateTime.now();
      inicioPlano = DateTime(agora.year, agora.month, agora.day)
          .subtract(Duration(days: agora.weekday - 1));
      await _p.setString(_k('inicio_plano'), inicioPlano!.toIso8601String());
    }
  }

  Future<void> salvarPlano(List<Dia> dias) async {
    await _garantirInicio();
    plano = dias;
    await atualizarPlano();
  }

  /// Salva o plano atual depois de editar exercícios/dias (trocar, reordenar...).
  Future<void> atualizarPlano() async {
    plano.sort((a, b) => a.weekday.compareTo(b.weekday));
    var n = 0;
    for (final d in plano) {
      for (final it in d.itens) {
        if (it.exId.isEmpty) {
          final id = 'c_${DateTime.now().microsecondsSinceEpoch}_${n++}';
          lib.add(Exercicio(id: id, nome: it.nome, grupo: it.grupo, custom: true));
          it.exId = id;
        }
      }
    }
    await _salvarCustom();
    await _p.setString(
        _k('plano'), jsonEncode(plano.map((d) => d.toJson()).toList()));
    notifyListeners();
  }

  Future<void> adicionarDia(Dia d) async {
    plano.add(d);
    await atualizarPlano();
  }

  Future<void> removerDia(Dia d) async {
    plano.remove(d);
    await atualizarPlano();
  }

  /// Exclui um treino do histórico (ex.: treino de teste).
  Future<void> excluirSessao(Sessao s) async {
    sessoes.removeWhere((x) => x.data == s.data);
    await _p.setString(
        _k('sessoes'), jsonEncode(sessoes.map((e) => e.toJson()).toList()));
    // Se não sobrou nenhum treino completo do plano nesse dia, desmarca o dia.
    final dt = DateTime.tryParse(s.data);
    if (dt != null && s.completo && !s.livre) {
      final k = chaveData(dt);
      final aindaTem = sessoes.any((x) {
        final d = DateTime.tryParse(x.data);
        return d != null && x.completo && !x.livre && chaveData(d) == k;
      });
      if (!aindaTem) {
        feitos.remove(k);
        await _p.setStringList(_k('feitos'), feitos.toList());
      }
    }
    notifyListeners();
  }

  /// Treinos/cardios concluídos em um dia (inclui treino livre e cardio).
  List<Sessao> sessoesDoDia(DateTime d) {
    final k = chaveData(d);
    return sessoes.where((s) {
      final dt = DateTime.tryParse(s.data);
      return dt != null && s.completo && chaveData(dt) == k;
    }).toList();
  }

  bool fezAtividade(DateTime d) => sessoesDoDia(d).isNotEmpty;

  Future<void> concluirDia(DateTime d) async {
    feitos.add(chaveData(d));
    await _p.setStringList(_k('feitos'), feitos.toList());
    notifyListeners();
  }

  Future<void> setObs(String id, String v) async {
    if (v.trim().isEmpty) {
      obs.remove(id);
    } else {
      obs[id] = v;
    }
    await _p.setString(_k('obs'), jsonEncode(obs));
    _agendarEnvio();
  }

  Future<void> setDescanso(int s) async {
    descanso = s;
    await _p.setInt(_k('descanso'), s);
    notifyListeners();
  }

  Future<void> addSessao(Sessao s) async {
    sessoes.add(s);
    await _p.setString(
        _k('sessoes'), jsonEncode(sessoes.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> addAvaliacao(Map<String, double> v) async {
    avaliacoes.add(Avaliacao(data: DateTime.now().toIso8601String(), v: v));
    await _p.setString(_k('avaliacoes'),
        jsonEncode(avaliacoes.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> setMetaPeso(double v) async {
    metaPeso = v;
    await _p.setDouble(_k('meta_peso'), v);
    notifyListeners();
  }

  Future<void> setMetaAgua(int ml) async {
    metaAgua = ml;
    await _p.setInt(_k('meta_agua'), ml);
    notifyListeners();
  }

  Future<void> addAgua(DateTime d, int ml) async {
    final k = chaveData(d);
    final novo = (agua[k] ?? 0) + ml;
    agua[k] = novo < 0 ? 0 : novo;
    await _p.setString(_k('agua'), jsonEncode(agua));
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
        'perfil': perfil,
        'diario': diario,
        'cardapio': cardapio,
        'alimentos_proprios':
            alimentos.where((a) => a.custom).map((a) => a.toJson()).toList(),
        'alimentos_editados': alimOver,
        'exercicios_editados': exOver,
      });

  Future<void> setCarga(String id, String v) async {
    cargas[id] = v;
    await _p.setString(_k('cargas'), jsonEncode(cargas));
    _agendarEnvio();
  }
}

final app = AppState();
