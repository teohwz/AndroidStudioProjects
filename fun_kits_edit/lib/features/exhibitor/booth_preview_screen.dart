import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/exhibitor_model.dart';

/// Read-only "what will a visitor see" preview, opened from the exhibitor's
/// own "Customize My Booth" screen (see ExhibitorBoothEditorScreen). Mimics
/// the visual look of the real visitor-facing BoothScreen's header/info
/// area — logo, banner, theme colors, name, welcome message, description,
/// tags, contact info — using whatever the exhibitor currently has typed or
/// picked on the form, even if they haven't tapped "Save Booth" yet.
///
/// Deliberately does NOT reuse BoothScreen itself: BoothScreen auto-checks
/// the visitor in, awards booth-attempt-pool attempts, and renders live,
/// tappable game/quiz/task sections wired to Firestore streams keyed by a
/// real signed-in visitor. None of that belongs in a preview the exhibitor
/// opens on their own account, and unsaved edits (like a logo just
/// uploaded) have no Firestore document to stream from yet anyway. So this
/// screen only re-draws the static, purely-visual parts, from the
/// [exhibitor] snapshot handed to it — no Firestore reads or writes happen
/// here at all.
class BoothPreviewScreen extends StatelessWidget {
  const BoothPreviewScreen({super.key, required this.exhibitor});

  final ExhibitorModel exhibitor;

  @override
  Widget build(BuildContext context) {
    final ex = exhibitor;
    final color = ex.themeColor;

    return Scaffold(
      backgroundColor: ex.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _PreviewBanner(color: color),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Hero(ex: ex, color: color),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mirrors booth_screen.dart: once there's a real
                          // banner photo, the name/booth-number relocates
                          // off the image into plain page content here, but
                          // per the exhibitor's explicit choice still uses
                          // the customizable Name Text color (headerTextColor)
                          // rather than switching to a fixed dark color.
                          if (ex.hasBanner)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ex.name.isEmpty ? 'Your Booth Name' : ex.name,
                                    style: TextStyle(
                                        color: ex.headerTextColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  if (ex.boothNumber.isNotEmpty ||
                                      ex.category.isNotEmpty)
                                    Text(
                                        [
                                          if (ex.boothNumber.isNotEmpty)
                                            'Booth ${ex.boothNumber}',
                                          ex.category,
                                        ].join(' · '),
                                        style: TextStyle(
                                            color: ex.headerTextColor
                                                .withOpacity(0.7),
                                            fontSize: 13)),
                                ],
                              ),
                            ),
                          if (ex.welcomeMessage.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: color.withOpacity(0.25)),
                              ),
                              child: Text(ex.welcomeMessage,
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic)),
                            ),
                          if (ex.description.isNotEmpty) ...[
                            Text(ex.description,
                                style: const TextStyle(
                                    color: AppColors.textMedium)),
                            const SizedBox(height: 14),
                          ],
                          if (ex.tags.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: ex.tags
                                  .map((t) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(t,
                                            style: TextStyle(
                                                color: color,
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ))
                                  .toList(),
                            ),
                          if (ex.contactEmail.isNotEmpty ||
                              ex.contactPhone.isNotEmpty ||
                              ex.website.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: color.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Contact',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: color)),
                                    const SizedBox(height: 8),
                                    if (ex.contactEmail.isNotEmpty)
                                      _ContactRow(Icons.email_outlined,
                                          ex.contactEmail),
                                    if (ex.contactPhone.isNotEmpty)
                                      _ContactRow(Icons.phone_outlined,
                                          ex.contactPhone),
                                    if (ex.website.isNotEmpty)
                                      _ContactRow(Icons.language_outlined,
                                          ex.website),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Games, quizzes and other interactive sections '
                              "aren't shown in preview — this is just the "
                              'look visitors will see.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMedium
                                      .withOpacity(0.8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed strip pinned above the scrollable preview so it's never mistaken
/// for the real, live booth page — and doubles as the way back to editing.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Close preview',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.visibility_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Preview — how visitors will see your booth',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700),
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

/// The banner/logo/name header, styled the same way as the real
/// BoothScreen's SliverAppBar hero — just laid out as a plain, static
/// (non-collapsing) block since there's nothing below it to scroll a
/// pinned app bar over.
class _Hero extends StatelessWidget {
  const _Hero({required this.ex, required this.color});
  final ExhibitorModel ex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        image: ex.hasBanner
            ? DecorationImage(
                image: CachedNetworkImageProvider(ex.bannerImageUrl),
                fit: BoxFit.cover,
              )
            : null,
        gradient: ex.hasBanner
            ? null
            : LinearGradient(
                colors: [color, ex.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: ex.logoUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: ex.logoUrl, fit: BoxFit.cover)
                : Icon(Icons.store_rounded, color: color, size: 30),
          ),
          // Once there's a real banner photo, the name/booth-number moves
          // down into plain page content instead (see the block just below
          // this hero) — only the logo stays overlapping the banner.
          if (!ex.hasBanner) ...[
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex.name.isEmpty ? 'Your Booth Name' : ex.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: ex.headerTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                  ),
                  if (ex.boothNumber.isNotEmpty || ex.category.isNotEmpty)
                    Text(
                      [
                        if (ex.boothNumber.isNotEmpty) 'Booth ${ex.boothNumber}',
                        ex.category,
                      ].join(' · '),
                      style: TextStyle(
                          color: ex.headerTextColor.withOpacity(0.7),
                          fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.textMedium),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMedium))),
        ]),
      );
}
