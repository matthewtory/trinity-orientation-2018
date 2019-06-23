import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ScrollState {
  Open, Closed
}

class ScrollBloc {

  Sink<double> get progressInput => _progressInputController.sink;
  StreamController<double> _progressInputController = StreamController<double>();

  Stream<double> get progressOutput => _output.stream;
  StreamController<double> _output = BehaviorSubject<double>();

  Sink<ScrollState> get scrollStateInput => scrollStateController.sink;
  Stream<ScrollState> get scrollStateOutput => scrollStateController.stream;
  StreamController<ScrollState> scrollStateController = StreamController<ScrollState>();

  Sink<double> get horizontalScrollInput => _horizontalScrollInputController.sink;
  StreamController<double> _horizontalScrollInputController = StreamController<double>();

  Stream<double> get horizontalScrollOutput => _horizontalScrollOutput.stream;
  StreamController<double> _horizontalScrollOutput = BehaviorSubject<double>();

  ScrollBloc() {
    _progressInputController.stream.listen((double progress) {
      _output.add(progress);
    });

    _horizontalScrollInputController.stream.listen((double progress) {
      _horizontalScrollOutput.add(progress);
    });
  }
}

class ScrollProvider extends InheritedWidget {
  ScrollProvider({Key key, this.scrollBloc, Widget child}) : super(key: key, child: child);

  final ScrollBloc scrollBloc;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    return true;
  }

  static ScrollBloc of(BuildContext context) =>
      (context.inheritFromWidgetOfExactType(ScrollProvider) as ScrollProvider).scrollBloc;
}
