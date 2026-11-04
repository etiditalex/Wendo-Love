import 'package:flutter/material.dart';

const _paper = Color(0xFFFFFDF8);
const _ink = Color(0xFF1C1917);
const _inkSoft = Color(0xFF44403C);
const _line = Color(0xFFD6D3D1);
const _mute = Color(0xFFA8A29E);
const _clay = Color(0xFFE72570);

/// Opens a searchable list. Choosing a country, county, or area never asks for an address.
Future<String?> showPlacePicker(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: _PlacePickerSheet(title: title, options: options, selected: selected),
        ),
      );
    },
  );
}

class PlaceField extends StatelessWidget {
  const PlaceField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _inkSoft)),
        const SizedBox(height: 6),
        Material(
          color: _paper,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final picked = await showPlacePicker(context, title: label, options: options, selected: value);
              if (picked != null) onChanged(picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(value, style: const TextStyle(fontSize: 16, color: _ink))),
                  const Icon(Icons.keyboard_arrow_down, color: _mute),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlacePickerSheet extends StatefulWidget {
  const _PlacePickerSheet({required this.title, required this.options, required this.selected});

  final String title;
  final List<String> options;
  final String selected;

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = _filter.trim().toLowerCase();
    final matches = [
      for (final option in widget.options)
        if (needle.isEmpty || option.toLowerCase().contains(needle)) option,
    ];
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(4)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: _inkSoft)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            controller: _query,
            autofocus: widget.options.length > 12,
            decoration: const InputDecoration(
              hintText: 'Search',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _filter = value),
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? const Center(child: Text('Nothing matches that search.', style: TextStyle(color: _inkSoft)))
              : ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final option = matches[index];
                    final chosen = option == widget.selected;
                    return ListTile(
                      title: Text(option, style: const TextStyle(color: _ink, fontSize: 16)),
                      trailing: chosen ? const Icon(Icons.check, color: _clay) : null,
                      onTap: () => Navigator.pop(context, option),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
