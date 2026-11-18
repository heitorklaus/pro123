class SolarPdfIcons {
  static String _svgWrap(String paths, {String color = '#0F172A', int size = 24, double strokeWidth = 2.0}) {
    return '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$color" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">$paths</svg>';
  }

  static String shieldCheck(String color, {int size = 24}) => _svgWrap(
    '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>',
    color: color, size: size,
  );
  static String dollar(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="12" r="10"/><path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8"/><path d="M12 6v12"/>',
    color: color, size: size,
  );
  static String solarTech(String color, {int size = 24}) => _svgWrap(
    '<path d="M12 2v2"/><path d="M4.93 4.93l1.41 1.41"/><path d="M2 12h2"/><path d="M19.07 4.93l-1.41 1.41"/><path d="M6 10l-3 10h18l-3-10H6z"/><path d="M6 15h12"/><path d="M12 10v10"/>',
    color: color, size: size,
  );
  static String thumbsUp(String color, {int size = 24}) => _svgWrap(
    '<path d="M7 10v12"/><path d="M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h3"/><path d="M10 5a3 3 0 0 1 6 0"/>',
    color: color, size: size,
  );
  static String lightbulb(String color, {int size = 24}) => _svgWrap(
    '<path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/>',
    color: color, size: size,
  );
  static String smartphone(String color, {int size = 24}) => _svgWrap(
    '<rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/>',
    color: color, size: size,
  );
  static String truck(String color, {int size = 24}) => _svgWrap(
    '<path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/><path d="M15 18H9"/><path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62l-3.48-4.35A1 1 0 0 0 17.52 8H14v10"/><circle cx="17" cy="18.5" r="2.5"/><circle cx="7" cy="18.5" r="2.5"/>',
    color: color, size: size,
  );
  static String award(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="8" r="6"/><path d="m15.477 12.89 1.515 8.526a.5.5 0 0 1-.724.522L12 19.8l-4.268 2.138a.5.5 0 0 1-.724-.522l1.515-8.526"/>',
    color: color, size: size,
  );
  static String bolt(String color, {int size = 24}) => _svgWrap(
    '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>',
    color: color, size: size,
  );
  static String solarPanel(String color, {int size = 24}) => _svgWrap(
    '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 12h18"/><path d="M12 3v18"/>',
    color: color, size: size,
  );
  static String sunWatt(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
    color: color, size: size,
  );
  static String inverter(String color, {int size = 24}) => _svgWrap(
    '<rect width="16" height="16" x="4" y="4" rx="2"/><path d="m9 9 6 6"/><path d="m15 9-6 6"/><path d="M9 1v3"/><path d="M15 1v3"/><path d="M9 20v3"/><path d="M15 20v3"/>',
    color: color, size: size,
  );
  static String roof(String color, {int size = 24}) => _svgWrap(
    '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>',
    color: color, size: size,
  );
  static String trendingUp(String color, {int size = 24}) => _svgWrap(
    '<polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/>',
    color: color, size: size,
  );
  static String rulerSquare(String color, {int size = 24}) => _svgWrap(
    '<path d="M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.41 2.41 0 0 1 0-3.4l2.6-2.6a2.41 2.41 0 0 1 3.4 0Z"/><path d="m14.5 12.5 2-2"/><path d="m11.5 9.5 2-2"/><path d="m8.5 6.5 2-2"/><path d="m17.5 15.5 2-2"/>',
    color: color, size: size,
  );
  static String calendarTable(String color, {int size = 24}) => _svgWrap(
    '<rect width="18" height="16" x="3" y="4" rx="2"/><line x1="3" x2="21" y1="10" y2="10"/><line x1="8" x2="8" y1="2" y2="6"/><line x1="16" x2="16" y1="2" y2="6"/>',
    color: color, size: size,
  );
  static String clock(String color, {int size = 24}) => _svgWrap(
    '<circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15.5 14"/>',
    color: color, size: size,
  );
  static String panelGrid(String color, {int size = 24}) => _svgWrap(
    '<path d="M3 5h18v14H3zM3 12h18M9 5v14m6-14v14"/>',
    color: color, size: size, strokeWidth: 1.65,
  );
  static String inverterBox(String color, {int size = 24}) => _svgWrap(
    '<path d="M6 3h12v18H6zM9 7h6m-3 3-3 5h4l-1 3"/>',
    color: color, size: size, strokeWidth: 1.65,
  );
  static String cablePlug(String color, {int size = 24}) => _svgWrap(
    '<path d="M7 3v5m4-5v5M5 8h8v3a4 4 0 0 1-8 0zm4 7v2a3 3 0 0 0 6 0v-3a3 3 0 0 1 6 0v5"/>',
    color: color, size: size, strokeWidth: 1.65,
  );
  static String documentFile(String color, {int size = 24}) => _svgWrap(
    '<path d="M6 3h8l4 4v14H6zm8 0v5h4M9 12h6m-6 4h6"/>',
    color: color, size: size, strokeWidth: 1.65,
  );
  static String pix(String color, {int size = 24}) => _svgWrap(
    '<path d="M12 3l9 9-9 9-9-9zm-5 9 5 5 5-5m-10 0 5-5 5 5"/>',
    color: color, size: size, strokeWidth: 1.65,
  );
  static String bank(String color, {int size = 24}) => _svgWrap(
    '<path d="M3 9l9-5 9 5H3zm3 3v6m6-6v6m6-6v6M3 21h18"/>',
    color: color, size: size, strokeWidth: 1.65,
  );
}
