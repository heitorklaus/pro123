/// Biblioteca de Ícones Vetoriais SVG Ultra-Sharp para o PDF Solar
class SolarPdfIcons {
  static String _svgWrap(String paths, {String color = '#0F172A', int size = 24, double strokeWidth = 2.0}) {
    return '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$color" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">$paths</svg>';
  }

  static String shieldCheck(String color, {int size = 24}) => _svgWrap(
    '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>',
    color: color,
    size: size,
  );

  static String dollar(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="12" r="10"/><path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8"/><path d="M12 6v12"/>',
    color: color,
    size: size,
  );

  static String solarTech(String color, {int size = 24}) => _svgWrap(
    '<path d="M12 2v2"/><path d="M4.93 4.93l1.41 1.41"/><path d="M2 12h2"/><path d="M19.07 4.93l-1.41 1.41"/><path d="M6 10l-3 10h18l-3-10H6z"/><path d="M6 15h12"/><path d="M12 10v10"/>',
    color: color,
    size: size,
  );

  static String thumbsUp(String color, {int size = 24}) => _svgWrap(
    '<path d="M7 10v12"/><path d="M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h3"/><path d="M10 5a3 3 0 0 1 6 0"/>',
    color: color,
    size: size,
  );

  static String lightbulb(String color, {int size = 24}) => _svgWrap(
    '<path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/>',
    color: color,
    size: size,
  );

  static String smartphone(String color, {int size = 24}) => _svgWrap(
    '<rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/>',
    color: color,
    size: size,
  );

  static String truck(String color, {int size = 24}) => _svgWrap(
    '<path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/><path d="M15 18H9"/><path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62l-3.48-4.35A1 1 0 0 0 17.52 8H14v10"/><circle cx="17" cy="18.5" r="2.5"/><circle cx="7" cy="18.5" r="2.5"/>',
    color: color,
    size: size,
  );

  static String award(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="8" r="6"/><path d="m15.477 12.89 1.515 8.526a.5.5 0 0 1-.724.522L12 19.8l-4.268 2.138a.5.5 0 0 1-.724-.522l1.515-8.526"/>',
    color: color,
    size: size,
  );

  static String bolt(String color, {int size = 24}) => _svgWrap(
    '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>',
    color: color,
    size: size,
  );

  static String solarPanel(String color, {int size = 24}) => _svgWrap(
    '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 12h18"/><path d="M12 3v18"/>',
    color: color,
    size: size,
  );

  static String sunWatt(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
    color: color,
    size: size,
  );

  static String inverter(String color, {int size = 24}) => _svgWrap(
    '<rect width="16" height="16" x="4" y="4" rx="2"/><path d="m9 9 6 6"/><path d="m15 9-6 6"/><path d="M9 1v3"/><path d="M15 1v3"/><path d="M9 20v3"/><path d="M15 20v3"/>',
    color: color,
    size: size,
  );

  static String roof(String color, {int size = 24}) => _svgWrap(
    '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>',
    color: color,
    size: size,
  );

  static String trendingUp(String color, {int size = 24}) => _svgWrap(
    '<polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/>',
    color: color,
    size: size,
  );

  static String rulerSquare(String color, {int size = 24}) => _svgWrap(
    '<path d="M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.41 2.41 0 0 1 0-3.4l2.6-2.6a2.41 2.41 0 0 1 3.4 0Z"/><path d="m14.5 12.5 2-2"/><path d="m11.5 9.5 2-2"/><path d="m8.5 6.5 2-2"/><path d="m17.5 15.5 2-2"/>',
    color: color,
    size: size,
  );
}
