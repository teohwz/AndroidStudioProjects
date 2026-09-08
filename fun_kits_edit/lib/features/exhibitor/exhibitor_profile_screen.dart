import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/services/firestore_service.dart';

class ExhibitorProfileScreen extends StatefulWidget {
  const ExhibitorProfileScreen({super.key});

  @override
  State<ExhibitorProfileScreen> createState() => _ExhibitorProfileScreenState();
}

class _ExhibitorProfileScreenState extends State<ExhibitorProfileScreen> {
  final _fs = FirestoreService();
  final _searchCtrl = TextEditingController();
  String _activeSearch = '';
  String _selectedCategory = 'All';
  List<String> _checkedInBooths = [];

  @override
  void initState() {
    super.initState();
    _loadCheckins();
  }

  Future<void> _loadCheckins() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ids = await _fs.getCheckedInBooths(uid);
    if (mounted) setState(() => _checkedInBooths = ids);
  }

  Future<void> _checkIn(ExhibitorModel ex) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_checkedInBooths.contains(ex.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already checked in here!')));
      return;
    }
    final isNew = await _fs.checkInBooth(uid, ex.id);
    if (mounted) {
      if (isNew) {
        setState(() => _checkedInBooths = [..._checkedInBooths, ex.id]);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Checked in! +1 bonus play earned at this booth.')));
      }
    }
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Exhibitors 🏢',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppColors.exhibitorColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ExhibitorModel>>(
        stream: _fs.getExhibitors(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];

          // Build category list
          final categories = ['All', ...{
            for (final e in all) e.category
          }.toList()..sort()];

          // Filter
          final filtered = all.where((e) {
            final matchSearch = _activeSearch.isEmpty ||
                e.name.toLowerCase().contains(_activeSearch.toLowerCase()) ||
                e.category.toLowerCase().contains(_activeSearch.toLowerCase()) ||
                e.boothNumber.toLowerCase().contains(_activeSearch.toLowerCase());
            final matchCat =
                _selectedCategory == 'All' || e.category == _selectedCategory;
            return matchSearch && matchCat;
          }).toList();

          if (all.isEmpty) {
            return const Center(
                child: Text('No exhibitors yet. Admin can add them.'));
          }

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, booth, category...',
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
                            },
                          ),
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
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              // Category chips
              if (categories.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
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
              // Count
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Text('${filtered.length} exhibitor${filtered.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppColors.textMedium, fontSize: 13)),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No results found.'))
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ExhibitorCard(
                    exhibitor: filtered[i],
                    isCheckedIn:
                    _checkedInBooths.contains(filtered[i].id),
                    onCheckIn: () => _checkIn(filtered[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Exhibitor Card ─────────────────────────────────────────────────────────────
class _ExhibitorCard extends StatefulWidget {
  const _ExhibitorCard({
    required this.exhibitor,
    required this.isCheckedIn,
    required this.onCheckIn,
  });

  final ExhibitorModel exhibitor;
  final bool isCheckedIn;
  final VoidCallback onCheckIn;

  @override
  State<_ExhibitorCard> createState() => _ExhibitorCardState();
}

class _ExhibitorCardState extends State<_ExhibitorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ex = widget.exhibitor;
    final color = ex.themeColor;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            height: 60,
            width: double.infinity,
            color: color.withOpacity(0.18),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _BannerPainter(color)),
                ),
                if (ex.boothNumber.isNotEmpty)
                  Positioned(
                    top: 10, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Booth ${ex.boothNumber}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ),
                  ),
                if (ex.isSponsored)
                  Positioned(
                    top: 10, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('⭐ Sponsored',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 11)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: ex.logoUrl.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CachedNetworkImage(
                            imageUrl: ex.logoUrl, fit: BoxFit.cover),
                      )
                          : Icon(Icons.store_rounded, color: color, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark)),
                          Text(ex.category,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textMedium,
                      ),
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Text(ex.description,
                      style: const TextStyle(
                          color: AppColors.textMedium, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (ex.contactEmail.isNotEmpty)
                    _InfoRow(Icons.email_outlined, ex.contactEmail, color),
                  if (ex.contactPhone.isNotEmpty)
                    _InfoRow(Icons.phone_outlined, ex.contactPhone, color),
                  if (ex.website.isNotEmpty)
                    _InfoRow(Icons.language_outlined, ex.website, color),
                  if (ex.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ex.tags
                          .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: widget.isCheckedIn
                        ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 18),
                          SizedBox(width: 6),
                          Text('Checked In',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                        : ElevatedButton.icon(
                      onPressed: widget.onCheckIn,
                      icon: const Icon(Icons.qr_code_scanner_rounded,
                          size: 18),
                      label: const Text('Check In (+1 bonus play)',
                          style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
      ],
    ),
  );
}

class _BannerPainter extends CustomPainter {
  _BannerPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
          Offset(size.width * 0.2 * i, size.height * 0.5), 28, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
