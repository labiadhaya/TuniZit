// Regions d'apres la repartition de l'ONH (document COI "Policies - Tunisia 2012") :
// Nord ; Sahel + Sfax + Centre/Sud-Ouest -> "centre" ; Sud-Est -> "sud".
// Kebili et Tozeur ne figurent pas dans cette liste : classes "sud" par hypothese (a valider).
const norm = (s) =>
  String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim();

const ZONES = {
  nord: ["tunis", "la manouba", "manouba", "ariana", "ben arous", "bizerte", "beja",
         "jendouba", "le kef", "kef", "siliana", "zaghouan", "nabeul"],
  centre: ["sousse", "monastir", "mahdia", "sfax", "kairouan", "kasserine", "gafsa", "sidi bouzid"],
  sud: ["medenine", "gabes", "tataouine", "kebili", "tozeur"],
};

const ZONE_LABEL = { nord: "le nord", centre: "le centre", sud: "le sud" };

function zoneFor(gouvernorat) {
  const n = norm(gouvernorat);
  for (const [zone, list] of Object.entries(ZONES)) if (list.includes(n)) return zone;
  return null;
}

module.exports = { zoneFor, ZONE_LABEL };