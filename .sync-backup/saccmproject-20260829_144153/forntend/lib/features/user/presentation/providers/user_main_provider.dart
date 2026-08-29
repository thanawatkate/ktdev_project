import 'package:flutter/material.dart';

class MainProvider extends ChangeNotifier {
  String title;
  MainProvider({this.title = ""});
  void addTitle(String val) {
    title = val;
    notifyListeners();
  }

  void delTitle() {
    title = "";
    notifyListeners();
  }
}
