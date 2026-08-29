import 'package:flutter/material.dart';

class DisplayProvider extends ChangeNotifier {
  String title;
  DisplayProvider({this.title = ""});

  void addTitle(String txt) {
    title = txt;
    notifyListeners();
  }
}
