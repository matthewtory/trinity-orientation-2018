import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleBloc {

  Sink<List<DocumentSnapshot>> get addition => _streamController.sink;

  StreamController<List<DocumentSnapshot>> _streamController = StreamController<List<DocumentSnapshot>>();

  Stream<List<DocumentSnapshot>> get latestItem => _output.stream;

  StreamController<List<DocumentSnapshot>> _output = BehaviorSubject<List<DocumentSnapshot>>();


  Sink<int> get numItemsInput => _numItemsInput.sink;
  StreamController<int> _numItemsInput = StreamController<int>();

  Stream<int> get numItemsOutput => _numItemsOutput.stream;
  StreamController<int> _numItemsOutput = BehaviorSubject<int>();

  ScheduleBloc() {
    _streamController.stream.listen((List<DocumentSnapshot> schedule) {
      _output.add(schedule);
    });

    _numItemsInput.stream.listen((int) {
      _numItemsOutput.add(int);
    });
  }

}