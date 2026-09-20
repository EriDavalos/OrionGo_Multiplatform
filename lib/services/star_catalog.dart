import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/stars.dart';

/// Carga el catálogo de estrellas (assets/data/stars.json) una sola vez y
/// cachea los objetos ya precesados a la fecha de hoy.
class StarCatalog {
  StarCatalog._();

  static List<Star>? _all;

  static Future<List<Star>> load() async {
    final cached = _all;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/data/stars.json');
    final rows = jsonDecode(raw) as List<dynamic>;
    final now = DateTime.now();

    final stars = <Star>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final star = Star.coordinates(
        _d(row['rahj2000']),
        _d(row['ramj2000']),
        _d(row['rasj2000']),
        _d(row['decgj2000']),
        _d(row['decmj2000']),
        _d(row['decsj2000']),
        (row['starname'] ?? '').toString(),
        _i(row['id_type']),
        _d(row['mag']),
      );
      star.precess(now);
      stars.add(star);
    }

    _all = stars;
    return stars;
  }

  static double _d(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static int _i(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  /// Estrellas visibles para una magnitud límite (equivale a loadSkyMap()).
  static Future<List<Star>> upToMagnitude(double magMax) async {
    final all = await load();
    return all.where((star) => star.mag <= magMax).toList();
  }

  /// Búsqueda por nombre y tipo (equivale a sqlite.getStars()).
  static Future<List<Star>> search(String query, int type) async {
    final all = await load();
    final q = query.trim().toLowerCase();
    return all.where((star) {
      final matchesType = type == 0 || star.type == type;
      if (!matchesType) return false;
      if (q.isEmpty) return true;
      return star.name.toLowerCase().contains(q);
    }).toList();
  }
}
