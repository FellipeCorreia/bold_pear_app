import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
        _loaded = true;
        // Garante fundo transparente mesmo se o HTML empacotado for de um build antigo.
        _web.runJavaScript("document.documentElement.style.setProperty('--bg','transparent');"
            "document.documentElement.style.background='transparent';document.body.style.background='transparent';"
            "document.body.style.position='fixed';document.body.style.inset='0';document.body.style.touchAction='none';"
            "document.addEventListener('touchmove',function(e){e.preventDefault()},{passive:false})");
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
