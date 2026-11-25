import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart' show Pedometer, StepCount;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_config.dart';
import 'nutri_modelo.dart';
import 'nivel.dart';

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
  String nome;
  int weekday;
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
  final List<Map<String, dynamic>>? detalhes; // exercícios e cargas do treino
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
    this.detalhes,
  });
  bool get cardio => tipo == 'cardio';

  /// Nome para exibir: o dia da semana em que o treino foi REALMENTE feito.
  /// ([dia] continua sendo o treino do plano, usado para ligar a sessão à rotina.)
  String get rotulo {
    if (cardio || livre || !_nomesDia.containsValue(dia)) return dia;
    final dt = DateTime.tryParse(data);
    if (dt == null) return dia;
    return _nomesDia[dt.weekday] ?? dia;
  }

  /// Se o treino do plano é de outro dia (ex.: treino de quarta feito na quinta).
  String? get treinoDeOutroDia => rotulo == dia ? null : dia;
  String get resumoCardio {
    final partes = <String>['${(seg / 60).round()} min'];
    if (km != null && km! > 0) {
      partes.add('${km!.toStringAsFixed(2).replaceAll('.', ',')} km');
    }
    if (km != null && km! >= 0.05 && seg > 0) {
      final r = (seg / km!).round();
      partes.add("${r ~/ 60}'${(r % 60).toString().padLeft(2, '0')}\" /km");
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
        detalhes: (j['detalhes'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
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
        'detalhes': detalhes,
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
/// Sugestão de carga para hoje. [subir] = tente mais; senão, mantenha.
class Sugestao {
  final double carga;
  final bool subir;
  const Sugestao(this.carga, this.subir);
}

// ---------- XP: valores e níveis ----------
const int kXpTreino = 100;
const int kXpCardio = 60;
const int kXpMissao = 150;
const int kXpPassos = 50;
const int kXpAgua = 20;
const int kXpPeso = 15;
const int kMissaoTreinos = 3;
const List<int> kXpCaixa = [100, 150, 200, 250, 300, 350, 500];

/// XP para sair do nível [n] e ir ao próximo: 160, 280, 400, 520...
int xpParaProximo(int n) => 160 + 120 * (n - 1);

/// Devolve [nível, XP dentro do nível, XP que o nível pede].
List<int> nivelDoXp(int total) {
  var n = 1;
  var r = total < 0 ? 0 : total;
  while (r >= xpParaProximo(n)) {
    r -= xpParaProximo(n);
    n++;
  }
  return [n, r, xpParaProximo(n)];
}

class XpAviso {
  final String texto;
  final String? extra;
  XpAviso(this.texto, this.extra);
}

class NumberFormatBr {
  static String milhar(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class AppState extends ChangeNotifier {
  List<Exercicio> lib = [];
  List<Exercicio> _base = [];
  List<Dia> plano = [];
  /// Ajustes por data (não fui treinar): 'R' = descanso, número = treino (weekday do plano) que caiu nesse dia.
  Map<String, String> ajustes = {};
  DateTime? inicioPlano;
  Set<String> feitos = {};
  Map<String, String> cargas = {};
  Map<String, String> obs = {};
  List<Sessao> sessoes = [];
  List<Map<String, dynamic>> sono = [];
  List<Avaliacao> avaliacoes = [];
  Map<String, int> agua = {};
  // XP / premiação: cada item é {id, ts, tipo, titulo, sub, xp}
  List<Map<String, dynamic>> xpLog = [];
  final ValueNotifier<XpAviso?> xpAviso = ValueNotifier<XpAviso?>(null);
  int _avisoXp = 0;
  final List<String> _avisoTitulos = [];
  int? _nivelAntesAviso;
  String? _passosXpDia;
  int metaAgua = 2500;
  double? metaPeso;
  int descanso = 75;
  int semanasPlano = 5; // duração do plano (editável em Meu plano)
  int _nivelSalvo = -1; // maior nível de treino já alcançado
  bool manterTela = true; // não desligar a tela com o app aberto
  Map<String, dynamic> anatomia = {}; // id do exercício -> músculos, execução, dicas
  bool aquecimento = false; // bloco de aquecimento no topo do treino
  late SharedPreferences _p;

  // Passos e academia
  Map<String, int> passos = {};
  int metaPassos = 10000;
  final ValueNotifier<int> passosHoje = ValueNotifier<int>(0);
  bool passosAtivo = false;
  String? erroPassos;
  StreamSubscription<StepCount>? _subPassos;
  Timer? _timerPassos;
  int? _ultimoTotal; // total do sensor já contabilizado
  bool _inicioAjustado = false;

  // Nutrição
  List<Alimento> _alimBase = [];
  List<Alimento> alimentos = [];
  List<Receita> receitas = [];
  Map<String, dynamic> alimOver = {};
  Map<String, dynamic> exOver = {};
  Map<String, dynamic> perfil = {};
  Map<String, dynamic> diario = {}; // dia -> refeição -> [entradas]
  Map<String, dynamic> cardapio = {}; // refeição -> [entradas]
  Map<String, dynamic> refeicoesConcluidas = {}; // dia -> [ids de refeições concluídas]

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
    anatomia = Map<String, dynamic>.from(jsonDecode(
        await rootBundle.loadString('assets/anatomia.json')) as Map);
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
    // Padrão ligado; uma vez, força ligado também para quem já tinha desligado.
    if (_p.getBool(_k('manter_tela_v2')) == null) {
      manterTela = true;
      await _p.setBool(_k('manter_tela'), true);
      await _p.setBool(_k('manter_tela_v2'), true);
    } else {
      manterTela = _p.getBool(_k('manter_tela')) ?? true;
    }
    aquecimento = _p.getBool(_k('aquecimento')) ?? false;
    if (_inicioAjustado && inicioPlano != null) {
      await _p.setString(_k('inicio_plano'), inicioPlano!.toIso8601String());
      _inicioAjustado = false;
    }
    unawaited(iniciarPassos());
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
        'sono': _p.getString(_k('sono')),
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
        'refeicoes_concluidas': _p.getString(_k('refeicoes_concluidas')),
        'passos': _p.getString(_k('passos')),
        'passos_meta': _p.getInt(_k('passos_meta')),
        'xp': _p.getString(_k('xp')),
        'ajustes': _p.getString(_k('ajustes')),
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
        'sono': jsonEncode(sono),
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
        'refeicoes_concluidas': jsonEncode(refeicoesConcluidas),
        'passos': jsonEncode(passos),
        'passos_meta': metaPassos,
        'xp': jsonEncode(xpLog),
        'ajustes': jsonEncode(ajustes),
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
    refeicoesConcluidas = Map<String, dynamic>.from(_mapa(d['refeicoes_concluidas']));
    passos = Map<String, int>.from(
        _mapa(d['passos']).map((k, v) => MapEntry('$k', (v as num).toInt())));
    metaPassos = (d['passos_meta'] as num?)?.toInt() ?? 10000;
    ajustes = {};
    final ajRaw = d['ajustes'];
    if (ajRaw is String && ajRaw.isNotEmpty) {
      try {
        (jsonDecode(ajRaw) as Map).forEach((k, v) => ajustes['$k'] = '$v');
      } catch (_) {}
    }
    xpLog = _lista(d['xp'])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    passosHoje.value = passos[chaveData(DateTime.now())] ?? 0;
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
    sono = _lista(d['sono']).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    _ajustarInicioVazio();
    if (inicioPlano == null && (plano.isNotEmpty || feitos.isNotEmpty)) {
      final datas = feitos.map(dataDaChave).whereType<DateTime>().toList();
      if (datas.isNotEmpty) datas.sort();
      final b = datas.isNotEmpty ? datas.first : DateTime.now();
      inicioPlano = DateTime(b.year, b.month, b.day)
          .subtract(Duration(days: b.weekday - 1));
    }
  }

  void _carregarLocal() {
    _aplicar(_lerLocal());
    semanasPlano = _p.getInt(_k('semanas_plano')) ?? 5;
    _nivelSalvo = _p.getInt(_k('nivel_treino')) ?? -1;
  }

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
    await _p.setString(_k('sono'), m['sono'] as String);
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
    await _p.setString(_k('refeicoes_concluidas'), m['refeicoes_concluidas'] as String);
    await _p.setString(_k('passos'), m['passos'] as String);
    await _p.setInt(_k('passos_meta'), metaPassos);
    await _p.setString(_k('xp'), m['xp'] as String);
    await _p.setString(_k('ajustes'), m['ajustes'] as String);
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
        // Mescla as sessões locais e da nuvem antes de aplicar os dados.
        // Assim, uma sessão salva no aparelho não some se ainda não chegou ao Firebase.
        final sessoesMescladas = <String, Map<String, dynamic>>{};
        for (final raw in [
          ..._lista(d['sessoes']),
          ...sessoes.map((s) => s.toJson()),
        ]) {
          final json = Map<String, dynamic>.from(raw as Map);
          final sessao = Sessao.fromJson(json);
          final normalizada = sessao.toJson();
          sessoesMescladas[jsonEncode(normalizada)] = normalizada;
        }
        d['sessoes'] = jsonEncode(sessoesMescladas.values.toList());

        _aplicar(d);
        await _salvarTudoLocal();
      } else {
        await _adotarLegado();
      }
      _aplicando = false;
      _nuvemPronta = true;
      // Persiste também a união no Firebase, não apenas no aparelho.
      if (snap.exists && d != null && d.isNotEmpty) {
        await _doc(u).set(_empacotar());
      } else {
        _enviar();
      }
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
      sono = ((m['sono'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
      if (m['ajustes'] is Map) {
        ajustes = {};
        (m['ajustes'] as Map).forEach((k, v) => ajustes['$k'] = '$v');
      }
      if (m['xp'] is List) {
        xpLog = (m['xp'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      if (m['perfil'] is Map) {
        perfil = Map<String, dynamic>.from(m['perfil'] as Map);
      }
      if (m['diario'] is Map) {
        diario = Map<String, dynamic>.from(m['diario'] as Map);
      }
      if (m['cardapio'] is Map) {
        cardapio = Map<String, dynamic>.from(m['cardapio'] as Map);
        refeicoesConcluidas = Map<String, dynamic>.from((m['refeicoes_concluidas'] as Map?) ?? {});
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

  bool refeicaoConcluida(String dia, String ref) {
    final l = refeicoesConcluidas[dia];
    return l is List && l.contains(ref);
  }

  Future<void> concluirRefeicao(String dia, String ref) async {
    if (refeicaoConcluida(dia, ref)) return;
    final entradas = entradasCardapio(ref);
    if (entradas.isEmpty) return;
    for (final e in entradas) {
      _listaDia(dia, ref).add(Map<String, dynamic>.from(e));
    }
    final l = (refeicoesConcluidas[dia] ??= <String>[]) as List;
    l.add(ref);
    await _salvarNutri();
  }

  Future<void> _salvarNutri() async {
    await _p.setString(_k('diario'), jsonEncode(diario));
    await _p.setString(_k('cardapio'), jsonEncode(cardapio));
    await _p.setString(_k('refeicoes_concluidas'), jsonEncode(refeicoesConcluidas));
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

  /// Preenche o cardápio inicial do usuário apenas na primeira vez.
  /// Se já houver qualquer refeição salva, preserva integralmente as escolhas existentes.
  Future<void> carregarCardapioPadrao() async {
    // Instalação nova: cria as cinco refeições completas.
    if (cardapio.isEmpty) {
      cardapio = {
      'cafe': [
        {'t': 'a', 'id': 'f_ovo_mexido', 'q': 110.0},
        {'t': 'a', 'id': 'f_pao_frances', 'q': 50.0},
        {'t': 'a', 'id': 'f_leite_integral', 'q': 200.0},
        {'t': 'a', 'id': 'f_banana_prata', 'q': 70.0},
      ],
      'almoco': [
        {'t': 'a', 'id': 'f_arroz_branco_cozido', 'q': 150.0},
        {'t': 'a', 'id': 'f_feijao_carioca_cozido', 'q': 100.0},
        {'t': 'a', 'id': 'f_peito_de_frango_grelhado', 'q': 160.0},
        {'t': 'a', 'id': 'f_cenoura_cozida', 'q': 100.0},
        {'t': 'a', 'id': 'f_azeite_de_oliva', 'q': 5.0},
      ],
      'cafe_tarde': [
        {'t': 'a', 'id': 'f_ovo_mexido', 'q': 110.0},
        {'t': 'a', 'id': 'f_pao_frances', 'q': 50.0},
        {'t': 'a', 'id': 'f_leite_integral', 'q': 200.0},
        {'t': 'a', 'id': 'f_maca_com_casca', 'q': 150.0},
      ],
      'lanche': [
        {'t': 'a', 'id': 'f_pao_frances', 'q': 40.0},
        {'t': 'a', 'id': 'f_leite_integral', 'q': 150.0},
        {'t': 'a', 'id': 'f_banana_prata', 'q': 70.0},
      ],
      'jantar': [
        {'t': 'a', 'id': 'f_arroz_branco_cozido', 'q': 100.0},
        {'t': 'a', 'id': 'f_feijao_carioca_cozido', 'q': 80.0},
        {'t': 'a', 'id': 'f_carne_moida_patinho_cozida', 'q': 120.0},
        {'t': 'a', 'id': 'f_cenoura_cozida', 'q': 100.0},
        {'t': 'a', 'id': 'f_azeite_de_oliva', 'q': 3.0},
      ],
        'outros': <dynamic>[],
      };
      await _salvarNutri();
      return;
    }

    // Atualização de versão: adiciona somente a nova refeição, sem apagar
    // ou mover alimentos que o usuário já cadastrou nas demais refeições.
    if (!cardapio.containsKey('cafe_tarde')) {
      cardapio['cafe_tarde'] = [
        {'t': 'a', 'id': 'f_ovo_mexido', 'q': 110.0},
        {'t': 'a', 'id': 'f_pao_frances', 'q': 50.0},
        {'t': 'a', 'id': 'f_leite_integral', 'q': 200.0},
        {'t': 'a', 'id': 'f_maca_com_casca', 'q': 150.0},
      ];
      cardapio['outros'] ??= <dynamic>[];
      await _salvarNutri();
    }
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

  /// Conta feminina: pelo sexo do perfil (ou pelo e-mail enquanto o perfil não existe).
  bool get fotosFemininas {
    final sx = perfil['sexo'];
    if (sx == 'f') return true;
    if (sx == 'm') return false;
    return (email ?? '').toLowerCase() == 'juliagalves102@gmail.com';
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

  /// Se nada foi feito ainda, a jornada começa na segunda-feira "de verdade":
  /// no domingo vale a segunda seguinte; de segunda a sábado, a segunda desta semana.
  void _ajustarInicioVazio() {
    if (inicioPlano == null ||
        feitos.isNotEmpty ||
        sessoes.isNotEmpty ||
        plano.isEmpty) {
      return;
    }
    final h = DateTime.now();
    final hoje = DateTime(h.year, h.month, h.day);
    final alvo = hoje.weekday == 7
        ? hoje.add(const Duration(days: 1))
        : hoje.subtract(Duration(days: hoje.weekday - 1));
    if (inicioPlano!.isBefore(alvo)) {
      inicioPlano = alvo;
      _inicioAjustado = true;
    }
  }

  Future<void> definirInicioPlano(DateTime d) async {
    final dia = DateTime(d.year, d.month, d.day);
    inicioPlano = dia.subtract(Duration(days: dia.weekday - 1));
    await _p.setString(_k('inicio_plano'), inicioPlano!.toIso8601String());
    notifyListeners();
  }

  // ---------- Passos (sensor do celular) ----------
  Future<void> iniciarPassos({bool pedir = false}) async {
    try {
      var st = await Permission.activityRecognition.status;
      if (!st.isGranted && pedir) {
        st = await Permission.activityRecognition.request();
      }
      if (!st.isGranted) {
        passosAtivo = false;
        notifyListeners();
        return;
      }
      await _subPassos?.cancel();
      _subPassos = Pedometer.stepCountStream.listen(
        _aoPasso,
        onError: (Object e) {
          erroPassos = 'Sensor de passos indisponível neste celular.';
          passosAtivo = false;
          notifyListeners();
        },
        cancelOnError: false,
      );
      passosAtivo = true;
      erroPassos = null;
      notifyListeners();
    } catch (e) {
      erroPassos = '$e';
      passosAtivo = false;
      notifyListeners();
    }
  }

  void _aoPasso(StepCount e) {
    final total = e.steps;
    _ultimoTotal ??= _p.getInt('passos_last');
    final k = chaveData(DateTime.now());
    var delta = 0;
    if (_ultimoTotal != null) {
      delta = total >= _ultimoTotal! ? total - _ultimoTotal! : total;
    }
    _ultimoTotal = total;
    if (delta > 0) passos[k] = (passos[k] ?? 0) + delta;
    passosHoje.value = passos[k] ?? 0;
    if (metaPassos > 0 && (passos[k] ?? 0) >= metaPassos && _passosXpDia != k) {
      _passosXpDia = k;
      unawaited(_xpPassos(k));
    }
    _timerPassos?.cancel();
    _timerPassos = Timer(const Duration(seconds: 30), _salvarPassos);
  }

  Future<void> _salvarPassos() async {
    if (_ultimoTotal != null) await _p.setInt('passos_last', _ultimoTotal!);
    await _p.setString(_k('passos'), jsonEncode(passos));
    _agendarEnvio();
  }

  Future<void> setMetaPassos(int v) async {
    metaPassos = v;
    await _p.setInt(_k('passos_meta'), v);
    notifyListeners();
  }

  Map<String, dynamic>? get academia {
    final a = perfil['academia'];
    return a is Map ? Map<String, dynamic>.from(a) : null;
  }

  Future<void> salvarAcademia(Map<String, dynamic>? a) async {
    final p = Map<String, dynamic>.from(perfil);
    if (a == null) {
      p.remove('academia');
    } else {
      p['academia'] = a;
    }
    await salvarPerfil(p);
  }

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

  Future<void> _salvarAjustes() async {
    final lim = DateTime.now().subtract(const Duration(days: 45));
    ajustes.removeWhere((k, _) {
      final d = dataDaChave(k);
      return d != null && d.isBefore(lim);
    });
    await _p.setString(_k('ajustes'), jsonEncode(ajustes));
  }

  /// "Não fui treinar": o dia vira descanso e o treino dele vai para o dia
  /// seguinte. Se o dia seguinte já tinha treino, esse também avança, e assim
  /// por diante, até cair num dia livre. Devolve o estado anterior (para desfazer).
  Future<Map<String, String>> naoFuiTreinar(DateTime d) async {
    final antes = Map<String, String>.from(ajustes);
    final base = DateTime(d.year, d.month, d.day);
    var carga = treinoNo(base);
    if (carga == null) return antes;
    final novos = <String, String>{chaveData(base): 'R'};
    for (var i = 1; i <= 14; i++) {
      final dia = DateTime(base.year, base.month, base.day + i);
      final ocupante = treinoNo(dia);
      novos[chaveData(dia)] = '${carga!.weekday}';
      if (ocupante == null) break;
      carga = ocupante;
    }
    ajustes.addAll(novos);
    await _salvarAjustes();
    notifyListeners();
    return antes;
  }

  Future<void> restaurarAjustes(Map<String, String> antes) async {
    ajustes = Map<String, String>.from(antes);
    await _salvarAjustes();
    notifyListeners();
  }

  /// Volta ao plano normal a partir de [d] (inclusive).
  Future<void> desfazerAjustesDesde(DateTime d) async {
    final base = DateTime(d.year, d.month, d.day);
    ajustes.removeWhere((k, _) {
      final x = dataDaChave(k);
      return x != null && !x.isBefore(base);
    });
    await _salvarAjustes();
    notifyListeners();
  }

  /// O treino [dia] é o treino de hoje (já considerando os ajustes)?
  bool eTreinoDeHoje(Dia dia) =>
      treinoNo(DateTime.now())?.weekday == dia.weekday;

  /// Treino exatamente do dia da semana de [d] (null = dia de descanso).
  Dia? treinoNo(DateTime d) {
    final aj = ajustes[chaveData(d)];
    if (aj != null) {
      if (aj == 'R') return null;
      final w = int.tryParse(aj);
      for (final x in plano) {
        if (x.weekday == w) return x;
      }
      return null;
    }
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
    ajustes.clear();
    await _salvarAjustes();
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
    if (dt != null) await _xpRevisarDia(dt);
    notifyListeners();
  }

  /// Atualiza ou remove um exercício de uma sessão histórica e recalcula
  /// os indicadores derivados para que histórico, volume e sugestões usem os dados corrigidos.
  Future<void> editarExercicioSessao(
      Sessao original, int indice, Map<String, dynamic>? novo) async {
    var pos = sessoes.indexWhere((x) => identical(x, original));
    if (pos < 0) {
      pos = sessoes.indexWhere((x) =>
          x.data == original.data && x.dia == original.dia &&
          x.seg == original.seg && x.tipo == original.tipo &&
          x.livre == original.livre);
    }
    if (pos < 0) return;
    final atual = sessoes[pos];
    final det = (atual.detalhes ?? const <Map<String, dynamic>>[])
        .map((e) => Map<String, dynamic>.from(e)).toList();
    if (indice < 0 || indice >= det.length) return;
    if (novo == null) {
      det.removeAt(indice);
    } else {
      det[indice] = Map<String, dynamic>.from(novo);
    }
    var volume = 0.0;
    var series = 0;
    for (final e in det) {
      final cs = (e['cargas'] as List? ?? const [])
          .map((v) => (v as num).toDouble()).toList();
      final reps = repsMedio('${e['reps'] ?? ''}');
      volume += cs.fold<double>(0, (a, b) => a + b * reps);
      series += cs.length;
    }
    final substituta = Sessao(
      data: atual.data, dia: atual.dia, seg: atual.seg,
      series: series, seriesTotal: atual.seriesTotal,
      volume: volume, completo: atual.completo, livre: atual.livre,
      tipo: atual.tipo, modalidade: atual.modalidade, km: atual.km,
      kcal: atual.kcal, fc: atual.fc, detalhes: det,
    );
    sessoes[pos] = substituta;

    // Atualiza a carga de referência usada no plano/Coach IA apenas ao editar.
    // A exclusão do histórico não deve apagar nem alterar cargas de outros treinos.
    if (novo != null) {
      final nome = '${novo['nome'] ?? ''}';
      final achado = melhor(nome, lib);
      final cs = (novo['cargas'] as List? ?? const [])
          .map((v) => (v as num).toDouble()).toList();
      if (achado.ex != null && achado.score >= .6 && cs.isNotEmpty) {
        cargas[achado.ex!.id] = cs.last.toString();
        await _p.setString(_k('cargas'), jsonEncode(cargas));
      }
    }
    await _p.setString(
        _k('sessoes'), jsonEncode(sessoes.map((e) => e.toJson()).toList()));
    // notifyListeners agenda a sincronização com o Firestore e atualiza
    // histórico, comparativos, gráficos e sugestões derivados das sessões.
    notifyListeners();
  }

  /// Corrige a duração de uma sessão já registrada no histórico.
  Future<void> editarDuracaoSessao(Sessao original, int segundos) async {
    if (segundos < 0) return;
    var pos = sessoes.indexWhere((x) => identical(x, original));
    if (pos < 0) {
      pos = sessoes.indexWhere((x) =>
          x.data == original.data && x.dia == original.dia &&
          x.tipo == original.tipo && x.livre == original.livre);
    }
    if (pos < 0) return;
    final a = sessoes[pos];
    sessoes[pos] = Sessao(
      data: a.data, dia: a.dia, seg: segundos,
      series: a.series, seriesTotal: a.seriesTotal, volume: a.volume,
      completo: a.completo, livre: a.livre, tipo: a.tipo,
      modalidade: a.modalidade, km: a.km, kcal: a.kcal, fc: a.fc,
      detalhes: a.detalhes,
    );
    await _p.setString(
        _k('sessoes'), jsonEncode(sessoes.map((e) => e.toJson()).toList()));
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

  /// Último treino completo feito desse dia do plano (para mostrar o tempo real).
  Sessao? ultimaSessaoDoDia(Dia d) {
    Sessao? r;
    for (final s in sessoes) {
      if (!s.completo || s.livre || s.cardio || s.dia != d.nome) continue;
      if (r == null || s.data.compareTo(r.data) > 0) r = s;
    }
    return r;
  }

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

  Future<void> salvarSono(Map<String, dynamic> r) async { final k = r['data'] as String; sono.removeWhere((e) => e['data'] == k); sono.add(Map<String,dynamic>.from(r)); await _p.setString(_k('sono'), jsonEncode(sono)); notifyListeners(); }
  Future<void> excluirSono(String k) async { sono.removeWhere((e) => e['data'] == k); await _p.setString(_k('sono'), jsonEncode(sono)); notifyListeners(); }

  Future<void> addSessao(Sessao s) async {
    final nivelAntes = nivelTreino.index;
    sessoes.add(s);

    // Primeiro garante o histórico no aparelho.
    await _p.setString(
        _k('sessoes'), jsonEncode(sessoes.map((e) => e.toJson()).toList()));
    if (s.completo) await _xpDaSessao(s);
    await _verificarNivelTreino(nivelAntes);

    // Ao concluir um treino, tenta confirmar o backup no Firebase antes
    // de encerrar o fluxo. Se estiver sem internet, mantém no aparelho e
    // agenda a sincronização para quando a conexão voltar.
    final u = uid;
    if (u != null && nuvemOk && _nuvemPronta && !_aplicando) {
      try {
        await _doc(u).set(_empacotar()).timeout(const Duration(seconds: 15));
        ultimaSync = DateTime.now();
        erroNuvem = null;
      } catch (e) {
        erroNuvem = '$e';
        _agendarEnvio();
      }
    } else {
      _agendarEnvio();
    }
    notifyListeners();
  }

  /// Nível de treino atual (só sobe, nunca desce por excluir um treino).
  ProgressoNivel get progressoNivel => calcularNivel(sessoes);
  NivelTreino get nivelTreino {
    final i = progressoNivel.nivel.index;
    return NivelTreino.values[i > _nivelSalvo ? i : _nivelSalvo];
  }

  Future<void> _verificarNivelTreino(int antes) async {
    final agora = progressoNivel.nivel.index;
    if (agora > _nivelSalvo) {
      _nivelSalvo = agora;
      await _p.setInt(_k('nivel_treino'), agora);
    }
    if (agora > antes) {
      final n = NivelTreino.values[agora];
      Future.delayed(const Duration(milliseconds: 3500), () {
        xpAviso.value = XpAviso('Você subiu para ${n.nome}! 💪',
            'Suas cargas estão evoluindo. O app atualizou seu nível.');
      });
    }
  }

  Future<void> setSemanasPlano(int n) async {
    semanasPlano = n.clamp(1, 52).toInt();
    await _p.setInt(_k('semanas_plano'), semanasPlano);
    notifyListeners();
  }

  Future<void> addAvaliacao(Map<String, double> v) async {
    avaliacoes.add(Avaliacao(data: DateTime.now().toIso8601String(), v: v));
    await _p.setString(_k('avaliacoes'),
        jsonEncode(avaliacoes.map((e) => e.toJson()).toList()));
    if (v['peso'] != null) {
      _xpAdd('peso:${chaveData(DateTime.now())}', 'peso', 'Peso atualizado',
          kXpPeso);
      await _xpFechar();
    }
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
    if (ml > 0 && k == chaveData(DateTime.now())) {
      _xpAdd('agua:$k', 'agua', 'Hidratação registrada', kXpAgua);
      await _xpFechar();
    }
    notifyListeners();
  }

  // ---------- XP e premiação ----------
  int get xpTotal =>
      xpLog.fold<int>(0, (t, e) => t + ((e['xp'] as num?)?.toInt() ?? 0));

  Future<void> _salvarXp() async {
    await _p.setString(_k('xp'), jsonEncode(xpLog));
  }

  /// Soma XP uma única vez por [id]. Devolve true se ganhou agora.
  bool _xpAdd(String id, String tipo, String titulo, int xp,
      {String sub = ''}) {
    if (xpLog.any((e) => e['id'] == id)) return false;
    _nivelAntesAviso ??= nivelDoXp(xpTotal)[0];
    xpLog.add({
      'id': id,
      'ts': DateTime.now().toIso8601String(),
      'tipo': tipo,
      'titulo': titulo,
      'sub': sub,
      'xp': xp,
    });
    _avisoXp += xp;
    _avisoTitulos.add(titulo);
    return true;
  }

  /// Grava o XP novo e avisa na tela (uma mensagem só por lote).
  Future<void> _xpFechar({bool avisar = true}) async {
    await _salvarXp();
    final antes = _nivelAntesAviso;
    final xp = _avisoXp;
    final titulos = List<String>.from(_avisoTitulos);
    _avisoXp = 0;
    _avisoTitulos.clear();
    _nivelAntesAviso = null;
    if (!avisar || xp <= 0) return;
    final depois = nivelDoXp(xpTotal)[0];
    final subiu = antes != null && depois > antes;
    xpAviso.value = XpAviso(
      '+$xp XP · ${titulos.join(', ')}',
      subiu ? 'Você subiu para o Nível $depois!' : null,
    );
  }

  Future<void> _xpDaSessao(Sessao s) async {
    final dt = DateTime.tryParse(s.data) ?? DateTime.now();
    final k = chaveData(dt);
    if (s.cardio) {
      _xpAdd('cardio:$k', 'cardio', 'Cardio concluído', kXpCardio,
          sub: s.modalidade ?? '');
    } else {
      _xpAdd('treino:$k', 'treino', 'Treino concluído', kXpTreino,
          sub: s.livre ? 'Treino livre' : s.dia);
      _xpMissao(dt);
    }
    await _xpFechar();
  }

  /// Dias diferentes da semana (domingo a sábado) com treino de musculação concluído.
  int treinosNaSemana([DateTime? ref]) {
    final r = ref ?? DateTime.now();
    final dom = DateTime(r.year, r.month, r.day - (r.weekday % 7));
    final dias = <String>{};
    for (final s in sessoes) {
      if (!s.completo || s.cardio) continue;
      final d = DateTime.tryParse(s.data);
      if (d == null) continue;
      final dd = DateTime(d.year, d.month, d.day);
      if (!dd.isBefore(dom) && dd.isBefore(DateTime(dom.year, dom.month, dom.day + 7))) {
        dias.add(chaveData(dd));
      }
    }
    return dias.length;
  }

  bool get missaoSemanalFeita {
    final n = DateTime.now();
    final dom = DateTime(n.year, n.month, n.day - (n.weekday % 7));
    return xpLog.any((e) => e['id'] == 'missao:${chaveData(dom)}');
  }

  void _xpMissao(DateTime dt) {
    if (treinosNaSemana(dt) < kMissaoTreinos) return;
    final dom = DateTime(dt.year, dt.month, dt.day - (dt.weekday % 7));
    _xpAdd('missao:${chaveData(dom)}', 'missao', 'Missão semanal concluída',
        kXpMissao,
        sub: 'Treine ${kMissaoTreinos}x esta semana');
  }

  /// Depois de excluir um treino: tira o XP do dia se não sobrou nenhum.
  Future<void> _xpRevisarDia(DateTime dt) async {
    final k = chaveData(dt);
    bool tem(bool cardio) => sessoes.any((x) {
          final d = DateTime.tryParse(x.data);
          return d != null &&
              x.completo &&
              x.cardio == cardio &&
              chaveData(d) == k;
        });
    final antes = xpLog.length;
    if (!tem(false)) xpLog.removeWhere((e) => e['id'] == 'treino:$k');
    if (!tem(true)) xpLog.removeWhere((e) => e['id'] == 'cardio:$k');
    if (xpLog.length != antes) await _salvarXp();
  }

  Future<void> _xpPassos(String k) async {
    final n = NumberFormatBr.milhar(metaPassos);
    if (_xpAdd('passos:$k', 'passos', 'Meta de passos batida', kXpPassos,
        sub: '$n passos')) {
      await _xpFechar();
      notifyListeners();
    }
  }

  // Caixa do dia: uma por dia; o prêmio cresce com a sequência de dias seguidos.
  bool get caixaDisponivel =>
      !xpLog.any((e) => e['id'] == 'caixa:${chaveData(DateTime.now())}');

  int get _seqCaixa {
    final dias = xpLog
        .where((e) => e['tipo'] == 'caixa')
        .map((e) => '${e['id']}'.substring(6))
        .toSet();
    final n = DateTime.now();
    var d = DateTime(n.year, n.month, n.day);
    if (!dias.contains(chaveData(d))) d = DateTime(d.year, d.month, d.day - 1);
    var c = 0;
    while (dias.contains(chaveData(d))) {
      c++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return c;
  }

  /// Número do dia da sequência da caixa de hoje (1, 2, 3...).
  int get diaDaCaixa => caixaDisponivel ? _seqCaixa + 1 : _seqCaixa;

  int premioDaCaixa(int dia) => kXpCaixa[(dia - 1) % kXpCaixa.length];

  /// Abre a caixa de hoje. Devolve o XP ganho (0 se já foi aberta).
  Future<int> abrirCaixa() async {
    if (!caixaDisponivel) return 0;
    final dia = diaDaCaixa;
    final xp = premioDaCaixa(dia);
    _xpAdd('caixa:${chaveData(DateTime.now())}', 'caixa', 'Recompensa diária',
        xp,
        sub: 'Dia $dia · caixa do dia');
    await _xpFechar(avisar: false);
    notifyListeners();
    return xp;
  }

  String exportar() => JsonEncoder.withIndent('  ').convert({
        'exportado_em': DateTime.now().toIso8601String(),
        'conta': {'nome': nome, 'email': email},
        'plano': plano.map((d) => d.toJson()).toList(),
        'sessoes': sessoes.map((e) => e.toJson()).toList(),
        'sono': sono,
        'avaliacoes': avaliacoes.map((e) => e.toJson()).toList(),
        'agua_ml_por_dia': agua,
        'meta_agua_ml': metaAgua,
        'meta_peso': metaPeso,
        'descanso_s': descanso,
        'cargas': cargas,
        'observacoes': obs,
        'dias_concluidos': feitos.toList(),
        'xp': xpLog,
        'ajustes': ajustes,
        'perfil': perfil,
        'diario': diario,
        'cardapio': cardapio,
        'refeicoes_concluidas': refeicoesConcluidas,
        'refeicoes_concluidas': refeicoesConcluidas,
        'alimentos_proprios':
            alimentos.where((a) => a.custom).map((a) => a.toJson()).toList(),
        'alimentos_editados': alimOver,
        'exercicios_editados': exOver,
      });

  // ---------- Treino em andamento (retomar se o app for fechado) ----------
  String? lerRunSalvo() => _p.getString(_k('run_salvo'));
  Future<void> gravarRunSalvo(String? json) async {
    if (json == null) {
      await _p.remove(_k('run_salvo'));
    } else {
      await _p.setString(_k('run_salvo'), json);
    }
  }

  // ---------- Telas e aquecimento ----------
  Future<void> setManterTela(bool v) async {
    manterTela = v;
    await _p.setBool(_k('manter_tela'), v);
    await aplicarManterTela();
    notifyListeners();
  }

  /// Envia a preferência ao Android (FLAG_KEEP_SCREEN_ON, ver MainActivity.kt).
  Future<void> aplicarManterTela() async {
    try {
      await const MethodChannel('meutreino/tela')
          .invokeMethod('manterTela', manterTela);
    } catch (_) {
      // Sem canal nativo (ex.: teste): segue sem travar a tela.
    }
  }

  Future<void> setAquecimento(bool v) async {
    aquecimento = v;
    await _p.setBool(_k('aquecimento'), v);
    notifyListeners();
  }

  // ---------- Histórico por exercício (pelo nome) ----------
  List<double> _cargasDe(Map<String, dynamic> m) =>
      ((m['cargas'] as List?) ?? const [])
          .map((e) => (e as num).toDouble())
          .toList();

  /// Cargas (uma por série) da última vez que este exercício foi feito.
  List<double>? ultimasCargas(String nome) {
    Map<String, dynamic>? achado;
    DateTime? quando;
    for (final s in sessoes) {
      final dt = DateTime.tryParse(s.data);
      if (dt == null || s.detalhes == null) continue;
      for (final m in s.detalhes!) {
        if (m['nome'] == nome && (quando == null || dt.isAfter(quando))) {
          achado = m;
          quando = dt;
        }
      }
    }
    return achado == null ? null : _cargasDe(achado);
  }

  /// Maior carga já registrada para este exercício (null = nunca usou carga).
  double? recorde(String nome) {
    double? r;
    for (final s in sessoes) {
      for (final m in s.detalhes ?? const <Map<String, dynamic>>[]) {
        if (m['nome'] != nome) continue;
        for (final c in _cargasDe(m)) {
          if (c > 0 && (r == null || c > r)) r = c;
        }
      }
    }
    return r;
  }

  /// Registro mais recente deste exercício (cargas e RPE).
  Map<String, dynamic>? _ultimoRegistro(String nome) {
    Map<String, dynamic>? achado;
    DateTime? quando;
    for (final s in sessoes) {
      final dt = DateTime.tryParse(s.data);
      if (dt == null || s.detalhes == null) continue;
      for (final m in s.detalhes!) {
        if (m['nome'] == nome && (quando == null || dt.isAfter(quando))) {
          achado = m;
          quando = dt;
        }
      }
    }
    return achado;
  }

  /// Sugestão para hoje pelo RPE da última vez: Fácil sobe; Ok/Pesado mantém.
  /// Sem RPE: sobe se todas as séries saíram com a mesma carga.
  Sugestao? sugestaoCarga(String nome, int series) {
    final m = _ultimoRegistro(nome);
    if (m == null) return null;
    final u = _cargasDe(m);
    if (u.isEmpty || u.first <= 0) return null;
    final passo = u.last >= 20 ? 2.5 : 1.0;
    final rpe = (m['rpe'] ?? '') as String;
    if (rpe == 'Fácil') return Sugestao(u.last + passo, true);
    if (rpe == 'Ok' || rpe == 'Pesado') return Sugestao(u.last, false);
    if (u.length < series || !u.every((c) => c == u.first)) return null;
    return Sugestao(u.first + passo, true);
  }

  // ---------- Exercícios do treino em andamento (sessão ainda não salva) ----------
  final Set<String> _runFeitos = {};
  final Set<String> _runExcl = {};
  String _kRun(String nome, String diaNome) =>
      '${chaveData(DateTime.now())}|$diaNome|$nome';
  String _pRun(String diaNome) => '${chaveData(DateTime.now())}|$diaNome|';

  /// Marca o exercício como finalizado no treino em andamento (fica travado).
  void marcarRunFeito(String nome, String diaNome) {
    if (_runFeitos.add(_kRun(nome, diaNome))) notifyListeners();
  }

  /// Marca o exercício como excluído só de hoje.
  void marcarRunExcluido(String nome, String diaNome) {
    if (_runExcl.add(_kRun(nome, diaNome))) notifyListeners();
  }

  /// Reconstrói a lista ao retomar um treino salvo (sem avisar a tela).
  void definirRun(String diaNome, Iterable<String> feitos, Iterable<String> excl) {
    final p = _pRun(diaNome);
    _runFeitos.removeWhere((k) => k.startsWith(p));
    _runExcl.removeWhere((k) => k.startsWith(p));
    for (final n in feitos) {
      _runFeitos.add('$p$n');
    }
    for (final n in excl) {
      _runExcl.add('$p$n');
    }
  }

  /// Treino de hoje terminou ou foi abandonado: libera a lista temporária.
  void limparRun(String diaNome) {
    final p = _pRun(diaNome);
    final a = _runFeitos.length + _runExcl.length;
    _runFeitos.removeWhere((k) => k.startsWith(p));
    _runExcl.removeWhere((k) => k.startsWith(p));
    if (_runFeitos.length + _runExcl.length != a) notifyListeners();
  }

  bool excluidoHojeEx(String nome, String diaNome) =>
      _runExcl.contains(_kRun(nome, diaNome));

  /// Já feito ou excluído hoje: não entra mais na fila do treino.
  bool resolvidoHojeEx(String nome, String diaNome) =>
      feitoHojeEx(nome, diaNome) || excluidoHojeEx(nome, diaNome);

  /// Exercício já registrado hoje neste dia do plano (inclui o treino em andamento).
  bool feitoHojeEx(String nome, String diaNome) {
    if (_runFeitos.contains(_kRun(nome, diaNome))) return true;
    final k = chaveData(DateTime.now());
    for (final s in sessoes) {
      final dt = DateTime.tryParse(s.data);
      if (dt == null || s.dia != diaNome || chaveData(dt) != k) continue;
      for (final m in s.detalhes ?? const <Map<String, dynamic>>[]) {
        if (m['nome'] == nome) return true;
      }
    }
    return false;
  }

  Future<void> setCarga(String id, String v) async {
    cargas[id] = v;
    await _p.setString(_k('cargas'), jsonEncode(cargas));
    _agendarEnvio();
  }
}

final app = AppState();
