import 'package:flutter/material.dart';

import '../models/point_of_sale.dart';

/// What the market form collects.
class MarketDetails {
  final String name;
  final String city;
  final String? area;
  final String? address;

  const MarketDetails({
    required this.name,
    required this.city,
    this.area,
    this.address,
  });
}

/// Add or edit a market.
///
/// Name and city are required because the schema requires them, and because a
/// market list without a city stops being searchable the moment a chain has
/// branches in more than one place.
class MarketFormDialog extends StatefulWidget {
  /// The market being edited, or null when adding a new one.
  final PointOfSale? existing;

  const MarketFormDialog({super.key, this.existing});

  @override
  State<MarketFormDialog> createState() => _MarketFormDialogState();
}

class _MarketFormDialogState extends State<MarketFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _area = TextEditingController(text: widget.existing?.area ?? '');
  late final _address = TextEditingController(
    text: widget.existing?.address ?? '',
  );

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _area.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      MarketDetails(
        name: _name.text.trim(),
        city: _city.text.trim(),
        area: _area.text.trim(),
        address: _address.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit market' : 'Add market'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Market name',
                    hintText: 'Carrefour City Centre',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Give this market a name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    hintText: 'Ramallah',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter the city' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _area,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Area or district (optional)',
                    hintText: 'Al-Masyoun',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  textCapitalization: TextCapitalization.sentences,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Add market'),
        ),
      ],
    );
  }
}

/// What the fridge form collects.
class FridgeDetails {
  final String name;
  final double? widthCm;
  final double? heightCm;

  /// How many shelves this fridge is split into.
  ///
  /// Fixed here at setup rather than chosen per visit: a fridge split three
  /// ways one week and two the next produces a trend line that means nothing.
  final int sectionCount;

  const FridgeDetails({
    required this.name,
    required this.sectionCount,
    this.widthCm,
    this.heightCm,
  });
}

/// Add a fridge to a market.
class FridgeFormDialog extends StatefulWidget {
  const FridgeFormDialog({super.key});

  @override
  State<FridgeFormDialog> createState() => _FridgeFormDialogState();
}

class _FridgeFormDialogState extends State<FridgeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  int _sections = 1;

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  static double? _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      FridgeDetails(
        name: _name.text.trim(),
        sectionCount: _sections,
        widthCm: _parse(_width.text),
        heightCm: _parse(_height.text),
      ),
    );
  }

  String? _validateSize(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) return 'Enter a number in cm';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add fridge'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Fridge name',
                    hintText: 'Entrance cooler',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Give this fridge a name'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _width,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Width cm',
                        ),
                        validator: _validateSize,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _height,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Height cm',
                        ),
                        validator: _validateSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Shelves',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How many shelves a rep photographs separately. Fixed at '
                  'setup — changing it later breaks comparisons over time.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 3, label: Text('3')),
                    ButtonSegment(value: 4, label: Text('4')),
                    ButtonSegment(value: 5, label: Text('5')),
                  ],
                  selected: {_sections},
                  onSelectionChanged: (s) => setState(() => _sections = s.first),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add fridge')),
      ],
    );
  }
}
