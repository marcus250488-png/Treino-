import 'state.dart';

/// Nível de treino (iniciante / intermediário / avançado), calculado pela
/// progressão de carga registrada nos treinos.
enum NivelTreino { iniciante, intermediario, avancado }

extension NivelTreinoNome on NivelTreino {
  String get nome => switch (this) {
        NivelTreino.iniciante => 'Iniciante',
        NivelTreino.intermediario => 'Intermediário',
        NivelTreino.avancado => 'Avançado',
      };
}

/// Requisitos para ENTRAR em cada nível (ajuste aqui se quiser mais fácil/difícil).
class _Req {
  final int aumentos, exercicios, semanas;
  const _Req(this.aumentos, this.exercicios, this.semanas);
}

const _reqIntermediario = _Req(20, 8, 4);
const _reqAvancado = _Req(70, 15, 12);

class ProgressoNivel {
  final NivelTreino nivel;

  /// Quantas vezes uma carga passou do maior valor já usado naquele exercício.
  final int aumentos;

  /// Exercícios diferentes que já tiveram aumento de carga.
  final int exercicios;

  /// Semanas diferentes com treino de musculação.
  final int semanas;

  /// 0..1 rumo ao próximo nível (1 quando já é Avançado).
  final double progresso;

  /// Próximo nível, ou null se já é Avançado.
  final NivelTreino? proximo;
  const ProgressoNivel(this.nivel, this.aumentos, this.exercicios,
      this.semanas, this.progresso, this.proximo);

  /// Texto curto do que falta para o próximo nível.
  String get falta {
    final r = proximo == NivelTreino.intermediario
        ? _reqIntermediario
        : _reqAvancado;
    if (proximo == null) return '';
    return '$aumentos/${r.aumentos} aumentos de carga • '
        '$exercicios/${r.exercicios} exercícios • '
        '$semanas/${r.semanas} semanas';
  }
}

DateTime _segunda(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

ProgressoNivel calcularNivel(List<Sessao> sessoes) {
  final lista = sessoes
      .where((s) => !s.cardio && s.detalhes != null)
      .toList()
    ..sort((a, b) => a.data.compareTo(b.data));

  final maior = <String, double>{};
  final comAumento = <String>{};
  final semanas = <String>{};
  var aumentos = 0;

  for (final s in lista) {
    final dt = DateTime.tryParse(s.data);
    if (dt != null) semanas.add(chaveData(_segunda(dt)));
    for (final m in s.detalhes!) {
      final nome = (m['nome'] ?? '') as String;
      if (nome.isEmpty) continue;
      var mx = 0.0;
      for (final c in (m['cargas'] as List?) ?? const []) {
        final v = (c as num).toDouble();
        if (v > mx) mx = v;
      }
      if (mx <= 0) continue;
      final ant = maior[nome];
      if (ant != null && mx > ant + 0.01) {
        aumentos++;
        comAumento.add(nome);
      }
      if (ant == null || mx > ant) maior[nome] = mx;
    }
  }

  bool atinge(_Req r) =>
      aumentos >= r.aumentos &&
      comAumento.length >= r.exercicios &&
      semanas.length >= r.semanas;

  double frac(int v, int n) => n == 0 ? 1 : (v / n).clamp(0.0, 1.0);
  double prog(_Req r) =>
      (frac(aumentos, r.aumentos) +
          frac(comAumento.length, r.exercicios) +
          frac(semanas.length, r.semanas)) /
      3;

  if (atinge(_reqAvancado)) {
    return ProgressoNivel(NivelTreino.avancado, aumentos, comAumento.length,
        semanas.length, 1, null);
  }
  if (atinge(_reqIntermediario)) {
    return ProgressoNivel(NivelTreino.intermediario, aumentos,
        comAumento.length, semanas.length, prog(_reqAvancado),
        NivelTreino.avancado);
  }
  return ProgressoNivel(NivelTreino.iniciante, aumentos, comAumento.length,
      semanas.length, prog(_reqIntermediario), NivelTreino.intermediario);
}
