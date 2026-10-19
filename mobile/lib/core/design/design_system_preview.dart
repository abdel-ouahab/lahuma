import 'package:flutter/material.dart' show Theme;
import 'app_theme.dart';
import 'design.dart';

/// Debug-only catalogue of every design-system component. Toggle light /
/// dark and Arabic (RTL) / English (LTR) locally to check each combination.
/// Reached through the debug route `/__design` (not linked from the app).
class DesignSystemPreview extends StatefulWidget {
  const DesignSystemPreview({super.key});

  @override
  State<DesignSystemPreview> createState() => _DesignSystemPreviewState();
}

class _DesignSystemPreviewState extends State<DesignSystemPreview> {
  Brightness? _brightness;
  bool _arabic = true;
  bool _switch = true;
  int _segment = 0;
  bool _loading = false;
  String _picked = 'Al-Fatiha';
  DateTime _date = DateTime(2026, 1, 1);

  @override
  Widget build(BuildContext context) {
    final brightness = _brightness ?? CupertinoTheme.brightnessOf(context);
    return Theme(
      data: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      child: Localizations.override(
        context: context,
        locale: Locale(_arabic ? 'ar' : 'en'),
        child: Builder(
          builder: (context) =>
              AppTheme.builder(context, _body(context, brightness)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Brightness brightness) {
    final c = context.palette;
    TextStyle swatchLabel =
        AppTypography.caption1.copyWith(color: c.secondaryLabel);

    return AppScaffold.largeTitle(
      title: 'Design System',
      bottom: AppNavBarBottom(
        child: Row(
          children: [
            Expanded(
              child: AppSegmentedControl<Brightness>(
                segments: const {
                  Brightness.light: 'Light',
                  Brightness.dark: 'Dark'
                },
                value: brightness,
                onChanged: (v) => setState(() => _brightness = v),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppSegmentedControl<bool>(
                segments: const {true: 'عربي RTL', false: 'English LTR'},
                value: _arabic,
                onChanged: (v) => setState(() => _arabic = v),
              ),
            ),
          ],
        ),
      ),
      onRefresh: () => Future<void>.delayed(const Duration(seconds: 1)),
      slivers: [
        _section('Typography', [
          for (final (name, style) in [
            ('Large Title 34', AppTypography.largeTitle),
            ('Title 1 28', AppTypography.title1),
            ('Title 2 22', AppTypography.title2),
            ('Title 3 20', AppTypography.title3),
            ('Headline 17', AppTypography.headline),
            ('Body 17', AppTypography.body),
            ('Callout 16', AppTypography.callout),
            ('Subheadline 15', AppTypography.subheadline),
            ('Footnote 13', AppTypography.footnote),
            ('Caption 12', AppTypography.caption1),
          ])
            Text('$name · بسم الله', style: style.copyWith(color: c.label)),
          Text(
            'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            style: AppTypography.quran().copyWith(color: c.label),
          ),
        ]),
        _section('Colours', [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (name, color) in [
                ('accent', AppColors.accent),
                ('accentTint', AppColors.accentTint),
                ('label', AppColors.label),
                ('secondaryLabel', AppColors.secondaryLabel),
                ('separator', AppColors.separator),
                ('fill', AppColors.fill),
                ('grouped', AppColors.groupedBackground),
                ('secondaryGrouped', AppColors.secondaryGroupedBackground),
                ('destructive', AppColors.destructive),
                ('success', AppColors.success),
                ('warning', AppColors.warning),
              ])
                SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 40,
                        decoration: ShapeDecoration(
                          color: c.resolve(color),
                          shape: AppRadius.continuous(
                            AppRadius.small,
                            side: BorderSide(color: c.separator),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(name, style: swatchLabel),
                    ],
                  ),
                ),
            ],
          ),
        ]),
        _section('Buttons', [
          AppButton.filled(label: 'Filled', onPressed: () {}, expand: true),
          AppButton.tinted(
            label: 'Tinted',
            icon: CupertinoIcons.play_fill,
            onPressed: () {},
            expand: true,
          ),
          AppButton.plain(label: 'Plain', onPressed: () {}),
          AppButton.destructive(
              label: 'Destructive', onPressed: () {}, expand: true),
          AppButton.filled(
            label: 'Tap for loading',
            loading: _loading,
            expand: true,
            onPressed: () async {
              setState(() => _loading = true);
              await Future<void>.delayed(const Duration(seconds: 2));
              if (mounted) setState(() => _loading = false);
            },
          ),
          const AppButton.filled(
              label: 'Disabled', onPressed: null, expand: true),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              AppButton.tinted(label: 'Small', small: true, onPressed: () {}),
              AppIconButton(
                  icon: CupertinoIcons.share, label: 'Share', onPressed: () {}),
              AppIconButton(
                icon: CupertinoIcons.ellipsis,
                label: 'More',
                filled: true,
                onPressed: () {},
              ),
            ],
          ),
        ]),
        _section('Inputs', [
          const AppSearchField(),
          const AppTextField(placeholder: 'Text field'),
          const AppTextField(placeholder: 'name@example.com', ltr: true),
          AppSegmentedControl<int>(
            segments: const {0: 'السور', 1: 'الأجزاء', 2: 'القرّاء'},
            value: _segment,
            onChanged: (v) => setState(() => _segment = v),
          ),
        ]),
        SliverToBoxAdapter(
          child: AppListSection(
            header: 'List section',
            footer: 'Rows wrap under large text; chevrons mirror in RTL.',
            hasLeading: true,
            children: [
              AppListTile(
                title: 'Navigation row',
                leading: const AppIconTile(
                  icon: CupertinoIcons.book_fill,
                  color: AppColors.tileBlue,
                ),
                onTap: () {},
              ),
              AppListTile(
                title: 'Value row',
                value: 'Value',
                leading: const AppIconTile(
                  icon: CupertinoIcons.globe,
                  color: AppColors.tilePurple,
                ),
                onTap: () {},
              ),
              AppListTile(
                title: 'Switch row',
                subtitle: 'With a subtitle that explains the setting.',
                leading: const AppIconTile(
                  icon: CupertinoIcons.moon_fill,
                  color: AppColors.tileOrange,
                ),
                trailing: AppSwitch(
                  value: _switch,
                  onChanged: (v) => setState(() => _switch = v),
                ),
              ),
              AppListTile(
                title: 'Destructive row',
                destructive: true,
                leading: const AppIconTile(
                  icon: CupertinoIcons.trash,
                  color: AppColors.tileRed,
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(
          child: AppListSection(
            header: 'Form rows',
            children: [
              AppTextFormRow(placeholder: 'Name', prefixLabel: 'Name'),
              AppTextFormRow(
                  placeholder: 'name@example.com',
                  prefixLabel: 'Email',
                  ltr: true),
            ],
          ),
        ),
        _section('Cards and progress', [
          AppCard(
            onTap: () {},
            child:
                Text('Tappable card (spring press)', style: AppTypography.body),
          ),
          AppCard(
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: AppColors.heroGradient,
            ),
            child: Text(
              'Hero card',
              style: AppTypography.title2.copyWith(color: AppColors.onAccent),
            ),
          ),
          const AppProgressBar(value: 0.62),
          Row(
            children: [
              const AppDirectionalIcon(CupertinoIcons.chevron_forward),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: LtrText(
                  '12 / 20 · 62%',
                  style: AppTypography.body.copyWith(color: c.label),
                ),
              ),
            ],
          ),
        ]),
        _section('States', const [
          AppLoader(label: 'Loading…'),
          AppEmptyState(
            icon: CupertinoIcons.bookmark,
            title: 'Nothing here yet',
            message: 'Empty states explain what will appear and how.',
          ),
        ]),
        _section('Overlays', [
          AppButton.tinted(
            label: 'Alert',
            expand: true,
            onPressed: () => showAppDialog<bool>(
              context,
              title: 'Delete note?',
              message: 'This cannot be undone.',
              actions: const [
                AppDialogAction(label: 'Cancel', value: false),
                AppDialogAction(
                    label: 'Delete', value: true, isDestructive: true),
              ],
            ),
          ),
          AppButton.tinted(
            label: 'Text input alert',
            expand: true,
            onPressed: () =>
                showAppTextInputDialog(context, title: 'Note', maxLines: 4),
          ),
          AppButton.tinted(
            label: 'Action sheet',
            expand: true,
            onPressed: () => showAppActionSheet<int>(
              context,
              title: 'Ayah 255',
              actions: const [
                AppSheetAction(
                    label: 'Copy', value: 0, icon: CupertinoIcons.doc_on_doc),
                AppSheetAction(
                    label: 'Share', value: 1, icon: CupertinoIcons.share),
                AppSheetAction(
                  label: 'Delete',
                  value: 2,
                  icon: CupertinoIcons.trash,
                  isDestructive: true,
                ),
              ],
            ),
          ),
          AppButton.tinted(
            label: 'Page sheet',
            expand: true,
            onPressed: () => showAppSheet<void>(
              context,
              title: 'Tafsir',
              builder: (context, controller) => ListView(
                controller: controller,
                children: [
                  for (var i = 0; i < 30; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Text('Line ${i + 1}', style: AppTypography.body),
                    ),
                ],
              ),
            ),
          ),
          AppButton.tinted(
            label: 'Bottom sheet',
            expand: true,
            onPressed: () => showAppBottomSheet<void>(
              context,
              title: 'Daily goal',
              builder: (context) => const AppListSection(
                children: [
                  AppListTile(title: '5 ayahs'),
                  AppListTile(title: '10 ayahs'),
                ],
              ),
            ),
          ),
          AppButton.tinted(
            label: 'Picker: $_picked',
            expand: true,
            onPressed: () async {
              final v = await showAppPicker<String>(
                context,
                items: const ['Al-Fatiha', 'Al-Baqarah', 'Al-Imran'],
                selected: _picked,
                labelOf: (s) => s,
              );
              if (v != null) setState(() => _picked = v);
            },
          ),
          AppButton.tinted(
            label: 'Date: ${_date.year}-${_date.month}-${_date.day}',
            expand: true,
            onPressed: () async {
              final d = await showAppDatePicker(context, initial: _date);
              if (d != null) setState(() => _date = d);
            },
          ),
          AppButton.tinted(
            label: 'Toast with action',
            expand: true,
            onPressed: () => AppToast.show(
              context,
              'Bookmark removed',
              icon: CupertinoIcons.bookmark,
              actionLabel: 'Undo',
              onAction: () {},
            ),
          ),
        ]),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return SliverToBoxAdapter(
      child: Builder(
        builder: (context) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenMargin,
            AppSpacing.lg,
            AppSpacing.screenMargin,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    AppTypography.title3.copyWith(color: context.palette.label),
              ),
              const SizedBox(height: AppSpacing.ms),
              for (final child in children) ...[
                child,
                const SizedBox(height: AppSpacing.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
