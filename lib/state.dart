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
    lib = [
      ..._base,
      ..._lista(d['custom'])
          .map((e) => Exercicio.fromJson(Map<String, dynamic>.from(e as Map))),
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
      'meta_peso', 'sessoes', 'avaliacoes', 'agua', 'obs', 'cargas'
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
      lib = [..._base, ...lib.where((e) => e.custom)];
      for (final d in plano) {
        for (final it in d.itens) {
          if (it.exId.isNotEmpty && ex(it.exId) == null) {
            lib.add(Exercicio(
                id: it.exId, nome: it.nome, grupo: it.grupo, custom: true));
          }
        }
      }
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
      });

  Future<void> setCarga(String id, String v) async {
    cargas[id] = v;
    await _p.setString(_k('cargas'), jsonEncode(cargas));
    _agendarEnvio();
  }
}

final app = AppState();
