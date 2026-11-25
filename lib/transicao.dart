import 'package:flutter/material.dart';
import 'telas.dart' show Fundo;

/// Cada tela ganha o próprio fundo opaco e só desliza, então a tela de baixo
/// não "aparece por trás" durante a troca (era isso que causava a piscada).
class TransicaoSemPiscar extends PageTransitionsBuilder {
  const TransicaoSemPiscar();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curva =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.10, 0), end: Offset.zero)
          .animate(curva),
      child: Fundo(child: child),
    );
  }
}

const kTransicoes = PageTransitionsTheme(builders: {
  TargetPlatform.android: TransicaoSemPiscar(),
  TargetPlatform.iOS: TransicaoSemPiscar(),
  TargetPlatform.fuchsia: TransicaoSemPiscar(),
  TargetPlatform.linux: TransicaoSemPiscar(),
  TargetPlatform.macOS: TransicaoSemPiscar(),
  TargetPlatform.windows: TransicaoSemPiscar(),
});
