import 'dart:html';
import 'dart:ui' as ui;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// macke soure you add jsQR library in index.html file
dynamic _jsQR(data, width, height, option) {
  return js.context.callMethod('jsQR', [data, width, height, option]);
}

class FlutterWebQrcodeScanner extends StatefulWidget {
  const FlutterWebQrcodeScanner({
    Key? key,
    this.controller,
    required this.onGetResult,
    this.onError,
    this.onPermessionError,
    this.placeholder,
    this.stopOnFirstResult,
    this.width,
    this.height,
  }) : super(key: key);
  final CameraController? controller;
  final Function? onPermessionError;
  final double? width;
  final double? height;
  final Function(String) onGetResult;

  ///widget displayed when video streem is not playing
  final Widget? placeholder;

  ///stop video streem on get first result
  final bool? stopOnFirstResult;

  /// *
  /// class DomException
  /// *
  /// get String? message
  /// *
  /// get String name
  final Function(DomException error)? onError;
  @override
  _WebcamPageState createState() => _WebcamPageState();
}

class _WebcamPageState extends State<FlutterWebQrcodeScanner> {
  late Widget _webcamWidget;
  late VideoElement _webcamVideoElement;
  late CanvasElement _canvasElement;
  late final CameraController _controller;
  CanvasRenderingContext2D? _canvas;
  String? _result;
  late MediaStream? _stream;
  bool _stopDecoding = false;
  // late MediaRecorder mediaRecorder;

  @override
  void initState() {
    super.initState();
    String _key = UniqueKey().toString();
    _webcamVideoElement = VideoElement()
      ..style.width = "100%"
      ..style.height = "100%";
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
        'webcamVideoElement$_key', (int viewId) => _webcamVideoElement);
    _webcamWidget =
        HtmlElementView(key: UniqueKey(), viewType: 'webcamVideoElement$_key');
    if (widget.controller == null) {
      _controller = CameraController();
    } else {
      _controller = widget.controller!;
    }
    _controller.addListener(_cameraControllerListener);

    if (_controller.isRecording) {
      _startVideoStreem();
    }

    _canvasElement = CanvasElement();
    _canvas = _canvasElement.getContext("2d") as CanvasRenderingContext2D?;
  }

  @override
  void dispose() {
    _stopVideoStreem();
    _controller.removeListener(_cameraControllerListener);
    super.dispose();
  }

  void _cameraControllerListener() async {
    if (_controller.isRecording) {
      _startVideoStreem();
      setState(() {});
    } else {
      // print('stop video streem ');
      _stopVideoStreem();
    }
  }

  _startVideoStreem() {
    _stopDecoding = false;
    _result = null;

    if (_webcamVideoElement.srcObject?.active == null ||
        !_webcamVideoElement.srcObject!.active!) {
      window.navigator.getUserMedia(video: true).then((MediaStream stream) {
        _webcamVideoElement.srcObject = stream;
        _stream = stream;
        _webcamVideoElement.setAttribute('playsinline', 'true');
        if (_webcamVideoElement.srcObject?.active != null &&
            _webcamVideoElement.srcObject!.active!) {
          _webcamVideoElement.play();
          Future.delayed(const Duration(milliseconds: 20), () {
            _decode();
          });
        }
      }).catchError((domError) {
        _controller.stopVideoStreem();
        if (domError.name == "NotAllowedError") {
          if (widget.onPermessionError != null) {
            widget.onPermessionError!();
          } else {
            if (kDebugMode) {
              print(domError);
            }
          }
        } else {
          if (widget.onError != null) {
            widget.onError!(domError);
          } else {
            if (kDebugMode) {
              print(domError);
            }
          }
        }
      });
    } else {
      if (_webcamVideoElement.srcObject!.active!) {
        _webcamVideoElement.play();
        Future.delayed(const Duration(milliseconds: 20), () {
          _decode();
        });
      }
    }
  }

  _stopVideoStreem() async {
    if (_webcamVideoElement.srcObject?.active != null) {
      _webcamVideoElement.pause();
      if (_stream != null) {
        _stream!.getTracks().forEach((track) {
          track.stop();
        });
      }
      _stopDecoding = true;

      setState(() {});
    }
  }

  _decode() {
    if (_stopDecoding) {
      return;
    }

    if (_webcamVideoElement.readyState == 4) {
      _canvasElement.width = _webcamVideoElement.videoWidth;
      _canvasElement.height = _webcamVideoElement.videoHeight;
      _canvas?.drawImage(_webcamVideoElement, 0, 0);
      var imageData = _canvas?.getImageData(
        0,
        0,
        _canvasElement.width ?? 100,
        _canvasElement.height ?? 100,
      );
      if (imageData is ImageData) {
        try {
          js.JsObject? code = _jsQR(
            imageData.data,
            imageData.width,
            imageData.height,
            {
              'inversionAttempts': 'dontInvert',
            },
          );
          if (code != null) {
            var scanData = _convertToDart(code);

            if (_result == null || _result != scanData['data']) {
              _result = scanData['data'];
              widget.onGetResult(scanData['data']);
              if (widget.stopOnFirstResult == true) {
                _controller.stopVideoStreem();
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print(e);
          }
        }
      }
    }
    Future.delayed(const Duration(milliseconds: 30), () => _decode());
  }

  _getKeysOfObject(js.JsObject object) {
    return (js.context['Object'] as js.JsFunction).callMethod('keys', [object]);
  }

  dynamic _convertToDart(value) {
    if (value == null) return null;
    if (value is bool || value is num || value is DateTime || value is String) {
      return value;
    }
    if (value is Iterable) return value.map(_convertToDart).toList();
    return Map.fromIterable(_getKeysOfObject(value),
        value: (key) => _convertToDart(value[key]));
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        height: widget.height,
        child: _controller.isRecording
            ? _webcamWidget
            : widget.placeholder ?? Container(),
      );
}

class CameraController extends ChangeNotifier {
  final bool autoPlay;

  CameraController({this.autoPlay = true}) {
    if (autoPlay) {
      _isRecording = true;
    }
  }

  bool _isRecording = false;

  bool get isRecording => _isRecording;

  void startVideoStreem() {
    if (!_isRecording) {
      _isRecording = true;
      notifyListeners();
    }
  }

  void stopVideoStreem() {
    if (_isRecording) {
      _isRecording = false;
      notifyListeners();
    }
  }
}
