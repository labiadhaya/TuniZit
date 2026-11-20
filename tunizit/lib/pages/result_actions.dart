import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/scan_service.dart';
import '../theme/app_theme.dart';

/// Numéro WhatsApp de l'expert (format international sans « + », ex. 21612345678).
/// Lancer avec : flutter run --dart-define=EXPERT_WHATSAPP=21612345678
/// Si vide, le bouton WhatsApp est masqué.
const _expertWhatsapp = String.fromEnvironment('EXPERT_WHATSAPP');

Future<void> showAssignParcelSheet(BuildContext context, ScanResult result) =>
    _showSheet(context, _AssignParcelSheet(result: result));

Future<void> showExpertSheet(BuildContext context, ScanResult result) =>
    _showSheet(context, _ExpertSheet(result: result));

Future<void> _showSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: SingleChildScrollView(child: child),
    ),
  );
}

String _diagnosisName(ScanResult r) {
  if (r.isHealthy) return 'Olivier en bonne santé';
  final fr = r.diseaseFr?.trim();
  return (fr != null && fr.isNotEmpty) ? fr : 'Diagnostic incertain';
}

// ───────────────────────── Éléments communs ─────────────────────────

class _Grabber extends StatelessWidget {
  const _Grabber();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.tileBorder,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SheetTitle(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, height: 1.35),
      ),
      const SizedBox(height: 16),
    ],
  );
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final int maxLines;
  final int? maxLength;
  const _Input({
    required this.controller,
    required this.label,
    this.keyboard,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.tile,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.tileBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.tileBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
        ),
      ),
    ),
  );
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.danger, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final bool soft;
  final VoidCallback? onPressed;
  const _SheetButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.soft = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: soft ? AppColors.lime : AppColors.forest,
        foregroundColor: soft ? AppColors.forest : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
    ),
  );
}

// ───────────────────────── Associer à une parcelle ─────────────────────────

class _AssignParcelSheet extends StatefulWidget {
  final ScanResult result;
  const _AssignParcelSheet({required this.result});
  @override
  State<_AssignParcelSheet> createState() => _AssignParcelSheetState();
}

class _AssignParcelSheetState extends State<_AssignParcelSheet> {
  List<Parcel>? _parcels;
  String? _selected;
  bool _creating = false;
  bool _busy = false;
  String? _error;

  final _name = TextEditingController();
  final _location = TextEditingController();
  final _variety = TextEditingController();
  final _trees = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _variety.dispose();
    _trees.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await ParcelService.list();
      if (!mounted) return;
      setState(() {
        _parcels = list;
        _creating = list.isEmpty;
        _selected = list.isNotEmpty ? list.first.id : null;
      });
    } on ScanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    final scanId = widget.result.dbId;
    if (scanId == null) {
      setState(
        () => _error =
            'Ce scan n’a pas pu être sauvegardé : association impossible.',
      );
      return;
    }
    if (_creating && _name.text.trim().isEmpty) {
      setState(() => _error = 'Donnez un nom à la parcelle.');
      return;
    }
    if (!_creating && _selected == null) {
      setState(() => _error = 'Choisissez une parcelle.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      Parcel parcel;
      if (_creating) {
        parcel = await ParcelService.create(
          name: _name.text.trim(),
          location: _location.text.trim().isEmpty
              ? null
              : _location.text.trim(),
          variety: _variety.text.trim().isEmpty ? null : _variety.text.trim(),
          treesCount: int.tryParse(_trees.text.trim()),
        );
        // Si l'association échoue ensuite, un nouvel essai réutilisera cette parcelle.
        _parcels = [parcel, ...?_parcels];
        _selected = parcel.id;
        _creating = false;
      } else {
        parcel = _parcels!.firstWhere((p) => p.id == _selected);
      }

      await ParcelService.assignScan(scanId, parcel.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Scan associé à « ${parcel.name} ».')),
        );
    } on ScanException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _parcels == null && _error == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Grabber(),
        _SheetTitle(
          'Associer à une parcelle',
          'Diagnostic : ${_diagnosisName(widget.result)}',
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (_parcels != null && _parcels!.isNotEmpty && !_creating)
            ..._parcels!.map(
              (p) => _ParcelTile(
                parcel: p,
                selected: p.id == _selected,
                onTap: () => setState(() => _selected = p.id),
              ),
            ),
          if (_creating) ...[
            _Input(
              controller: _name,
              label: 'Nom de la parcelle *',
              maxLength: 80,
            ),
            _Input(
              controller: _location,
              label: 'Localisation (ex. Sfax, Sakiet Ezzit)',
            ),
            _Input(controller: _variety, label: 'Variété (ex. Chemlali)'),
            _Input(
              controller: _trees,
              label: 'Nombre d’arbres',
              keyboard: TextInputType.number,
            ),
          ],
          if (_parcels != null && _parcels!.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() => _creating = !_creating),
                icon: Icon(_creating ? Icons.list : Icons.add, size: 18),
                label: Text(
                  _creating
                      ? 'Choisir une parcelle existante'
                      : 'Nouvelle parcelle',
                ),
              ),
            ),
          if (_error != null) _ErrorText(_error!),
          const SizedBox(height: 4),
          _SheetButton(
            label: _creating ? 'Créer et associer' : 'Associer',
            icon: Icons.link,
            busy: _busy,
            onPressed: _submit,
          ),
        ],
        if (loading == false && _parcels == null && _error != null) ...[
          const SizedBox(height: 4),
          _SheetButton(
            label: 'Réessayer',
            icon: Icons.refresh,
            soft: true,
            onPressed: () {
              setState(() => _error = null);
              _load();
            },
          ),
        ],
      ],
    );
  }
}

