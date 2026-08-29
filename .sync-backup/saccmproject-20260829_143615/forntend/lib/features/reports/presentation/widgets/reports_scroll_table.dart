import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';

/// Scrollable report table with frozen header — uses [DataTable2].
class ReportsScrollTable extends StatelessWidget {
  const ReportsScrollTable({
    super.key,
    required this.columns,
    required this.rows,
    this.headingColor,
    this.minWidth = 640,
    this.columnSpacing = 12,
    this.headingRowHeight = 44,
    this.dataRowHeight = 44,
  });

  final List<ReportsTableColumn> columns;
  final List<List<ReportsTableCell>> rows;
  final Color? headingColor;
  final double minWidth;
  final double columnSpacing;
  final double headingRowHeight;
  final double dataRowHeight;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final headBg = headingColor ?? c.reportTableHeader;
    final headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 12,
      color: c.textPrimary,
      fontFamily: 'Kanit',
    );
    final bodyStyle = TextStyle(
      fontSize: 12,
      color: c.textPrimary,
      fontFamily: 'Kanit',
    );
    final subBodyStyle = bodyStyle.copyWith(
      color: c.textSecondary,
      fontWeight: FontWeight.normal,
    );

    // ความสูงตาราง = หัว + แถวข้อมูล (ไม่พึ่ง viewport ของ DataTable2)
    // เพื่อให้วางใน ListView / horizontal scroll ได้โดยไม่ unbounded-height crash
    final tableHeight =
        headingRowHeight + (rows.isEmpty ? dataRowHeight : rows.length * dataRowHeight);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : minWidth;
        return ColoredBox(
          color: c.reportPaper,
          child: SizedBox(
            width: width,
            height: tableHeight,
            child: DataTable2(
              columnSpacing: columnSpacing,
              horizontalMargin: 8,
              minWidth: minWidth,
              headingRowHeight: headingRowHeight,
              dataRowHeight: dataRowHeight,
              headingRowColor: WidgetStatePropertyAll(headBg),
              dataRowColor: WidgetStatePropertyAll(c.reportPaper),
              border: TableBorder.all(color: c.reportPaperBorder, width: 0.85),
              columns: columns
                  .map(
                    (col) => DataColumn2(
                      label: Text(col.label, style: headerStyle),
                      numeric: col.numeric,
                      size: col.size,
                    ),
                  )
                  .toList(),
              rows: rows
                  .map(
                    (cells) => DataRow2(
                      cells: List.generate(cells.length, (i) {
                        final cell = cells[i];
                        final style = cell.subdued ? subBodyStyle : bodyStyle;
                        final textStyle = cell.color != null
                            ? style.copyWith(color: cell.color)
                            : style;
                        return DataCell(
                          Align(
                            alignment: cell.numeric
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Text(
                              cell.text,
                              style: textStyle,
                              textAlign: cell.numeric
                                  ? TextAlign.right
                                  : TextAlign.left,
                              maxLines: cell.maxLines,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

class ReportsTableColumn {
  const ReportsTableColumn({
    required this.label,
    this.numeric = false,
    this.size = ColumnSize.M,
  });

  final String label;
  final bool numeric;
  final ColumnSize size;
}

class ReportsTableCell {
  const ReportsTableCell(
    this.text, {
    this.numeric = false,
    this.subdued = false,
    this.color,
    this.maxLines = 2,
  });

  final String text;
  final bool numeric;
  final bool subdued;
  final Color? color;
  final int maxLines;
}
