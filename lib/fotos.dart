import 'state.dart';

class FotoDia {
  final String chave, rotulo, asset;
  final double ax, ay;
  const FotoDia(this.chave, this.rotulo, this.asset, this.ax, this.ay);
}

const fotosDisponiveis = <FotoDia>[
  FotoDia('peito', 'Peito', 'assets/fotos/peito.jpg', -0.05, -0.2),
  FotoDia('pernas', 'Pernas', 'assets/fotos/pernas.jpg', 0, -1),
  FotoDia('ombros', 'Ombros', 'assets/fotos/ombros.jpg', 0, -0.4),
  FotoDia('costas', 'Costas e bíceps', 'assets/fotos/costas.jpg', -0.1, -0.5),
  FotoDia('cardio', 'Cardio', 'assets/fotos/cardio.jpg', 0, -1),
];

FotoDia? fotoPorChave(String? k) {
  if (k == null) return null;
  for (final f in fotosDisponiveis) {
    if (f.chave == k) return f;
  }
  return null;
}

String _sa(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  var r = s.toLowerCase();
  for (var i = 0; i < de.length; i++) {
    r = r.replaceAll(de[i], para[i]);
  }
  return r;
}

String? _porGrupo(String t) {
  if (RegExp(r'peit').hasMatch(t)) return 'peito';
  if (RegExp(r'perna|quadr|posterior|panturr|gluteo|coxa|adutor|abdutor')
      .hasMatch(t)) {
    return 'pernas';
  }
  if (RegExp(r'ombro|deltoid').hasMatch(t)) return 'ombros';
  if (RegExp(r'costa|dorsal|bicep|tricep|braco').hasMatch(t)) return 'costas';
  if (RegExp(r'cardio|aerob').hasMatch(t)) return 'cardio';
  return null;
}

String? _porNome(String t) {
  if (RegExp(r'supino|crucifixo|peck|voador|flexao').hasMatch(t)) {
    return 'peito';
  }
  if (RegExp(r'agachamento|leg press|extensora|flexora|stiff|afundo|panturrilha|passada|hack|cadeira')
      .hasMatch(t)) {
    return 'pernas';
  }
  if (RegExp(r'elevacao lateral|elevacao frontal|desenvolvimento|ombro')
      .hasMatch(t)) {
    return 'ombros';
  }
  if (RegExp(r'puxada|remada|barra fixa|pulldown|serrote|rosca|triceps|frances')
      .hasMatch(t)) {
    return 'costas';
  }
  if (RegExp(r'esteira|bicicleta|corrida|eliptico').hasMatch(t)) return 'cardio';
  return null;
}

String? categoriaDoItem(Item it) {
  final g = _porGrupo(_sa(it.grupo));
  if (g != null) return g;
  return _porNome(_sa(app.ex(it.exId)?.nome ?? it.nome));
}

/// Escolhe a foto do dia pelo que o treino tem de verdade (ou pela escolha manual).
FotoDia? fotoDoDia(Dia d) {
  final manual = fotoPorChave(d.imagem);
  if (manual != null) return manual;
  final cont = <String, int>{};
  final ordem = <String>[];
  for (final it in d.itens) {
    final c = categoriaDoItem(it);
    if (c == null) continue;
    if (!cont.containsKey(c)) ordem.add(c);
    cont[c] = (cont[c] ?? 0) + 1;
  }
  if (ordem.isEmpty) return null;
  var melhor = ordem.first;
  for (final c in ordem) {
    if (cont[c]! > cont[melhor]!) melhor = c;
  }
  return fotoPorChave(melhor);
}
