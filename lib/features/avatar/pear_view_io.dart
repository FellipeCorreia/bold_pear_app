import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/pi_cores.dart';
import 'pear_controller.dart';

/// Android/iOS: a pera 3D (three.js, offline) roda numa WebView local.
class PearView extends StatefulWidget {
  const PearView({super.key, required this.controller});
  final PearController controller;

  @override
  State<PearView> createState() => _PearViewState();
}

class _PearViewState extends State<PearView> {
  late final WebViewController _web;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(PiCores.fundo)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
        _loaded = true;
        _push();
      }))
      ..loadFlutterAsset('assets/avatar/index.html');
    widget.controller.addListener(_push);
  }

  void _push() {
    if (!_loaded) return;
    _web.runJavaScript('window.pear&&window.pear.set(${jsonEncode(widget.controller.state)})');
  }

  @override
  void dispose() {
    widget.controller.removeListener(_push);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(child: WebViewWidget(controller: _web));
}
