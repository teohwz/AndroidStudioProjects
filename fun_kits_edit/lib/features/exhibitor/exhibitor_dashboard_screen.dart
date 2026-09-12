import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/models/exhibitor_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/mask_name.dart';
import '../../shared/widgets/dashboard_tab_bar.dart';
import '../../shared/widgets/dense_menu_row.dart';
import '../admin/manage_lucky_draw_screen.dart';
import '../admin/manage_quiz_screen.dart';
import '../auth/role_choice_screen.dart';
import 'exhibitor_analytics_screen.dart';
import 'exhibitor_booth_editor_screen.dart';
import 'exhibitor_game_config_screen.dart';
import 'exhibitor_prize_wins_screen.dart';
import 'exhibitor_qr_screen.dart';

/// Hub screen for an exhibitor's own booth. Everything reachable from here
/// is scoped to `AuthService.myBoothId` — there is no way to open another
/// exhibitor's booth from this UI, and firestore.rules refuses it server-side
/// regardless (see ExhibitorGuard in routes.dart for the route-level guard).
///
/// Laid out as a "quiet style" bottom tab bar with 5 icons, only 2 of which
/// are real persistent tabs — Overview and Manage — that swap this screen's
/// body content in place (see [_tabIndex]/[IndexedStack] below). The other
/// 3 (Analytics, QR Code, Prize Wins) are shortcut icons that just push
/// their existing standalone screens unchanged, same as tapping a menu item
/// used to; see [DashboardTabItem.isRealTab] for why that split exists.
class ExhibitorDashboardScreen extends StatefulWidget {
  const ExhibitorDashboardScreen({super.key});

  @override
  State<ExhibitorDashboardScreen> createState() =>
      _ExhibitorDashboardScreenState();
}

class _ExhibitorDashboardScreenState extends State<ExhibitorDashboardScreen> {
  // Only 2 of the bar's 5 icons are real tabs (index 0 = Overview, 1 =
  // Manage) — this index only ever holds 0 or 1, since the other 3 icons
  // push a screen instead of changing which body is shown.
  int _tabIndex = 0;

  void _onNavTap(int index, String boothId) {
    switch (index) {
      case 0:
      case 1:
        setState(() => _tabIndex = index);
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ExhibitorAnalyticsScreen(boothId: boothId)),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ExhibitorQrScreen(boothId: boothId)),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ExhibitorPrizeWinsScreen(boothId: boothId)),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final boothId = auth.myBoothId;
    final fs = FirestoreService();
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    if (boothId == null || boothId.isEmpty) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No booth is linked to this account yet. Contact the '
                'event organiser.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMedium),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_tabIndex == 0)
              _OverviewHeader(fs: fs, boothId: boothId)
            else
              const _PlainHeader(
                title: 'Manage',
                subtitle: 'One-time setup, edit anytime',
              ),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _OverviewBody(fs: fs, boothId: boothId),
                  _ManageBody(boothId: boothId),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DashboardTabBar(
        currentIndex: _tabIndex,
        items: const [
          DashboardTabItem(icon: Icons.grid_view_rounded),
          DashboardTabItem(icon: Icons.tune_rounded),
          DashboardTabItem(
              icon: Icons.bar_chart_rounded, isRealTab: false),
          DashboardTabItem(icon: Icons.qr_code_rounded, isRealTab: false),
          DashboardTabItem(
              icon: Icons.card_giftcard_rounded, isRealTab: false),
        ],
        onTap: (i) => _onNavTap(i, boothId),
      ),
    );
  }
}

/// Plain white header shared by every non-Overview tab — just a title and
/// subtitle, no account menu (see this screen's doc comment / the confirmed
/// requirement: the 3-dot menu lives only on Overview).
class _PlainHeader extends StatelessWidget {
  const _PlainHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: palette.textDark)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 11.5, color: palette.textMedium)),
        ],
      ),
    );
  }
}

