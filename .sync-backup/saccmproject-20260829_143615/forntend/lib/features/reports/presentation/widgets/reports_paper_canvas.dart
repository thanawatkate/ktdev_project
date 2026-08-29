import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

/// แผ่นเนื้อหารายงาน — พื้นโต๊ะ + แผ่นกระดาษลอยกลางจอ
///
/// ใช้ห่อ [TabBarView] ของเมนูรายงาน เพื่อให้ตาราง/ตัวเลขอ่านเหมือนเอกสารพิมพ์
/// ต้องส่งความสูงเต็มพื้นที่ให้ลูก (TabBarView) เสมอ — ห้ามใช้ Align อย่างเดียว
class ReportsPaperCanvas extends StatelessWidget {
  const ReportsPaperCanvas({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return ColoredBox(
      color: c.reportDesk,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          // TabBarView ต้องได้ความสูงจำกัด — ถ้า parent ไม่จำกัด ให้ขยายตามที่เหลือไม่ได้
          assert(
            maxH.isFinite,
            'ReportsPaperCanvas requires a bounded height (e.g. inside Expanded).',
          );
          final paperW = wide ? maxW.clamp(0.0, 1100.0) : maxW;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: paperW.isFinite ? paperW : null,
              height: maxH.isFinite ? maxH : null,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 20 : 10,
                  wide ? 12 : 8,
                  wide ? 20 : 10,
                  wide ? 16 : 10,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.reportPaper,
                    borderRadius: BorderRadius.circular(wide ? 4 : 2),
                    border: Border.all(color: c.reportPaperBorder, width: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(wide ? 4 : 2),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        cardTheme: CardThemeData(
                          color: c.reportPaper,
                          elevation: 0,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: BorderSide(
                              color: c.reportPaperBorder,
                              width: 0.8,
                            ),
                          ),
                        ),
                        dividerColor: c.reportPaperBorder,
                        scaffoldBackgroundColor: c.reportPaper,
                      ),
                      child: ColoredBox(
                        color: c.reportPaper,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
