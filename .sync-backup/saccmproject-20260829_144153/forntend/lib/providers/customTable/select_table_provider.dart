import 'package:flutter/material.dart';

class SelectionModel extends ChangeNotifier {
  final List<bool> _selected;
  final List<int> _selectedData;
  List<int>? get selectedData => _selectedData;

  SelectionModel(int numItems, this._selectedData)
      : _selected = List.generate(numItems, (_) => false);

  List<bool> get selected => _selected;
  void toggleSelection(int index, bool isSelected) {
    _selected[index] = isSelected;
    notifyListeners();
  }

  void setSelectionData(int id) {
    _selectedData.add(id);
    debugPrint('selectedData: $selectedData');
    notifyListeners();
  }
}
