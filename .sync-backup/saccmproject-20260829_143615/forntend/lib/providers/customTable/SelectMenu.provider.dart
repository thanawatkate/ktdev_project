import 'package:flutter/material.dart';

class SelectionMenu extends ChangeNotifier {
  final List<bool> _selected = <bool>[false, false, false];

  List<bool> get selected => _selected;
  void toggleSelection(int index, bool isSelected) {
    _selected[index] = isSelected;
    notifyListeners();
  }
}
