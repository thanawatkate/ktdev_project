import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/providers/customTable/SelectMenu.provider.dart';
import 'package:saccm/providers/customTable/select_table_provider.dart';

class CustomTable extends StatelessWidget {
  final List rowData;
  final List<List<String>> columData;
  final Function(int)? buttonOnPressed;

  const CustomTable({
    super.key,
    required this.columData,
    required this.rowData,
    this.buttonOnPressed,
  });

  static const List<Widget> menuTable = <Widget>[
    Text(TransactionUiText.delete),
    Text(TransactionUiText.edit)
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
        padding: const EdgeInsets.all(16),
        child: ChangeNotifierProvider(
          create: (_) => SelectionModel(rowData.length, []),
          child: SingleChildScrollView(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (rowData.isNotEmpty)
                Consumer<SelectionModel>(builder: (context, model, child) {
                  bool exists =
                      model.selected.any((element) => element == true);
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (exists == true)
                          ChangeNotifierProvider(
                              create: (_) => SelectionMenu(),
                              child: Consumer<SelectionMenu>(
                                  builder: (context, model, child) {
                                return ToggleButtons(
                                  direction: Axis.horizontal,
                                  onPressed: buttonOnPressed,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(4)),
                                  borderColor: c.cardBorder,
                                  selectedBorderColor: scheme.primary,
                                  selectedColor: scheme.onPrimary,
                                  fillColor: scheme.primary,
                                  color: c.textPrimary,
                                  constraints: const BoxConstraints(
                                    minHeight: 20.0,
                                    minWidth: 80.0,
                                  ),
                                  isSelected: model.selected,
                                  children: menuTable,
                                );
                              })),
                        DataTable(
                          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.16);
                            }
                            return null; // Use the default value.
                          }),
                          headingTextStyle: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Kanit',
                          ),
                          dataTextStyle: TextStyle(
                            color: c.textPrimary,
                            fontFamily: 'Kanit',
                          ),
                          showCheckboxColumn: true,
                          horizontalMargin: 12,
                          sortAscending: true,
                          // ignore: avoid_print
                          columns: columData
                              .map(
                                (e) => DataColumn(
                                  label: Text(e[0]),
                                ),
                              )
                              .toList(),
                          // rows: const []
                          rows: List<DataRow>.generate(
                            rowData.length,
                            (index) {
                              return DataRow(
                                cells: columData
                                    .map(
                                      (e) => DataCell(Text(
                                          rowData[index][e[1]].toString())),
                                    )
                                    .toList(),
                                selected: model.selected[index],
                                onSelectChanged: (bool? selected) {
                                  if (selected != null) {
                                    model.toggleSelection(index, selected);
                                    model
                                        .setSelectionData(rowData[index]['id']);
                                  }
                                },
                              );
                            },
                          ),
                          // onSelectAll: (value) => {print(value)},
                        ),
                      ]);
                }),
              if (rowData.isEmpty)
                Text(
                  TransactionUiText.noData,
                  style: TextStyle(color: c.textSecondary),
                )
            ]),
          ),
        ));
  }
}
