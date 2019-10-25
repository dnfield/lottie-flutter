import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:lottie_flutter/lottie_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

const List<String> assetNames = const <String>[
  'assets/Indicators2.json',
  'assets/happy_gift.json',
  'assets/empty_box.json',
  'assets/muzli.json',
  // 'assets/hamburger_arrow.json',//not loaing correctly
  'assets/motorcycle.json',
  'assets/emoji_shock.json',
  'assets/checked_done_.json',
  'assets/favourite_app_icon.json',
  'assets/preloader.json',
  'assets/walkthrough.json',
  'assets/laugh.json',
  'assets/extra/1192-like.json',
  // 'assets/extra/1919-share-the-love.json',//errors
  'assets/extra/2086-wow.json',
  // 'assets/extra/3109-badge.json',
  'assets/extra/3150-success.json',
  'assets/extra/3151-books.json',
  'assets/extra/3227-error-404-facebook-style.json',
  // 'assets/extra/3341-rubberhose-to-ios.json',
  // 'assets/extra/3359-christmas-tree-with-gifts.json',
  'assets/extra/3360-hearts.json',
  'assets/extra/3409-done.json',
  // 'assets/extra/3477-christmas-tree-with-gift-boxes.json',
  'assets/extra/3603-chat-animation.json',
  'assets/extra/362-like.json',
  // 'assets/extra/3647-incoming-call.json',
  // 'assets/extra/3648-no-internet-connection.json',//Text not rendering
  // 'assets/extra/3659-swipe.json',//not rendering correctly
  'assets/extra/3660-night-mode.json',
  // 'assets/extra/3738-blockchain-2.json',//may be gradient problem
  'assets/extra/3757-manch-app-like-button.json',
  // 'assets/extra/3781-barcode-scanner.json',
  'assets/extra/3794-map-pin-drop.json',
  'assets/extra/3846-trophy-shake.json',
  'assets/extra/3856-heart-break-or-unlike.json',
  // 'assets/extra/3870-taxi.json',
  // 'assets/extra/3928-xiao-you.json',
  'assets/extra/3944-voce-ganhou.json',
  // 'assets/extra/3956-earth.json',//only 1/4 image is shown
  // 'assets/extra/3971-graph.json',
  // 'assets/extra/3992-week-before-christmas.json',
  // 'assets/extra/4007-loader.json',
  'assets/extra/4010-00-layout.json',
  // 'assets/extra/4012-fast-car.json',
];

void main() {
  runApp(DemoApp());
}

class DemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lottie Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LottieDemo(),
    );
  }
}

class LottieDemo extends StatefulWidget {
  const LottieDemo({Key key}) : super(key: key);

  @override
  _LottieDemoState createState() => _LottieDemoState();
}

class _LottieDemoState extends State<LottieDemo>
    with SingleTickerProviderStateMixin {
  LottieComposition _composition;
  String _assetName;
  AnimationController _controller;
  bool _repeat;

  @override
  void initState() {
    super.initState();

    _repeat = false;
    _loadButtonPressed(assetNames.first);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1),
      vsync: this,
    );
    _controller.addListener(() => setState(() {}));
  }

  void _loadButtonPressed(String assetName, {String from}) {
    loadAsset(assetName).then((LottieComposition composition) {
      setState(() {
        _assetName = assetName;
        _composition = composition;
        _controller.reset();
        // if (_controller.status == AnimationStatus.dismissed ||
        //     _controller.status == AnimationStatus.completed) {
        //   _controller.forward();
        // }
        //if (from == 'drag') {
        _controller.forward();
        print(_controller
            .velocity); //TODO Velocity is reducing when dragging right to left ?
        //}
        if (_controller.isAnimating) {
          if (_repeat) {
            _controller.forward().then<Null>((nulle) => _controller.repeat());
          } else {
            _controller.forward();
          }
        }
      });
    });
  }

  Offset startPos;
  @override
  Widget build(BuildContext context) {
    final DropdownButton<String> dropDown = DropdownButton<String>(
      items: assetNames
          .map((String assetName) => DropdownMenuItem<String>(
                child: Text(assetName.substring(7)),
                value: assetName,
              ))
          .toList(),
      hint: const Text('Choose an asset'),
      value: _assetName,
      onChanged: (String val) => _loadButtonPressed(val),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lottie Demo'),
      ),
      body: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              GestureDetector(
                onHorizontalDragStart: (DragStartDetails details) {
                  startPos = details.globalPosition;
                },
                onHorizontalDragEnd: (DragEndDetails details) {
                  //var change = (details. - startPos).dx.round();
                  final double change = details.velocity.pixelsPerSecond.dx;
                  //print(change);
                  final int i = assetNames.indexOf(dropDown.value);
                  if (change > 0) {
                    _controller.stop();
                    if (i - 1 > -1) {
                      _loadButtonPressed(assetNames[i - 1], from: 'drag');
                    } else {
                      print('first Item');
                    }
                  } else {
                    _controller.stop();
                    if (i + 1 < assetNames.length) {
                      _loadButtonPressed(assetNames[i + 1], from: 'drag');
                    } else {
                      print('last Item');
                    }
                  }
                },
                child: dropDown,
              ),
              Text(_composition?.bounds?.size?.toString() ?? ''),
              Lottie(
                composition: _composition,
                size: const Size(360.0, 360.0),
                controller: _controller,
              ),
              Slider(
                value: _controller.value,
                onChanged: _composition != null
                    ? (double val) => setState(() => _controller.value = val)
                    : null,
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.repeat),
                      color: _repeat ? Colors.black : Colors.black45,
                      onPressed: () => setState(() {
                            _repeat = !_repeat;
                            if (_controller.isAnimating) {
                              if (_repeat) {
                                _controller.forward().then<Null>(
                                    (nulle) => _controller.repeat());
                              } else {
                                _controller.forward();
                              }
                            }
                          }),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fast_rewind),
                      onPressed: _controller.value > 0 && _composition != null
                          ? () => setState(() => _controller.reset())
                          : null,
                    ),
                    IconButton(
                      icon: _controller.isAnimating
                          ? const Icon(Icons.pause)
                          : const Icon(Icons.play_arrow),
                      onPressed: _controller.isCompleted || _composition == null
                          ? null
                          : () {
                              setState(() {
                                if (_controller.isAnimating) {
                                  _controller.stop();
                                } else {
                                  if (_repeat) {
                                    _controller.repeat();
                                  } else {
                                    _controller.forward();
                                  }
                                }
                              });
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: _controller.isAnimating && _composition != null
                          ? () {
                              _controller.reset();
                            }
                          : null,
                    ),
                  ]),
            ],
          ),
        ),
      ),
    );
  }
}

Future<LottieComposition> loadAsset(String assetName) async {
  return await rootBundle
      .loadString(assetName)
      .then<Map<String, dynamic>>((String data) => json.decode(data))
      .then((Map<String, dynamic> map) => LottieComposition.fromMap(map));
}
