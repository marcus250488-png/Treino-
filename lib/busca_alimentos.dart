import 'dart:convert';
import 'package:http/http.dart' as http;

/// Resultado da busca online (Open Food Facts). Valores por 100 g.
class ResultadoOnline {
  final String nome, marca;
  final double kcal, p, c, g;
  final double? porcaoG;
  const ResultadoOnline({
    required this.nome,
    required this.marca,
    required this.kcal,
    required this.p,
    required this.c,
    required this.g,
    this.porcaoG,
  });
}

double? _n(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(',', '.'));
}

Future<List<ResultadoOnline>> _consultar(String host, String q) async {
  final uri = Uri.https(host, '/cgi/search.pl', {
    'search_terms': q,
    'search_simple': '1',
    'action': 'process',
    'json': '1',
    'page_size': '20',
    'lc': 'pt',
    'fields': 'product_name,brands,nutriments,serving_quantity',
  });
  final r = await http.get(uri, headers: {
    'User-Agent': 'MeuTreino/1.0 (app pessoal de treino)',
  }).timeout(const Duration(seconds: 10));
  if (r.statusCode != 200) throw Exception('Erro ${r.statusCode}');
  final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  final out = <ResultadoOnline>[];
  for (final e in (j['products'] as List? ?? const [])) {
    final m = e as Map;
    final nome = ('${m['product_name'] ?? ''}').trim();
    final n = m['nutriments'];
    if (nome.isEmpty || n is! Map) continue;
    final kcal = _n(n['energy-kcal_100g']) ??
        (_n(n['energy_100g']) != null ? _n(n['energy_100g'])! / 4.184 : null);
    if (kcal == null) continue;
    final marca = ('${m['brands'] ?? ''}').split(',').first.trim();
    final porcao = _n(m['serving_quantity']);
    out.add(ResultadoOnline(
      nome: nome,
      marca: marca,
      kcal: kcal,
      p: _n(n['proteins_100g']) ?? 0,
      c: _n(n['carbohydrates_100g']) ?? 0,
      g: _n(n['fat_100g']) ?? 0,
      porcaoG: (porcao != null && porcao > 0) ? porcao : null,
    ));
    if (out.length >= 10) break;
  }
  return out;
}

/// Busca alimentos na internet (Open Food Facts). Tenta o Brasil primeiro.
Future<List<ResultadoOnline>> buscarAlimentosOnline(String q) async {
  final br = await _consultar('br.openfoodfacts.org', q);
  if (br.isNotEmpty) return br;
  return _consultar('world.openfoodfacts.org', q);
}