/// Overview's header — booth name/number instead of a fixed title, plus the
/// account menu (Switch Role/Logout), same items as the old AppBar's
/// overflow menu, just restyled into this plain header row.
class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.fs, required this.boothId});
  final FirestoreService fs;
  final String boothId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return StreamBuilder<ExhibitorModel?>(
      stream: fs.watchExhibitor(boothId),
      builder: (context, snap) {
        final booth = snap.data;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booth?.name.isNotEmpty == true
                          ? booth!.name
                          : 'Set up your booth',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: palette.textDark),
                    ),
                    const SizedBox(height: 2),
                    Text('Booth #${booth?.boothNumber ?? '—'}',
                        style:
                            TextStyle(fontSize: 11.5, color: palette.textMedium)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: palette.textMedium),
                onSelected: (v) async {
                  if (v == 'logout') {
                    await context.read<AuthService>().logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  } else if (v == 'switch_role') {
                    // An exhibitor switching roles can only be switching TO
                    // Visitor — hide the Exhibitor card on the screen they
                    // land on (see RoleChoiceScreen.hideRole). The actual
                    // logout-and-confirm happens when they tap the Visitor
                    // card there, not here.
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            const RoleChoiceScreen(hideRole: 'exhibitor')));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'switch_role', child: Text('Switch Role')),
                  const PopupMenuItem(value: 'logout', child: Text('Logout')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Overview tab body — the stat row, plus (added after the initial "quiet
/// style" restyle) a setup-progress nudge, a share-your-booth prompt, and a
/// recent-activity feed, so this tab reads as an active hub rather than 3
/// bare numbers. The 7 action items that used to live below the stats here
/// pre-restyle have all moved out to their own tabs (4 into Manage, 3
/// promoted to their own shortcut icons) — unrelated to this addition.
class _OverviewBody extends StatefulWidget {
  const _OverviewBody({required this.fs, required this.boothId});
  final FirestoreService fs;
  final String boothId;

  @override
  State<_OverviewBody> createState() => _OverviewBodyState();
}

class _OverviewBodyState extends State<_OverviewBody> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ExhibitorModel?>(
      stream: widget.fs.watchExhibitor(widget.boothId),
      builder: (context, boothSnap) {
        final booth = boothSnap.data;
        return RefreshIndicator(
          // The sections below each fetch their own one-shot Future in
          // their own build() — a plain setState here recreates each of
          // those widgets with a fresh Future, which is what actually
          // re-fetches on pull-to-refresh (the previous no-op placeholder
          // is replaced now that there's real data worth refreshing).
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (booth != null) ...[
                _SetupChecklistCard(
                    fs: widget.fs, boothId: widget.boothId, booth: booth),
                const SizedBox(height: 16),
              ],
              _StatsRow(fs: widget.fs, boothId: widget.boothId),
              const SizedBox(height: 16),
              _ShareBoothCard(boothId: widget.boothId),
              const SizedBox(height: 16),
              _RecentActivityCard(fs: widget.fs, boothId: widget.boothId),
            ],
          ),
        );
      },
    );
  }
}

/// Setup-progress nudge — shown only while at least one of the 4 tracked
/// items is incomplete; disappears entirely once every item is done. Each
/// incomplete row is tappable and jumps straight to where it's fixed.
/// "Set up a prize game" deliberately checks the 4 prize games (Spin Wheel/
/// Scratch Card/Guess the Number/Memory Cards), not the 6 generic games —
/// those are enabled by default and would make this item read as
/// already-done for every booth, defeating the point of the nudge.
class _SetupChecklistCard extends StatelessWidget {
  const _SetupChecklistCard(
      {required this.fs, required this.boothId, required this.booth});
  final FirestoreService fs;
  final String boothId;
  final ExhibitorModel booth;

