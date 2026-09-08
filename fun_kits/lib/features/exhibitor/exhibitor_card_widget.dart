import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/exhibitor_model.dart';

/// A fully branded exhibitor card. Customizes its colors from
/// [ExhibitorModel.themeColor]. Can be used in list views,
/// grids, or as a standalone detail card.
class ExhibitorCardWidget extends StatelessWidget {
  const ExhibitorCardWidget({
    super.key,
    required this.exhibitor,
    this.onTap,
    this.compact = false,
  });

  final ExhibitorModel exhibitor;
  final VoidCallback? onTap;

  /// Compact mode renders a smaller card suitable for grids
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return compact
        ? _CompactCard(exhibitor: exhibitor, onTap: onTap)
        : _FullCard(exhibitor: exhibitor, onTap: onTap);
  }
}

// ─── Full Card ───────────────────────────────────────────────────────────────
class _FullCard extends StatelessWidget {
  const _FullCard({required this.exhibitor, this.onTap});

  final ExhibitorModel exhibitor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = exhibitor.themeColor;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Branded banner ──────────────────────────────────────
            _BannerSection(exhibitor: exhibitor),

            // ── Body ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo avatar
                  _LogoAvatar(exhibitor: exhibitor, size: 56),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                exhibitor.name,
                                style: AppTextStyles.headingMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (exhibitor.isSponsored)
                              _SponsoredBadge(color: color),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exhibitor.description,
                          style: AppTextStyles.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // Tags
                        if (exhibitor.tags.isNotEmpty)
                          _TagRow(
                              tags: exhibitor.tags, color: color),
                        const SizedBox(height: 10),
                        // Contact row
                        _ContactRow(exhibitor: exhibitor, color: color),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Compact Card ────────────────────────────────────────────────────────────
class _CompactCard extends StatelessWidget {
  const _CompactCard({required this.exhibitor, this.onTap});

  final ExhibitorModel exhibitor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = exhibitor.themeColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: color.withOpacity(0.3), width: 1.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LogoAvatar(exhibitor: exhibitor, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exhibitor.name,
                          style: AppTextStyles.headingSmall
                              .copyWith(color: color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (exhibitor.boothNumber.isNotEmpty)
                        Text('Booth ${exhibitor.boothNumber}',
                            style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              exhibitor.description,
              style: AppTextStyles.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Subcomponents ───────────────────────────────────────────────────────────

class _BannerSection extends StatelessWidget {
  const _BannerSection({required this.exhibitor});
  final ExhibitorModel exhibitor;

  @override
  Widget build(BuildContext context) {
    final color = exhibitor.themeColor;
    return SizedBox(
      height: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: color.withOpacity(0.15)),
          // Decorative circles
          Positioned(
              right: -20,
              top: -20,
              child: _Circle(color: color, size: 90, opacity: 0.15)),
          Positioned(
              right: 50,
              bottom: -30,
              child: _Circle(color: color, size: 70, opacity: 0.10)),
          Positioned(
              left: -10,
              bottom: -15,
              child: _Circle(color: color, size: 55, opacity: 0.08)),
          // Category chip
          Positioned(
            top: 10,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                exhibitor.category,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          // Booth number chip
          if (exhibitor.boothNumber.isNotEmpty)
            Positioned(
              top: 10,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Booth ${exhibitor.boothNumber}',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle(
      {required this.color,
      required this.size,
      required this.opacity});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      );
}

class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({required this.exhibitor, required this.size});
  final ExhibitorModel exhibitor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = exhibitor.themeColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius:
            BorderRadius.circular(size * 0.25),
        border: Border.all(
            color: color.withOpacity(0.4), width: 1.5),
      ),
      child: exhibitor.hasLogo
          ? ClipRRect(
              borderRadius:
                  BorderRadius.circular(size * 0.23),
              child: CachedNetworkImage(
                imageUrl: exhibitor.logoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Center(
                  child: Icon(Icons.store_rounded,
                      color: color, size: size * 0.45),
                ),
                errorWidget: (_, __, ___) => Center(
                  child: Icon(Icons.store_rounded,
                      color: color, size: size * 0.45),
                ),
              ),
            )
          : Center(
              child: Text(
                exhibitor.name.isNotEmpty
                    ? exhibitor.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.tags, required this.color});
  final List<String> tags;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags
          .take(3)
          .map((tag) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
              ))
          .toList(),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(
      {required this.exhibitor, required this.color});
  final ExhibitorModel exhibitor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (exhibitor.contactEmail.isNotEmpty) ...[
          Icon(Icons.email_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              exhibitor.contactEmail,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (exhibitor.contactPhone.isNotEmpty) ...[
          const SizedBox(width: 12),
          Icon(Icons.phone_outlined, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            exhibitor.contactPhone,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: AppColors.accent.withOpacity(0.5), width: 1),
      ),
      child: const Text(
        '★ Sponsor',
        style: TextStyle(
            fontSize: 10,
            color: AppColors.warning,
            fontWeight: FontWeight.w800),
      ),
    );
  }
}
