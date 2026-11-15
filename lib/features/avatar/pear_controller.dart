import 'package:flutter/foundation.dart';

/// Estado da Bold Pear 3D: expressão, fala, voz (acessórios) e respiração.
class PearController extends ChangeNotifier {
  String expr = 'neutral'; // neutral | happy | concern
  bool talking = false;
  String gender = 'f';
  double breath = 1;

  Map<String, Object> get state => {'expr': expr, 'talking': talking, 'gender': gender, 'breath': breath};

  void set({String? expr, bool? talking, String? gender, double? breath}) {
    var changed = false;
    if (expr != null && expr != this.expr) {
      this.expr = expr;
      changed = true;
    }
    if (talking != null && talking != this.talking) {
      this.talking = talking;
      changed = true;
    }
    if (gender != null && gender != this.gender) {
      this.gender = gender;
      changed = true;
    }
    if (breath != null && breath != this.breath) {
      this.breath = breath;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
