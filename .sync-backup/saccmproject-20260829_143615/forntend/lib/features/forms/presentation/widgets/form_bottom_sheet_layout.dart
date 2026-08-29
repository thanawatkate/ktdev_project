import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/widgets/widgets.dart';

class FormBottomSheetLayout extends StatelessWidget {
  const FormBottomSheetLayout({
    super.key,
    required this.title,
    required this.icon,
    required this.sectionTitle,
    required this.children,
    required this.onSubmit,
    this.validateBeforeSubmit,
    this.submitLabel = TransactionUiText.formsPrintPdfAction,
  });

  final String title;
  final IconData icon;
  final String sectionTitle;
  final List<Widget> children;
  final VoidCallback onSubmit;
  final String? Function()? validateBeforeSubmit;
  final String submitLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TransactionFormHeader(
                icon: icon,
                iconColor: accent,
                iconBgColor: c.iconBgIncome,
                title: title,
                subtitle: TransactionUiText.reviewBeforeSave,
                quickHint: TransactionUiText.formsQuickHint,
                hintAccentColor: accent,
                hintBorderColor: c.cardBorder,
                textPrimaryColor: c.textPrimary,
              ),
              const SizedBox(height: AppTheme.sp12),
              Container(
                decoration: BoxDecoration(
                  color: c.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.r16),
                  border: Border.all(color: c.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.sp16,
                        AppTheme.sp16,
                        AppTheme.sp16,
                        AppTheme.sp12,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.description_outlined,
                              size: 16, color: accent),
                          const SizedBox(width: AppTheme.sp8),
                          Text(
                            sectionTitle,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              fontFamily: 'Kanit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: c.cardBorder),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.sp16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            children[i],
                            if (i < children.length - 1)
                              const SizedBox(height: AppTheme.sp12),
                          ],
                        ],
                      ),
                    ),
                    Divider(height: 1, color: c.cardBorder),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.sp12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(TransactionUiText.cancel),
                          ),
                          const SizedBox(width: AppTheme.sp8),
                          AppButton.primary(
                            fullWidth: false,
                            label: submitLabel,
                            icon: const Icon(Icons.print_outlined, size: 18),
                            onPressed: () {
                              final error = validateBeforeSubmit?.call();
                              if (error != null && error.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error)),
                                );
                                return;
                              }
                              onSubmit();
                            },
                          ),
                        ],
                      ),
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
