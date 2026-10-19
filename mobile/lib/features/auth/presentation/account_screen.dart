import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/design.dart';
import '../../../core/localization/tr.dart';
import '../../../core/network/api_exception.dart';
import 'auth_providers.dart';

/// Sign in / create account / sign out. Optional: reading, bookmarks and
/// progress all work without it, and nothing is synced to the account yet.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _messageFor(ApiException e) {
    if (e.message == ApiException.offline) {
      return context.tr(
          'تعذّر الاتصال بالخادم. تحقق من الإنترنت وأعد المحاولة.',
          'Could not reach the server. Check your internet and try again.');
    }
    if (e.message == ApiException.generic) {
      return context.tr('حدث خطأ. أعد المحاولة بعد قليل.',
          'Something went wrong. Try again in a moment.');
    }
    return e.message;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    try {
      if (_registering) {
        await auth.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.login(email: _email.text.trim(), password: _password.text);
      }
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = _messageFor(const ApiException(ApiException.generic)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final title = user != null
        ? context.tr('الحساب', 'Account')
        : _registering
            ? context.tr('إنشاء حساب', 'Create account')
            : context.tr('تسجيل الدخول', 'Sign in');

    return AppScaffold(
      title: title,
      // Opened without history (deep link): offer a way home instead of the
      // system back chevron.
      leading: context.canPop()
          ? null
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.go('/home'),
              child: Text(
                context.tr('الرئيسية', 'Home'),
                style:
                    AppTypography.body.copyWith(color: context.palette.accent),
              ),
            ),
      // No explicit padding: the list then insets itself by the translucent
      // nav bar and home indicator (MediaQuery padding) and scrolls under them.
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const SizedBox(height: AppSpacing.md),
          ...user != null ? _signedIn(context, user) : _form(context),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  List<Widget> _signedIn(BuildContext context, AuthUser user) {
    final c = context.palette;
    return [
      AppListSection(
        footer: context.tr(
          'أنت مسجّل الدخول. مزامنة العلامات والتقدّم بين الأجهزة ستُضاف قريبًا؛ حتى ذلك الحين تبقى بياناتك على هذا الجهاز.',
          'You are signed in. Syncing bookmarks and progress across devices is coming; until then your data stays on this device.',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(CupertinoIcons.person_crop_circle_fill,
                    size: 56, color: c.accent),
                const SizedBox(width: AppSpacing.ms),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: AppTypography.title3.copyWith(color: c.label)),
                      LtrText(
                        user.email,
                        style: AppTypography.subheadline
                            .copyWith(color: c.secondaryLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      AppListSection(
        children: [
          AppListTile(
            title: context.tr('تسجيل الخروج', 'Sign out'),
            destructive: true,
            chevron: false,
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _form(BuildContext context) {
    final c = context.palette;
    return [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin + AppSpacing.xs,
          0,
          AppSpacing.screenMargin + AppSpacing.xs,
          AppSpacing.md,
        ),
        child: Text(
          context.tr('الحساب اختياري. يمكنك القراءة وحفظ العلامات بدونه.',
              'An account is optional. You can read and bookmark without one.'),
          style: AppTypography.subheadline.copyWith(color: c.secondaryLabel),
        ),
      ),
      AutofillGroup(
        child: Form(
          key: _formKey,
          child: AppListSection(
            children: [
              if (_registering)
                AppTextFormRow(
                  controller: _name,
                  placeholder: context.tr('الاسم', 'Name'),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.tr('أدخل اسمك', 'Enter your name')
                      : null,
                ),
              AppTextFormRow(
                controller: _email,
                placeholder: context.tr('البريد الإلكتروني', 'Email'),
                ltr: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch((v ?? '').trim())
                    ? null
                    : context.tr(
                        'أدخل بريدًا إلكترونيًا صحيحًا', 'Enter a valid email'),
              ),
              AppTextFormRow(
                controller: _password,
                placeholder: context.tr('كلمة المرور', 'Password'),
                ltr: true,
                obscureText: _hidePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                autofillHints: [
                  _registering
                      ? AutofillHints.newPassword
                      : AutofillHints.password
                ],
                suffix: AppIconButton(
                  icon: _hidePassword
                      ? CupertinoIcons.eye
                      : CupertinoIcons.eye_slash,
                  color: c.secondaryLabel,
                  label: _hidePassword
                      ? context.tr('إظهار كلمة المرور', 'Show password')
                      : context.tr('إخفاء كلمة المرور', 'Hide password'),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) {
                    return context.tr(
                        'أدخل كلمة المرور', 'Enter your password');
                  }
                  if (_registering && value.length < 8) {
                    return context.tr(
                        '٨ أحرف على الأقل', 'At least 8 characters');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenMargin + AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.screenMargin + AppSpacing.xs,
            0,
          ),
          child: Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.exclamationmark_circle_fill,
                    size: 16, color: c.destructive),
                const SizedBox(width: AppSpacing.xs + 2),
                Expanded(
                  child: Text(
                    _error!,
                    style:
                        AppTypography.footnote.copyWith(color: c.destructive),
                  ),
                ),
              ],
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.screenMargin,
          AppSpacing.lg,
          AppSpacing.screenMargin,
          0,
        ),
        child: Column(
          children: [
            AppButton.filled(
              label: _registering
                  ? context.tr('إنشاء الحساب', 'Create account')
                  : context.tr('دخول', 'Sign in'),
              loading: _busy,
              expand: true,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.plain(
              label: _registering
                  ? context.tr('لدي حساب بالفعل', 'I already have an account')
                  : context.tr('ليس لدي حساب', 'Create a new account'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _registering = !_registering;
                        _error = null;
                      }),
            ),
          ],
        ),
      ),
    ];
  }
}
