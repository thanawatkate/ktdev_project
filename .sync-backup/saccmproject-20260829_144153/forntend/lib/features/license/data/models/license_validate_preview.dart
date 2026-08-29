import 'package:saccm/features/license/product_tier.dart';

class LicenseValidatePreview {
  final String schoolName;
  final ProductTier? productTier;
  final bool expired;

  const LicenseValidatePreview({
    required this.schoolName,
    this.productTier,
    this.expired = false,
  });
}
