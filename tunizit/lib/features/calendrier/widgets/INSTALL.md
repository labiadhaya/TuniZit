# Module Calendrier – Tunizit

## Contenu
```
front/lib/features/calendrier/   -> écran, widgets, modèle, services (mock + http)
front/lib/dev/calendar_dev_main.dart  -> point d'entrée de test (sans toucher main.dart)
back/routes/activities.js        -> routes /api/activities
back/sql/calendar_activities.sql -> table Supabase
```

## 1. Tester le front tout de suite (sans backend)
1. Copie `front/lib/*` dans le `lib/` de ton projet Flutter.
2. `flutter run -t lib/dev/calendar_dev_main.dart`

Il utilise `MockActivityService` : les 3 cartes de la capture, et tout marche
en mémoire (filtres, ajout, compléter, détails, avancement).
Requiert Dart 3 (records) : Flutter >= 3.10.

## 2. Backend
1. Exécute `back/sql/calendar_activities.sql` dans Supabase (vérifie d'abord les types de `exploitations.id` / `parcels.id`).
2. Copie `back/routes/activities.js` et monte-le dans `app.js` :
   `app.use('/api/activities', authMiddleware, require('./routes/activities'));`
3. Adapte si besoin : `require('../supabaseClient')` et `req.user.id`.

## 3. Brancher le front sur le backend
1. `flutter pub add http`
2. Dans l'écran :
```dart
CalendrierScreen(
  service: HttpActivityService(
    baseUrl: 'http://10.0.2.2:5000', // émulateur Android ; IP du PC sur téléphone réel
    getToken: () async => /* JWT Supabase */,
  ),
)
```
`HttpActivityService` suppose `GET /api/exploitations` -> `[{id,name}]` et
`GET /api/parcels` -> `[{id,name,variety,exploitation_id}]`. Adapte si tes routes diffèrent.

## 4. Intégration dans l'onglet « Outils »
Utilise `CalendrierScreen(embedded: true)` : pas de Scaffold, le header, la barre
d'onglets (Travaux & Calendrier / Zakat Agricole / Assistant) et la barre du bas
restent ceux de l'écran parent.

## Pas encore fait
- Notifications locales (rappels) : `reminder_at` est enregistré, mais rien ne se déclenche (flutter_local_notifications à ajouter).
- Vue calendrier mensuelle (route `/calendar` prête côté back).
- Les autres phases phénologiques (voir TODO dans `activities.js`).
