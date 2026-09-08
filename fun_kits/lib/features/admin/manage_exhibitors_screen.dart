import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/services/firestore_service.dart';

class ManageExhibitorsScreen extends StatefulWidget {
  const ManageExhibitorsScreen({super.key});

  @override
  State<ManageExhibitorsScreen> createState() =>
      _ManageExhibitorsScreenState();
}

class _ManageExhibitorsScreenState extends State<ManageExhibitorsScreen> {
  final _service = FirestoreService();
  final _searchCtrl = TextEditingController();
  String _activeSearch = '';
  String _selectedCategory = 'All';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _showDialog([ExhibitorModel? existing]) {
    showDialog(
      context: context,
      builder: (_) =>
          _ExhibitorFormDialog(service: _service, existing: existing),
    );
  }

  void _confirmDelete(ExhibitorModel ex) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Exhibitor?'),
        content: Text(
            'Remove "${ex.name}"? Visitors will no longer see this booth.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _service.deleteExhibitor(ex.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${ex.name}" deleted.')));
              }
            },
            child:
            const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Manage Exhibitors 🏢',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.textDark,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        backgroundColor: AppColors.exhibitorColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Exhibitor',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<ExhibitorModel>>(
        stream: _service.getExhibitors(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          final categories = ['All', ...{
            for (final e in all) e.category
          }.toList()..sort()];

          final filtered = all.where((e) {
            final matchSearch = _activeSearch.isEmpty ||
                e.name.toLowerCase().contains(_activeSearch.toLowerCase()) ||
                e.category.toLowerCase().contains(_activeSearch.toLowerCase()) ||
                e.boothNumber
                    .toLowerCase()
                    .contains(_activeSearch.toLowerCase());
            final matchCat = _selectedCategory == 'All' ||
                e.category == _selectedCategory;
            return matchSearch && matchCat;
          }).toList();

          if (all.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.store_outlined,
                    size: 64,
                    color: AppColors.textMedium.withOpacity(0.4)),
                const SizedBox(height: 12),
                const Text('No exhibitors yet.',
                    style: TextStyle(
                        color: AppColors.textMedium, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Tap + to add your first booth.',
                    style: TextStyle(color: AppColors.textMedium)),
              ]),
            );
          }

          return Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search booths...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textMedium),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchCtrl.text.isNotEmpty)
                          IconButton(
                              icon: const Icon(Icons.clear_rounded,
                                  color: AppColors.textMedium),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _activeSearch = '');
                              }),
                        IconButton(
                          icon: const Icon(Icons.search_rounded,
                              color: AppColors.exhibitorColor),
                          onPressed: () {
                            setState(() => _activeSearch = _searchCtrl.text);
                          },
                        ),
                      ],
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFE0DFFF), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              // Category filter
              if (categories.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final selected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.exhibitorColor
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: selected
                                    ? AppColors.exhibitorColor
                                    : const Color(0xFFE0DFFF)),
                          ),
                          child: Text(cat,
                              style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textMedium,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Text(
                        '${filtered.length} of ${all.length} exhibitor${all.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppColors.textMedium, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No results found.'))
                    : ListView.separated(
                  padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final ex = filtered[i];
                    return _ExhibitorTile(
                      exhibitor: ex,
                      onEdit: () => _showDialog(ex),
                      onDelete: () => _confirmDelete(ex),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExhibitorTile extends StatelessWidget {
  const _ExhibitorTile({
    required this.exhibitor,
    required this.onEdit,
    required this.onDelete,
  });

  final ExhibitorModel exhibitor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = exhibitor.themeColor;
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border:
        Border.all(color: color.withOpacity(0.25), width: 1.4),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            exhibitor.name.isNotEmpty
                ? exhibitor.name[0].toUpperCase()
                : '?',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(exhibitor.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exhibitor.boothNumber.isNotEmpty)
              Text(
                  'Booth ${exhibitor.boothNumber}  •  ${exhibitor.category}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMedium)),
            if (exhibitor.isSponsored)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('⭐ Sponsored',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppColors.textMedium,
                onPressed: onEdit),
            IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.red.shade300,
                onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _ExhibitorFormDialog extends StatefulWidget {
  const _ExhibitorFormDialog(
      {required this.service, required this.existing});
  final FirestoreService service;
  final ExhibitorModel? existing;

  @override
  State<_ExhibitorFormDialog> createState() =>
      _ExhibitorFormDialogState();
}

class _ExhibitorFormDialogState
    extends State<_ExhibitorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _booth;
  late final TextEditingController _category;
  late final TextEditingController _tags;
  late final TextEditingController _color;
  late bool _isSponsored;
  late Color _pickedColor;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _email = TextEditingController(text: e?.contactEmail ?? '');
    _phone = TextEditingController(text: e?.contactPhone ?? '');
    _website = TextEditingController(text: e?.website ?? '');
    _booth = TextEditingController(text: e?.boothNumber ?? '');
    _category = TextEditingController(text: e?.category ?? 'General');
    _tags = TextEditingController(text: e?.tags.join(', ') ?? '');
    _color =
        TextEditingController(text: e?.themeColorHex ?? '#6C63FF');
    _isSponsored = e?.isSponsored ?? false;
    _pickedColor = _hexToColor(_color.text);
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // add opacity
    return Color(int.parse(hex, radix: 16));
  }

  @override
  void dispose() {
    for (final c in [
      _name, _description, _email, _phone, _website, _booth,
      _category, _tags, _color
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final tagList = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final model = ExhibitorModel(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      description: _description.text.trim(),
      contactEmail: _email.text.trim(),
      contactPhone: _phone.text.trim(),
      website: _website.text.trim(),
      boothNumber: _booth.text.trim(),
      category: _category.text.trim().isEmpty
          ? 'General'
          : _category.text.trim(),
      tags: tagList,
      themeColorHex: _color.text.trim().isEmpty
          ? '#6C63FF'
          : _color.text.trim(),
      isSponsored: _isSponsored,
      logoUrl: widget.existing?.logoUrl ?? '',
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    try {
      if (widget.existing == null) {
        await widget.service.addExhibitor(model);
      } else {
        await widget.service.updateExhibitor(model);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Exhibitor' : 'Add Exhibitor',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Company Name *',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Required'
                        : null),
                _field(_description, 'Description', maxLines: 3),
                _field(_email, 'Contact Email *',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Required'
                        : null),
                _field(_phone, 'Contact Phone',
                    keyboardType: TextInputType.phone),
                _field(_website, 'Website'),
                _field(_booth, 'Booth Number'),
                _field(_category, 'Category'),
                _field(_tags, 'Tags (comma-separated)'),
                // Color picker
                GestureDetector(
                  onTap: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Pick Theme Color'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: _pickedColor,
                            onColorChanged: (color) {
                              setState(() {
                                _pickedColor = color;
                                _color.text =
                                '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                              });
                            },
                            pickerAreaHeightPercent: 0.8,
                          ),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Done')),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _pickedColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Theme Color',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMedium)),
                              Text(_color.text,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const Icon(Icons.colorize_outlined,
                            color: AppColors.textMedium),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isSponsored,
                  onChanged: (v) =>
                      setState(() => _isSponsored = v),
                  title: const Text('Sponsored Exhibitor'),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.exhibitorColor,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.exhibitorColor),
          child: _saving
              ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : Text(isEdit ? 'Save Changes' : 'Add Exhibitor'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1,
        TextInputType? keyboardType,
        String? Function(String?)? validator,
        String? hintText}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