  @override
  Widget build(BuildContext context) {
    final hasContact = booth.contactEmail.isNotEmpty ||
        booth.contactPhone.isNotEmpty ||
        booth.website.isNotEmpty;
    final hasWelcome = booth.welcomeMessage.isNotEmpty;

    return FutureBuilder<bool>(
      future: fs.hasAnyPrizeGameConfigured(boothId),
      builder: (context, snap) {
        // Wait for the async prize-game check before deciding whether to
        // show anything at all — avoids a flash of "incomplete" that then
        // immediately disappears once the check resolves true.
        if (!snap.hasData) return const SizedBox.shrink();

        final items = <_ChecklistItemData>[
          _ChecklistItemData(
            label: 'Add a logo',
            done: booth.hasLogo,
            onTap: () => _openBoothEditor(context),
          ),
          _ChecklistItemData(
            label: 'Write a welcome message',
            done: hasWelcome,
            onTap: () => _openBoothEditor(context),
          ),
          _ChecklistItemData(
            label: 'Add contact info',
            done: hasContact,
            onTap: () => _openBoothEditor(context),
          ),
          _ChecklistItemData(
            label: 'Set up a prize game',
            done: snap.data!,
            onTap: () => _openGameSettings(context),
          ),
        ];
        final doneCount = items.where((i) => i.done).length;
        if (doneCount == items.length) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final palette = theme.extension<AppPalette>()!;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Finish setting up your booth',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: palette.textDark)),
                  ),
                  Text('$doneCount/${items.length}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: doneCount / items.length,
                  minHeight: 6,
                  backgroundColor:
                      theme.colorScheme.outlineVariant.withOpacity(0.3),
                  valueColor:
                      AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 8),
              for (final item in items.where((i) => !i.done))
                InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.radio_button_unchecked,
                            size: 16,
                            color: palette.textMedium.withOpacity(0.6)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item.label,
                              style: TextStyle(
                                  fontSize: 12.5, color: palette.textDark)),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 16,
                            color: palette.textMedium.withOpacity(0.7)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openBoothEditor(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ExhibitorBoothEditorScreen(boothId: boothId)));

  void _openGameSettings(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ExhibitorGameConfigScreen(boothId: boothId)));
}

class _ChecklistItemData {
  const _ChecklistItemData(
      {required this.label, required this.done, required this.onTap});
  final String label;
  final bool done;
  final VoidCallback onTap;
}

/// "Get visitors scanning" nudge — a lightweight card that opens the
/// existing My QR Code screen rather than duplicating its QR-rendering/
/// share logic here (confirmed choice — see this round's requirement doc).
class _ShareBoothCard extends StatelessWidget {
  const _ShareBoothCard({required this.boothId});
  final String boothId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ExhibitorQrScreen(boothId: boothId)),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.qr_code_rounded,
                    color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Share your booth',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: palette.textDark)),
                    const SizedBox(height: 2),
                    Text('Get your QR code so visitors can scan in',
                        style: TextStyle(
                            fontSize: 11.5, color: palette.textMedium)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: palette.textMedium.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "What's happening" feed — merged from check-ins, game plays, and prize
/// wins. See [FirestoreService.getRecentBoothActivity] for the merge logic
/// and its no-PII note; winner names here are masked at display time (see
/// [maskWinnerName]), same convention as everywhere else a winner is shown
/// to anyone other than the exhibitor themselves handling a hand-out.
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.fs, required this.boothId});
  final FirestoreService fs;
  final String boothId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return FutureBuilder<List<BoothActivityEvent>>(
      future: fs.getRecentBoothActivity(boothId),
      builder: (context, snap) {
        final events = snap.data ?? const [];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent Activity',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: palette.textDark)),
              const SizedBox(height: 10),
              if (snap.connectionState == ConnectionState.waiting)
                Text('Loading…',
                    style: TextStyle(fontSize: 12, color: palette.textMedium))
              else if (events.isEmpty)
                Text(
                    'Nothing yet — activity will show up here once visitors '
                    'start checking in and playing.',
                    style: TextStyle(fontSize: 12, color: palette.textMedium))
              else
                for (final event in events) _ActivityRow(event: event),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event});
  final BoothActivityEvent event;

  IconData _icon() {
    if (event.type == BoothActivityType.checkIn) return Icons.how_to_reg_rounded;
    if (event.type == BoothActivityType.play) return Icons.sports_esports_rounded;
    return Icons.emoji_events_rounded;
  }

  Color _color(AppPalette palette, ColorScheme scheme) {
    if (event.type == BoothActivityType.checkIn) return palette.success;
    if (event.type == BoothActivityType.play) return scheme.primary;
    return palette.gold;
  }

  String _text() {
    if (event.type == BoothActivityType.win) {
      return '${maskWinnerName(event.rawWinnerName)} won '
          '${event.prizeLabel ?? 'a prize'}';
    }
    return event.text;
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final color = _color(palette, theme.colorScheme);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon(), size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_text(),
                style: TextStyle(fontSize: 12, color: palette.textDark)),
          ),
          const SizedBox(width: 6),
          Text(_relativeTime(event.time),
              style: TextStyle(fontSize: 10.5, color: palette.textMedium)),
        ],
      ),
    );
  }
}

