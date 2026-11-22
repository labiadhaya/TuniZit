import 'package:material_ui/material_ui.dart';

class Opt {
  // اختيار واحد في الفورم: قيمة داخلية، نصّ ظاهر، ومساعدة/أيقونة اختيارية.
  const Opt(this.value, this.label, {this.help, this.icon});
  final String value;
  final String label;
  final String? help;
  final IconData? icon;
}

String labelFor(List<Opt> opts, String? v) {
  // نحوّل القيمة اللي يخزّنها الـ API للاسم اللي يتعرض للمستخدم.
  if (v == null) return 'Non précisé';
  for (final o in opts) {
    if (o.value == v) return o.label;
  }
  return v;
}

const gouvernorats = <String>[
  'Ariana', 'Béja', 'Ben Arous', 'Bizerte', 'Gabès', 'Gafsa', 'Jendouba',
  'Kairouan', 'Kasserine', 'Kébili', 'Le Kef', 'Mahdia', 'La Manouba',
  'Médenine', 'Monastir', 'Nabeul', 'Sfax', 'Sidi Bouzid', 'Siliana',
  'Sousse', 'Tataouine', 'Tozeur', 'Tunis', 'Zaghouan',
];

// الاختيارات الجاهزة لأسئلة المناخ والتربة والماء والإنتاج.
const gelOpts = <Opt>[
  Opt('aucun', 'Aucun', icon: Icons.wb_sunny_outlined),
  Opt('rare', 'Rare',
      help: 'Quelques nuits de gel certaines années.', icon: Icons.cloud_outlined),
  Opt('frequent', 'Fréquent',
      help: 'Du gel chaque hiver.', icon: Icons.ac_unit),
];

const solOpts = <Opt>[
  Opt('sableux', 'Sableux',
      help: 'Terre légère : le sable s\'écoule entre les doigts.', icon: Icons.grain),
  Opt('limoneux', 'Limoneux',
      help: 'Terre douce, ni collante ni sableuse.', icon: Icons.landscape_outlined),
  Opt('argileux', 'Argileux',
      help: 'Terre lourde, collante quand elle est mouillée.', icon: Icons.layers_outlined),
  Opt('calcaire', 'Calcaire',
      help: 'Terre claire, blanchâtre, riche en calcaire.', icon: Icons.terrain),
  Opt('caillouteux', 'Caillouteux',
      help: 'Terre avec beaucoup de pierres.', icon: Icons.filter_hdr),
];

const drainageOpts = <Opt>[
  Opt('bon', 'Bon',
      help: 'L\'eau s\'infiltre vite après la pluie.', icon: Icons.water_drop_outlined),
  Opt('moyen', 'Moyen',
      help: 'L\'eau reste un peu puis disparaît.', icon: Icons.opacity),
  Opt('mauvais', 'Mauvais',
      help: 'L\'eau reste en flaque plusieurs jours.', icon: Icons.waves),
];

const salinityOpts = <Opt>[
  Opt('faible', 'Faible'),
  Opt('moyenne', 'Moyenne'),
  Opt('elevee', 'Élevée', help: 'Croûte blanche de sel visible sur le sol.'),
];

const eauOpts = <Opt>[
  Opt('pluvial', 'Pluie seulement',
      help: 'Aucune irrigation.', icon: Icons.cloud_outlined),
  Opt('appoint', 'Irrigation d\'appoint',
      help: 'Un peu d\'eau en été pour aider les arbres.', icon: Icons.water_drop_outlined),
  Opt('reguliere', 'Irrigation régulière',
      help: 'Arrosage régulier pendant la saison.', icon: Icons.shower_outlined),
];

const irrigationOpts = <Opt>[
  Opt('goutte_a_goutte', 'Goutte à goutte', icon: Icons.water_drop_outlined),
  Opt('autre', 'Autre système', icon: Icons.settings_outlined),
];

const objectifOpts = <Opt>[
  Opt('huile', 'Huile d\'olive', icon: Icons.eco_outlined),
  Opt('table', 'Olives de table', icon: Icons.restaurant_outlined),
  Opt('les_deux', 'Les deux', icon: Icons.all_inclusive),
];

const systemeOpts = <Opt>[
  Opt('traditionnel', 'Traditionnel',
      help: 'Arbres espacés, peu ou pas d\'irrigation.', icon: Icons.park_outlined),
  Opt('intensif', 'Intensif',
      help: 'Plus d\'arbres par hectare, irrigation nécessaire.', icon: Icons.grid_view),
  Opt('super_intensif', 'Super-intensif',
      help: 'Très haute densité, irrigation et récolte mécanique.', icon: Icons.grid_on),
];