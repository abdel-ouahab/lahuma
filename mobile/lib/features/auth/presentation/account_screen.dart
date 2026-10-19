import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/localization/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/lahuma_icon_button.dart';
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
      return context.tr('تعذّر الاتصال بالخادم. تحقق من الإنترنت وأعد المحاولة.',
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
        setState(() => _error = _messageFor(const ApiException(ApiException.generic)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? AppColors.textDark : AppColors.textLight;
    final subtext = isDark ? AppColors.subtextDark : AppColors.subtextLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: LahumaIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: context.tr('رجوع', 'Back'),
                onTap: () => context.canPop() ? context.pop() : context.go('/home'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (user != null) ..._signedIn(context, user, text, subtext)
            else ..._form(context, text, subtext),
          ],
        ),
      ),
    );
  }

  List<Widget> _signedIn(
      BuildContext context, AuthUser user, Color text, Color subtext) {
    return [
      Text(
        user.name,
        style: GoogleFonts.cairo(
            fontSize: 24, fontWeight: FontWeight.w700, color: text),
      ),
      Text(user.email,
          style: GoogleFonts.cairo(fontSize: 14, color: subtext)),
      const SizedBox(height: AppSpacing.lg),
      Text(
        context.tr(
          'أنت مسجّل الدخول. مزامنة العلامات والتقدّم بين الأجهزة ستُضاف قريبًا؛ حتى ذلك الحين تبقى بياناتك على هذا الجهاز.',
          'You are signed in. Syncing bookmarks and progress across devices is coming; until then your data stays on this device.',
        ),
        style: GoogleFonts.cairo(fontSize: 13, height: 1.7, color: subtext),
      ),
      const SizedBox(height: AppSpacing.lg),
      OutlinedButton.icon(
        onPressed: () async {
          await ref.read(authProvider.notifier).logout();
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(context.tr('تسجيل الخروج', 'Sign out')),
      ),
    ];
  }

  List<Widget> _form(BuildContext context, Color text, Color subtext) {
    return [
      Text(
        _registering
            ? context.tr('إنشاء حساب', 'Create account')
            : context.tr('تسجيل الدخول', 'Sign in'),
        style: GoogleFonts.cairo(
            fontSize: 24, fontWeight: FontWeight.w700, color: text),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        context.tr('الحساب اختياري. يمكنك القراءة وحفظ العلامات بدونه.',
            'An account is optional. You can read and bookmark without one.'),
        style: GoogleFonts.cairo(fontSize: 13, height: 1.6, color: subtext),
      ),
      const SizedBox(height: AppSpacing.lg),
      Form(
        key: _formKey,
        child: Column(
          children: [
            if (_registering) ...[
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(labelText: context.tr('الاسم', 'Name')),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.tr('أدخل اسمك', 'Enter your name')
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration:
                  InputDecoration(labelText: context.tr('البريد الإلكتروني', 'Email')),
              validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch((v ?? '').trim())
                  ? null
                  : context.tr('أدخل بريدًا إلكترونيًا صحيحًا', 'Enter a valid email'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              autofillHints: [
                _registering ? AutofillHints.newPassword : AutofillHints.password
              ],
              decoration: InputDecoration(
                labelText: context.tr('كلمة المرور', 'Password'),
                suffixIcon: IconButton(
                  tooltip: context.tr('إظهار كلمة المرور', 'Show password'),
                  icon: Icon(_hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: (v) {
                final value = v ?? '';
                if (value.isEmpty) {
                  return context.tr('أدخل كلمة المرور', 'Enter your password');
                }
                if (_registering && value.length < 8) {
                  return context.tr('٨ أحرف على الأقل', 'At least 8 characters');
                }
                return null;
              },
            ),
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.md),
        Text(_error!,
            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.error)),
      ],
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(_registering
                ? context.tr('إنشاء الحساب', 'Create account')
                : context.tr('دخول', 'Sign in')),
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                  _registering = !_registering;
                  _error = null;
                }),
        child: Text(_registering
            ? context.tr('لدي حساب بالفعل', 'I already have an account')
            : context.tr('ليس لدي حساب', 'Create a new account')),
      ),
    ];
  }
}
