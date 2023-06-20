import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as wv;

import 'base.dart';

class NativeWebView extends WebView {
  const NativeWebView({
    required Key? key,
    required String src,
    required double? width,
    required double? height,
    required OnLoaded? onLoaded,
    required this.options,
  }) : super(
          key: key,
          src: src,
          width: width,
          height: height,
          onLoaded: onLoaded,
        );

  final WebViewOptions options;

  @override
  State<WebView> createState() => NativeWebViewState();
}

class EasyWebViewControllerWrapper extends EasyWebViewControllerWrapperBase {
  final wv.WebViewController _controller;

  EasyWebViewControllerWrapper._(this._controller);

  @override
  Future<void> evaluateJSMobile(String js) {
    return _controller.runJavaScript(js);
  }

  @override
  Future<String> evaluateJSWithResMobile(String js) async {
    final res = await _controller.runJavaScriptReturningResult(js);

    return res.toString();
  }

  @override
  Object get nativeWrapper => _controller;

  @override
  void postMessageWeb(dynamic message, String targetOrigin) =>
      throw UnsupportedError("the platform doesn't support this operation");
}

class NativeWebViewState extends WebViewState<NativeWebView> {
  late wv.WebViewController controller;

  @override
  void initState() {
    final _controller = wv.WebViewController();
    _controller.setJavaScriptMode(wv.JavascriptMode.unrestricted);
    _controller.setNavigationDelegate(
        wv.NavigationDelegate(onNavigationRequest: (navigationRequest) async {
      if (widget.options.navigationDelegate == null) {
        return wv.NavigationDecision.navigate;
      }
      final _navDecision = await widget.options
          .navigationDelegate!(WebNavigationRequest(navigationRequest.url));
      return _navDecision == WebNavigationDecision.prevent
          ? wv.NavigationDecision.prevent
          : wv.NavigationDecision.navigate;
    }));
    if (widget.options.crossWindowEvents.isNotEmpty) {
      updateJSChannels(_controller, widget.options.crossWindowEvents, null);
    }
    _controller.loadRequest(Uri.parse(url));

    controller = _controller;

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      widget.onLoaded?.call(EasyWebViewControllerWrapper._(controller));
    });

    super.initState();
  }

  @override
  void didUpdateWidget(covariant NativeWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      reload();
    }
    if (!listEquals(
      oldWidget.options.crossWindowEvents,
      widget.options.crossWindowEvents,
    )) {
      updateJSChannels(
        controller,
        widget.options.crossWindowEvents,
        oldWidget.options.crossWindowEvents,
      );
    }
  }

  updateJSChannels(
    wv.WebViewController controller,
    List<CrossWindowEvent> crossWindowEvents,
    List<CrossWindowEvent>? oldCrossWindowEvents,
  ) {
    oldCrossWindowEvents?.forEach((element) {
      controller.removeJavaScriptChannel(element.name);
    });

    crossWindowEvents.forEach((element) {
      controller.addJavaScriptChannel(element.name,
          onMessageReceived: (javascriptMessage) {
        element.eventAction(javascriptMessage.message);
      });
    });
  }

  reload() {
    controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget builder(BuildContext context, Size size, String contents) {
    return wv.WebViewWidget(
      key: widget.key,
      controller: controller,
    );
  }
}
