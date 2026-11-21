const _months = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

String two(int n) => n.toString().padLeft(2, '0');

/// "30 Octobre"
String frDay(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "30 Octobre 2026"
String frDate(DateTime d) => '${frDay(d)} ${d.year}';

/// "30 Octobre 2026 à 08:00"
String frDateTime(DateTime d) => '${frDate(d)} à ${two(d.hour)}:${two(d.minute)}';

/// "2026-10-30" (format attendu par la colonne SQL `date`)
String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
