import 'package:flutter_test/flutter_test.dart';
import 'package:saccm/core/local_data_source/reports_local_data_source.dart';

void main() {
  group('ReportsLocalDataSource official annual expense grouping', () {
    test('maps expense type codes to page 33 sections', () {
      expect(
        ReportsLocalDataSource.expenseReportGroupForCode('00')['code'],
        'personnel',
      );
      expect(
        ReportsLocalDataSource.expenseReportGroupForCode('01')['code'],
        'operating',
      );
      expect(
        ReportsLocalDataSource.expenseReportGroupForCode('06')['code'],
        'investment',
      );
      expect(
        ReportsLocalDataSource.expenseReportGroupForCode('07')['code'],
        'subsidy',
      );
      expect(
        ReportsLocalDataSource.expenseReportGroupForCode('08')['code'],
        'other',
      );
    });

    test('aggregates detail rows without losing equal amounts', () {
      final grouped = ReportsLocalDataSource.groupExpenseRowsByOfficialSection([
        {'code': '01', 'type_name': 'ค่าตอบแทน', 'total': 100, 'count': 1},
        {'code': '02', 'type_name': 'ค่าใช้สอย', 'total': 100, 'count': 1},
        {'code': '05', 'type_name': 'ครุภัณฑ์', 'total': 50, 'count': 1},
      ]);

      final operating =
          grouped.singleWhere((row) => row['code'] == 'operating');
      expect(operating['total'], 200);
      expect(operating['count'], 2);
      expect(grouped.map((row) => row['code']), ['operating', 'investment']);
    });
  });
}
