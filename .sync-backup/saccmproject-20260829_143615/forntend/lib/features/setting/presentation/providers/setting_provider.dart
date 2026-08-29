import 'package:flutter/material.dart';

class SettingProvider extends ChangeNotifier {
  String? title;
  SettingProvider({this.title = ""});
  Future<void> addTitle(String val) async {
    title = val;
    notifyListeners();
  }

  //end userTab
}