class _ParcelTile extends StatelessWidget {
  final Parcel parcel;
  final bool selected;
  final VoidCallback onTap;
  const _ParcelTile({
    required this.parcel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.lime.withAlpha(120) : AppColors.tile,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.tileBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.forest : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parcel.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (parcel.subtitle.isNotEmpty)
                      Text(
                        parcel.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Contacter un expert ─────────────────────────

class _ExpertSheet extends StatefulWidget {
  final ScanResult result;
  const _ExpertSheet({required this.result});
  @override
  State<_ExpertSheet> createState() => _ExpertSheetState();
}

class _ExpertSheetState extends State<_ExpertSheet> {
  final _phone = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  static final _phoneRe = RegExp(r'^\+?[0-9 ()-]{8,20}$');

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  String _summary() {
    final r = widget.result;
    final pct = (r.confidence * 100).toStringAsFixed(0);
    final id = r.scanId != null ? ' (scan ${r.scanId})' : '';
    return 'Bonjour, j’ai analysé mon olivier avec TuniZit$id. '
        'Diagnostic : ${_diagnosisName(r)}, confiance $pct %. '
        'Pouvez-vous m’aider ?';
  }

  Future<void> _send() async {
    final phone = _phone.text.trim();
    if (!_phoneRe.hasMatch(phone)) {
      setState(() => _error = 'Entrez un numéro de téléphone valide.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ExpertService.request(
        scanDbId: widget.result.dbId,
        phone: phone,
        message: _message.text.trim().isEmpty ? null : _message.text.trim(),
      );
      if (mounted) setState(() => _sent = true);
    } on ScanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _whatsapp() async {
    try {
      final uri = Uri.https('wa.me', '/$_expertWhatsapp', {'text': _summary()});
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted)
        setState(() => _error = 'Impossible d’ouvrir WhatsApp.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible d’ouvrir WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Grabber(),
          const Icon(Icons.check_circle, size: 56, color: AppColors.leaf),
          const SizedBox(height: 12),
          const Text(
            'Demande enregistrée',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Votre demande a été transmise avec le numéro ${_phone.text.trim()}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          _SheetButton(
            label: 'Fermer',
            icon: Icons.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Grabber(),
        _SheetTitle(
          'Consulter un expert agronome',
          'Diagnostic : ${_diagnosisName(widget.result)}. Laissez votre numéro pour être recontacté.',
        ),
        _Input(
          controller: _phone,
          label: 'Votre téléphone *',
          keyboard: TextInputType.phone,
        ),
        _Input(
          controller: _message,
          label: 'Message (facultatif)',
          maxLines: 3,
          maxLength: 500,
        ),
        if (_error != null) _ErrorText(_error!),
        _SheetButton(
          label: 'Envoyer ma demande',
          icon: Icons.send_outlined,
          busy: _busy,
          onPressed: _send,
        ),
        if (_expertWhatsapp.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SheetButton(
            label: 'Écrire sur WhatsApp',
            icon: Icons.chat_outlined,
            soft: true,
            onPressed: _whatsapp,
          ),
        ],
      ],
    );
  }
}
