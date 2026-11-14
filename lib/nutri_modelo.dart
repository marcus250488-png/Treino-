import 'package:flutter/material.dart';

String fmtD(double v, [int dec = 0]) {
  if (dec == 0) return v.round().toString();
  final s = v.toStringAsFixed(dec);
  final t = s.contains('.') ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : s;
  return t.replaceAll('.', ',');
}

class Macros {
  final double kcal, p, c, g;
  const Macros([this.kcal = 0, this.p = 0, this.c = 0, this.g = 0]);
  Macros operator +(Macros o) =>
      Macros(kcal + o.kcal, p + o.p, c + o.c, g + o.g);
  Macros operator *(double f) => Macros(kcal * f, p * f, c * f, g * f);
}

class Alimento {
  final String id, nome, un;
  final double kcal, p, c, g, ug; // valores por 100 g (ou 100 ml)
  final bool custom;
  const Alimento({
    required this.id,
    required this.nome,
    required this.kcal,
    required this.p,
    required this.c,
    required this.g,
    this.un = '',
    this.ug = 0,
    this.custom = false,
  });
  factory Alimento.fromJson(Map<String, dynamic> j) => Alimento(
        id: j['id'] as String,
        nome: j['nome'] as String,
        kcal: (j['kcal'] as num).toDouble(),
        p: (j['p'] as num).toDouble(),
        c: (j['c'] as num).toDouble(),
        g: (j['g'] as num).toDouble(),
        un: (j['un'] ?? '') as String,
        ug: ((j['ug'] ?? 0) as num).toDouble(),
        custom: (j['custom'] ?? false) as bool,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'kcal': kcal,
        'p': p,
        'c': c,
        'g': g,
        'un': un,
        'ug': ug,
        'custom': custom,
      };
  Macros porGramas(double gr) =>
      Macros(kcal * gr / 100, p * gr / 100, c * gr / 100, g * gr / 100);
}

class Ingrediente {
  final String id;
  final double g;
  const Ingrediente(this.id, this.g);
}

class Receita {
  final String id, nome, cat, modo;
  final int min;
  final List<Ingrediente> ing;
  const Receita({
    required this.id,
    required this.nome,
    required this.cat,
    required this.modo,
    required this.min,
    required this.ing,
  });
  factory Receita.fromJson(Map<String, dynamic> j) => Receita(
        id: j['id'] as String,
        nome: j['nome'] as String,
        cat: (j['cat'] ?? '') as String,
        modo: (j['modo'] ?? '') as String,
        min: ((j['min'] ?? 0) as num).toInt(),
        ing: (j['ing'] as List)
            .map((e) => Ingrediente(
                (e as List)[0] as String, (e[1] as num).toDouble()))
            .toList(),
      );
}

class Metas {
  final double tmb, gasto, kcal, p, c, g;
  const Metas(this.tmb, this.gasto, this.kcal, this.p, this.c, this.g);
}

class Refeicao {
  final String id, nome, img;
  final double pct;
  final Color cor;
  const Refeicao(this.id, this.nome, this.pct, this.cor, this.img);
}

const kRefeicoes = <Refeicao>[
  Refeicao('cafe', 'Café da manhã', 0.20, Color(0xFF4FFBA5), 'assets/nutri/cafe.jpg'),
  Refeicao('almoco', 'Almoço', 0.35, Color(0xFFFA9D50), 'assets/nutri/almoco.jpg'),
  Refeicao('lanche', 'Lanche da tarde', 0.15, Color(0xFFFB507C), 'assets/nutri/lanche.jpg'),
  Refeicao('jantar', 'Jantar', 0.30, Color(0xFFFAD24F), 'assets/nutri/jantar.jpg'),
  Refeicao('outros', 'Outros', 0.0, Color(0xFFB3B3B3), 'assets/nutri/outros.jpg'),
];

const kFatoresAtividade = <double>[1.2, 1.375, 1.55, 1.725, 1.9];
const kAjusteObjetivo = <double>[0.80, 1.0, 1.10];
// proteína, carboidrato, gordura (fração das calorias)
const kDivisaoMacros = <List<double>>[
  [0.35, 0.35, 0.30],
  [0.30, 0.40, 0.30],
  [0.25, 0.50, 0.25],
];
