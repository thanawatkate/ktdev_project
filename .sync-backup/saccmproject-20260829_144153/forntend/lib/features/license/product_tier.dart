/// แพ็กเกจการขาย SACCM
enum ProductTier {
  /// ทดลองใช้ฝังในแอป — จำนวนวันกำหนดใน config.dart ไม่ผ่าน Registry
  trial,

  /// ซื้อแล้วลงทะเบียน — ใช้ offline บนเครื่อง (รหัสจาก Registry)
  offline,

  /// ซื้อแล้วลงทะเบียน — offline + ซิงก์ server กลาง
  online,
}

extension ProductTierX on ProductTier {
  static ProductTier? fromRegistryKind(String? kind) {
    switch (kind) {
      case 'online':
      case 'standard':
        return ProductTier.online;
      case 'offline':
        return ProductTier.offline;
      default:
        return null;
    }
  }

  String get storageKey => name;

  static ProductTier? fromStorage(String? key) {
    switch (key) {
      case 'offline':
        return ProductTier.offline;
      case 'online':
        return ProductTier.online;
      default:
        return null;
    }
  }

  bool get isLicensed => this == ProductTier.offline || this == ProductTier.online;

  bool get canSyncOnline => this == ProductTier.online;
}
