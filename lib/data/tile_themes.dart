import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colour theme for the board and tiles.
class TileTheme {
  final String id;
  final int price;
  final Color background;
  final Color board;
  final Color emptyCell;

  /// Colours for 2, 4, 8, … in order; bigger values reuse the last colours.
  final List<Color> tiles;
  final Color darkText;
  final Color lightText;

  const TileTheme({
    required this.id,
    required this.price,
    required this.background,
    required this.board,
    required this.emptyCell,
    required this.tiles,
    this.darkText = const Color(0xFF5B4F45),
    this.lightText = Colors.white,
  });

  int _index(int value) => (math.log(value) / math.ln2).round() - 1;

  Color tileColor(int value) {
    final i = _index(value);
    return tiles[i.clamp(0, tiles.length - 1)];
  }

  Color textColor(int value) =>
      tileColor(value).computeLuminance() > 0.5 ? darkText : lightText;
}

class TileThemes {
  static const classic = TileTheme(
    id: 'classic',
    price: 0,
    background: Color(0xFFFAF8EF),
    board: Color(0xFFBBADA0),
    emptyCell: Color(0xFFCDC1B4),
    tiles: [
      Color(0xFFEEE4DA),
      Color(0xFFEDE0C8),
      Color(0xFFF2B179),
      Color(0xFFF59563),
      Color(0xFFF67C5F),
      Color(0xFFF65E3B),
      Color(0xFFEDCF72),
      Color(0xFFEDCC61),
      Color(0xFFEDC850),
      Color(0xFFEDC53F),
      Color(0xFFEDC22E),
      Color(0xFF3C3A32),
      Color(0xFF2C2A24),
      Color(0xFF1C1A16),
    ],
  );

  static const midnight = TileTheme(
    id: 'midnight',
    price: 0,
    background: Color(0xFF12141F),
    board: Color(0xFF232838),
    emptyCell: Color(0xFF2E3448),
    darkText: Color(0xFF1A1D2B),
    tiles: [
      Color(0xFF3A4160),
      Color(0xFF46507A),
      Color(0xFF4F6BED),
      Color(0xFF5B8DEF),
      Color(0xFF38B6FF),
      Color(0xFF22D3EE),
      Color(0xFF2DD4BF),
      Color(0xFF34D399),
      Color(0xFFA3E635),
      Color(0xFFFACC15),
      Color(0xFFF97316),
      Color(0xFFEF4444),
      Color(0xFFEC4899),
      Color(0xFFA855F7),
    ],
  );

  static const ocean = TileTheme(
    id: 'ocean',
    price: 300,
    background: Color(0xFFE8F6FA),
    board: Color(0xFF7FB5C7),
    emptyCell: Color(0xFFA6CEDB),
    darkText: Color(0xFF12404F),
    tiles: [
      Color(0xFFE0F7FA),
      Color(0xFFB2EBF2),
      Color(0xFF80DEEA),
      Color(0xFF4DD0E1),
      Color(0xFF26C6DA),
      Color(0xFF00ACC1),
      Color(0xFF0097A7),
      Color(0xFF00838F),
      Color(0xFF006064),
      Color(0xFF01579B),
      Color(0xFF0D47A1),
      Color(0xFF1A237E),
      Color(0xFF311B92),
      Color(0xFF4A148C),
    ],
  );

  static const candy = TileTheme(
    id: 'candy',
    price: 600,
    background: Color(0xFFFFF0F6),
    board: Color(0xFFE7A4C2),
    emptyCell: Color(0xFFF2C4D8),
    darkText: Color(0xFF6B2146),
    tiles: [
      Color(0xFFFFE4EF),
      Color(0xFFFFCCE0),
      Color(0xFFFFA8CB),
      Color(0xFFFF85B5),
      Color(0xFFFF5C9D),
      Color(0xFFE91E7A),
      Color(0xFFC51162),
      Color(0xFFB388FF),
      Color(0xFF9C6BFF),
      Color(0xFF7C4DFF),
      Color(0xFF651FFF),
      Color(0xFF6200EA),
      Color(0xFF4A00B0),
      Color(0xFF32007A),
    ],
  );

  static const forest = TileTheme(
    id: 'forest',
    price: 900,
    background: Color(0xFFF1F5EC),
    board: Color(0xFF8FA77E),
    emptyCell: Color(0xFFB4C6A6),
    darkText: Color(0xFF2E3B22),
    tiles: [
      Color(0xFFEFF5E6),
      Color(0xFFDCEBC8),
      Color(0xFFC5E1A5),
      Color(0xFFAED581),
      Color(0xFF9CCC65),
      Color(0xFF7CB342),
      Color(0xFF558B2F),
      Color(0xFF33691E),
      Color(0xFFA1887F),
      Color(0xFF8D6E63),
      Color(0xFF6D4C41),
      Color(0xFF4E342E),
      Color(0xFF3E2723),
      Color(0xFF261712),
    ],
  );

  static const neon = TileTheme(
    id: 'neon',
    price: 1500,
    background: Color(0xFF0A0A0F),
    board: Color(0xFF16161F),
    emptyCell: Color(0xFF22222E),
    darkText: Color(0xFF0A0A0F),
    tiles: [
      Color(0xFF39FF14),
      Color(0xFF00FFEF),
      Color(0xFF00B3FF),
      Color(0xFF7A5CFF),
      Color(0xFFD14BFF),
      Color(0xFFFF2BD6),
      Color(0xFFFF2E63),
      Color(0xFFFF6B1A),
      Color(0xFFFFB800),
      Color(0xFFFFF200),
      Color(0xFFFFFFFF),
      Color(0xFFFF0055),
      Color(0xFF00FF9C),
      Color(0xFF9D00FF),
    ],
  );

  static const all = [classic, midnight, ocean, candy, forest, neon];

  static TileTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => classic);
}
