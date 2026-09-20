import 'package:flutter/material.dart';

/// Puntos de quiebre usados en toda la app.
/// En teléfono se conserva el diseño de OrionGo_Mobile (drawer + hojas
/// inferiores); a partir de [desktop] el diseño cambia a barra lateral fija y
/// diálogos centrados.
class Breakpoints {
  static const double tablet = 700;
  static const double desktop = 1000;
  static const double wide = 1500;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;
  bool get isTablet => screenWidth >= Breakpoints.tablet && !isDesktop;
  bool get isPhone => screenWidth < Breakpoints.tablet;

  /// Tamaño de texto escalado según el ancho (los `vw` de la app móvil).
  double vw(double factor) => screenWidth * factor / 100;
}

/// Contenedor centrado con ancho máximo cómodo para formularios y listas.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Rejilla simple que pasa de 1 columna en teléfono a N en escritorio.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 280,
    this.spacing = 16,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        var columns = (available / minItemWidth).floor().clamp(1, maxColumns);
        if (available < minItemWidth) columns = 1;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.center,
          children: children
              .map(
                (child) => SizedBox(
                  width: columns == 1
                      ? available
                      : (available - spacing * (columns - 1)) / columns,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}