/// Manage tab body — the 4 "one-time setup" actions as a dense list,
/// exactly as they were content-wise, just restyled and moved out of the
/// old 2-column grid.
class _ManageBody extends StatelessWidget {
  const _ManageBody({required this.boothId});
  final String boothId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        DenseMenuRow(
          icon: Icons.palette_rounded,
          title: 'Customize Booth',
          subtitle: 'Name, logo, colors, message',
          color: theme.colorScheme.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExhibitorBoothEditorScreen(boothId: boothId),
            ),
          ),
        ),
        DenseMenuRow(
          icon: Icons.videogame_asset_rounded,
          title: 'Game Settings',
          subtitle: 'Enable games & set points',
          color: palette.puzzleColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExhibitorGameConfigScreen(boothId: boothId),
            ),
          ),
        ),
        DenseMenuRow(
          icon: Icons.quiz_rounded,
          title: 'My Quizzes',
          subtitle: 'Create & edit quizzes',
          color: palette.quizColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManageQuizScreen(boothId: boothId),
            ),
          ),
        ),
        DenseMenuRow(
          icon: Icons.casino_rounded,
          title: 'My Lucky Draws',
          subtitle: 'Create & run draws',
          color: palette.luckyDrawColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManageLuckyDrawScreen(boothId: boothId),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.fs, required this.boothId});
  final FirestoreService fs;
  final String boothId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return FutureBuilder<List<Map<String, int>>>(
      // Totals + today's counts fetched together so the tile only ever
      // shows both numbers at once, never a stale total next to a
      // still-loading trend.
      future: Future.wait(
          [fs.getBoothStats(boothId), fs.getBoothStatsToday(boothId)]),
      builder: (context, snap) {
        final stats = snap.data != null ? snap.data![0] : const <String, int>{};
        final today = snap.data != null ? snap.data![1] : const <String, int>{};
        return Row(
          children: [
            _StatTile(
                label: 'Check-ins',
                value: stats['checkIns'] ?? 0,
                today: today['checkIns'] ?? 0,
                color: palette.success),
            const SizedBox(width: 8),
            _StatTile(
                label: 'Plays',
                value: stats['totalPlays'] ?? 0,
                today: today['totalPlays'] ?? 0,
                color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            _StatTile(
                label: 'Points Given',
                value: stats['pointsDistributed'] ?? 0,
                today: today['pointsDistributed'] ?? 0,
                color: palette.gold),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    this.today = 0,
  });
  final String label;
  final int value;
  final Color color;
  final int today;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 1),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color:
                        Theme.of(context).extension<AppPalette>()!.textMedium)),
            if (today > 0) ...[
              const SizedBox(height: 2),
              Text('+$today today',
                  style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: color.withOpacity(0.85))),
            ],
          ],
        ),
      ),
    );
  }
}
