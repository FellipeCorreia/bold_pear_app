import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import 'pear_controller.dart';

/// Web: a pera 3D roda num iframe com o mesmo HTML usado no mobile.
class PearView extends StatefulWidget {
  const PearView({super.key, required this.controller});
  final PearController controller;

  @override
  State<PearView> createState() => _PearViewState();
}

class _PearViewState extends State<PearView> {
  static int _seq = 0;
  late final String _viewType = 'bold-pear-${_seq++}';
  web.HTMLIFrameElement? _frame;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final f = web.HTMLIFrameElement()
        ..src = 'assets/assets/avatar/index.html?bg=2c2c30'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'none';
      f.addEventListener('load', ((web.Event _) => _push()).toJS);
      _frame = f;
      return f;
    });
    widget.controller.addListener(_push);
  }

  void _push() {
    final w = _frame?.contentWindow;
    if (w == null) return;
    w.postMessage(jsonEncode({'pear': widget.controller.state}).toJS, '*'.toJS);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_push);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
