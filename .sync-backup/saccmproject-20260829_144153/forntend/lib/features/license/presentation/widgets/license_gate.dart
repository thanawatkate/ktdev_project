import 'dart:async';

import 'package:flutter/material.dart';
import 'package:saccm/config.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/license/embedded_trial_license.dart';
import 'package:saccm/features/license/license_mode.dart';
import 'package:saccm/features/license/product_tier.dart';
import 'package:saccm/features/license/presentation/pages/license_activation_page.dart';
import 'package:saccm/features/license/presentation/pages/product_plan_page.dart';
import 'package:saccm/widgets/widgets.dart';

/// บล็อกเมื่อหมดทดลองใช้หรือใบอนุญาตหมดอายุ
class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key, required this.child});

  final Widget child;

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  bool _checking = true;
  LicenseSnapshot? _snap;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    LicenseSnapshot? snap;
    try {
      await EmbeddedTrialLicense.ensureStarted();
      snap = await LicenseMode.snapshot();
    } catch (_) {
      // ออฟไลน์/secure storage ล้มเหลว — ยังให้ใช้โหมดทดลองบนเครื่องได้
      try {
        snap = await LicenseMode.snapshot();
      } catch (_) {
        try {
          final trial = await EmbeddedTrialLicense.status();
          snap = LicenseSnapshot(tier: ProductTier.trial, trial: trial);
        } catch (_) {
          snap = null;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _checking = false;
      _snap = snap ?? _fallbackTrialSnapshot();
    });
    unawaited(_revalidateInBackground());
  }

  Future<void> _revalidateInBackground() async {
    await LicenseMode.revalidateLicensedOnlineIfPossible();
    // Tier B: anchor วันทดลองใช้กับ Registry เมื่อยังอยู่โหมดทดลอง
    if (!await LicenseMode.isLicensed()) {
      await EmbeddedTrialLicense.syncServerAnchorIfPossible();
    }
    final snap = await LicenseMode.snapshot();
    if (!mounted) return;
    setState(() => _snap = snap);
  }

  /// สำรองเมื่ออ่าน secure storage ไม่ได้ — ยังเปิดแอปโหมดทดลองได้
  LicenseSnapshot _fallbackTrialSnapshot() {
    final now = DateTime.now();
    return LicenseSnapshot(
      tier: ProductTier.trial,
      trial: EmbeddedTrialStatus(
        startedAt: now,
        expiresAt: now.add(const Duration(days: kEmbeddedTrialDays)),
        daysTotal: kEmbeddedTrialDays,
        daysRemaining: kEmbeddedTrialDays,
        expired: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Material(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final snap = _snap!;
    if (!snap.canUseApp) {
      return _AccessBlockedScreen(snap: snap, onRefresh: _refresh);
    }
    return widget.child;
  }
}

class _AccessBlockedScreen extends StatelessWidget {
  const _AccessBlockedScreen({
    required this.snap,
    required this.onRefresh,
  });

  final LicenseSnapshot snap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isLicense = snap.isLicenseExpired;

    return Material(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLicense
                        ? Icons.vpn_key_off_outlined
                        : Icons.timer_off_outlined,
                    size: 64,
                    color: c.textSecondary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isLicense
                        ? TransactionUiText.licenseExpiredBlockedTitle
                        : TransactionUiText.embeddedTrialExpiredTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isLicense
                        ? TransactionUiText.licenseExpiredBlockedMessage
                        : TransactionUiText.embeddedTrialExpiredMessage(
                            kEmbeddedTrialDays,
                          ),
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontFamily: 'Kanit', color: c.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  AppButton.primary(
                    label: TransactionUiText.productPlanTitle,
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProductPlanPage(),
                        ),
                      );
                      onRefresh();
                    },
                  ),
                  const SizedBox(height: 12),
                  AppButton.secondary(
                    label: TransactionUiText.licenseActivateOptionalTitle,
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LicenseActivationPage(),
                        ),
                      );
                      onRefresh();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
