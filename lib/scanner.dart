import 'dart:async' show Future, Timer;
import 'dart:core'
    show Duration, Future, List, String, bool, dynamic, int, override, print;
import 'dart:html' as html;
import 'dart:js_util' show promiseToFuture;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'jsqr.dart' show jsQR;
import 'media.dart' show UserMediaOptions, VideoOptions, getUserMedia;

class Scanner extends StatefulWidget {
  /// clickToCapture to show a button to capture a Data URL for the image
  final bool clickToCapture;

  const Scanner({this.clickToCapture = false, key}) : super(key: key);

  @override
  _ScannerState createState() => _ScannerState();

  static html.DivElement vidDiv =
      html.DivElement(); // need a global for the registerViewFactory

  static Future<bool> cameraAvailable() async {
    List<dynamic> sources =
        await html.window.navigator.mediaDevices!.enumerateDevices();
    print("sources:");
    // List<String> vidIds = [];
    bool hasCam = false;
    for (final e in sources) {
      print(e);
      if (e.kind == 'videoinput') {
        // vidIds.add(e['deviceId']);
        hasCam = true;
      }
    }
    return hasCam;
  }
}

class _ScannerState extends State<Scanner> {
  html.MediaStream? _localStream;
  // html.CanvasElement canvas;
  // html.CanvasRenderingContext2D ctx;
  bool _inCalling = false;
  bool _isTorchOn = false;
  html.MediaRecorder? _mediaRecorder;
  bool get _isRec => _mediaRecorder != null;
  Timer? timer;
  String? code;
  String? _errorMsg;
  var front = false;
  var video;
  String viewID = "your-view-id";

  @override
  void initState() {
    print("MY SCANNER initState");
    super.initState();
    video = html.VideoElement();
    // canvas = new html.CanvasElement(width: );
    // ctx = canvas.context2D;
    Scanner.vidDiv.children = [video];
    // ignore: UNDEFINED_PREFIXED_NAME
    ui.platformViewRegistry
        .registerViewFactory(viewID, (int id) => Scanner.vidDiv);
    // initRenderers();
    Timer(Duration(milliseconds: 500), () {
      start();
    });
  }

  void start() async {
    await _makeCall();
    // if (timer == null || !timer.isActive) {
    //   timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
    //     if (code != null) {
    //       timer.cancel();
    //       Navigator.pop(context, code);
    //       return;
    //     }
    //     _captureFrame2();
    //     if (code != null) {
    //       timer.cancel();
    //       Navigator.pop(context, code);
    //     }
    //   });
    // }
    if (!widget.clickToCapture) {
      // instead of periodic, which seems to have some timing issues, going to call timer AFTER the capture.
      Timer(Duration(milliseconds: 200), () {
        _captureFrame2();
      });
    }
  }

  void cancel() {
    if (timer != null) {
      timer!.cancel();
      timer = null;
    }
    if (_inCalling) {
      _stopStream();
    }
  }

  @override
  void dispose() {
    print("Scanner.dispose");
    cancel();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> _makeCall() async {
    if (_localStream != null) {
      return;
    }

    try {
      var constraints = UserMediaOptions(
          // audio: false,
          video: VideoOptions(
        facingMode: (front ? "user" : "environment"),
      ));
      // dart style, not working properly:
      // var stream =
      //     await html.window.navigator.mediaDevices.getUserMedia(constraints);
      // straight JS:
      var stream = await promiseToFuture(getUserMedia(constraints));
      _localStream = stream;
      video.srcObject = _localStream;
      video.setAttribute("playsinline",
          'true'); // required to tell iOS safari we don't want fullscreen
      await video.play();
    } catch (e, stackTrace) {
      print("error on getUserMedia: ${e.toString()} $stackTrace");
      cancel();
      setState(() {
        _errorMsg = e.toString() + stackTrace.toString();
      });
      return;
    }
    if (!mounted) return;

    setState(() {
      _inCalling = true;
    });
  }

  void _hangUp() async {
    await _stopStream();
    setState(() {
      _inCalling = false;
    });
  }

  Future<void> _stopStream() async {
    try {
      // await _localStream.dispose();
      _localStream!.getTracks().forEach((track) {
        if (track.readyState == 'live') {
          track.stop();
        }
      });
      // video.stop();
      video.srcObject = null;
      _localStream = null;
      // _localRenderer.srcObject = null;
    } catch (e) {
      print(e.toString());
    }
  }

  _toggleCamera() async {
    final videoTrack = _localStream!
        .getVideoTracks()
        .firstWhere((track) => track.kind == 'video');
    // await videoTrack.switchCamera();
    videoTrack.stop();
    await _makeCall();
  }

  Future<dynamic> _captureFrame2() async {
    if (_localStream == null) {
      print("localstream is null, can't capture frame");
      return null;
    }
    html.CanvasElement canvas = new html.CanvasElement(
        width: video.videoWidth, height: video.videoHeight);
    html.CanvasRenderingContext2D ctx = canvas.context2D;
    // canvas.width = video.videoWidth;
    // canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0);
    html.ImageData imgData =
        ctx.getImageData(0, 0, canvas.width!, canvas.height!);
    // print(imgData);
    var code = jsQR(imgData.data, canvas.width, canvas.height);
    // print("CODE: $code");
    if (code != null) {
      print(code.data);
      this.code = code.data;
      Navigator.pop(context, this.code);
      return this.code;
    } else {
      Timer(Duration(milliseconds: 500), () {
        _captureFrame2();
      });
    }
  }

  Future<String?> _captureImage() async {
    if (_localStream == null) {
      print("localstream is null, can't capture frame");
      return null;
    }
    html.CanvasElement canvas = new html.CanvasElement(
        width: video.videoWidth, height: video.videoHeight);
    html.CanvasRenderingContext2D ctx = canvas.context2D;
    // canvas.width = video.videoWidth;
    // canvas.height = video.videoHeight;
    ctx.drawImage(video, 0, 0);
    var dataUrl = canvas.toDataUrl("image/jpeg", 0.9);
    return dataUrl;
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMsg != null) {
      return Center(child: Text(_errorMsg!));
    }
    if (_localStream == null) {
      return Text("Loading...");
    }
    return Column(children: [
      Expanded(
        child: Container(
          // constraints: BoxConstraints(
          //   maxWidth: 600,
          //   maxHeight: 1000,
          // ),
          child: OrientationBuilder(
            builder: (context, orientation) {
              return Center(
                child: Container(
                  margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  // width: MediaQuery.of(context).size.width,
                  // height: MediaQuery.of(context).size.height,
                  child: HtmlElementView(viewType: viewID),
                  decoration: BoxDecoration(color: Colors.black54),
                ),
              );
            },
          ),
        ),
      ),
      // IconButton(
      //   icon: Icon(Icons.switch_video),
      //   onPressed: _toggleCamera,
      // ),
      if (widget.clickToCapture)
        IconButton(
          icon: Icon(Icons.camera),
          onPressed: () async {
            var imgUrl = await _captureImage();
            print("Image URL: $imgUrl");
            Navigator.pop(context, imgUrl);
          },
        ),
    ]);
  }
}
