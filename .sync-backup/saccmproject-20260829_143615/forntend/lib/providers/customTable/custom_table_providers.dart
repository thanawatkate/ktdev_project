import 'package:flutter/material.dart';

class CustomTableProvider extends ChangeNotifier {
  List<dynamic> rowData;

  CustomTableProvider({
    required this.rowData,
  });
  void addListData(List<dynamic> val) {
    rowData = val;
    notifyListeners();
  }

  // for checkbox
}
