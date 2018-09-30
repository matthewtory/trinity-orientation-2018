import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'schedule.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'map.dart';
import 'info.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'event_page.dart';
import 'photos.dart';

void main() {
  FirebaseAuth.instance.currentUser().then((user) {
    if (user == null) {
      FirebaseAuth.instance.signInAnonymously();
    }
  });

  runApp(new MyApp());
}

Future<String> _loadCrosswordAsset() async {
  return await rootBundle.loadString('assets/utsg.json');
}

Future loadCrossword() async {
  String jsonCrossword = await _loadCrosswordAsset();
  _parseJsonForCrossword(jsonCrossword);
}

void _parseJsonForCrossword(String jsonString) {
  Map decoded = json.decode(jsonString);

  List<dynamic> buildings = decoded['buildings'];
  for (var building in buildings) {
    if (building['lat'] != null && building['lat'] != 0 && building['lng'] != null && building['long'] != 0) {
      Firestore.instance.collection('buildings').add({
        'name': building['name'],
        'code': building['code'],
        'location': new GeoPoint(double.parse('${building['lat']}'), double.parse('${building['lng']}')),
        'address':
            '${building['address']['street']}, ${building['address']['city']}, ${building['address']['province']}, ${building['address']['country']}, ${building['address']['postal']}'
      }).then((doc) {
        print(doc);
      }, onError: (error) {
        print(error);
      });
    }
  }
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    return new MaterialApp(
      title: '2T2000s',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new AppHome(),
    );
  }
}

class AppHome extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => AppHomeState();
}

class AppPage {
  AppPage({Widget icon, String title, Color color, this.body, TickerProvider vsync})
      : this._icon = icon,
        this._title = title,
        this._color = color,
        this.controller = new AnimationController(vsync: vsync, duration: Duration(milliseconds: 300)),
        this.item = new BottomNavigationBarItem(
          icon: icon,
          title: new Text(title),
          backgroundColor: color,
        ) {
    _animation = new CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);
  }

  final Widget _icon;
  final String _title;
  final Color _color;
  final AnimationController controller;
  final BottomNavigationBarItem item;
  final Widget body;
  CurvedAnimation _animation;

  FadeTransition buildTransition(BuildContext context) {
    return new FadeTransition(
      opacity: _animation,
      child: body,
    );
  }
}

class AppHomeState extends State<AppHome> with TickerProviderStateMixin {
  final FirebaseMessaging _firebaseMessaging = new FirebaseMessaging();

  List<AppPage> _items;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) {
        print("onMessage: $message");
        _handleMessage(message);
      },
      onLaunch: (Map<String, dynamic> message) {
        print("onLaunch: $message");
        _handleMessage(message);
      },
      onResume: (Map<String, dynamic> message) {
        print("onResume: $message");
        _handleMessage(message);
      },
    );
    _firebaseMessaging.requestNotificationPermissions(IosNotificationSettings(sound: true, badge: true, alert: true));
    _firebaseMessaging.onIosSettingsRegistered.listen((IosNotificationSettings settings) {
      print("Settings registered: $settings");
    });
    _firebaseMessaging.getToken().then((String token) {
      assert(token != null);

      print(token);
    });
    _firebaseMessaging.subscribeToTopic('test_topic');
    _firebaseMessaging.subscribeToTopic('cool_topic');

    _items = [
      new AppPage(
          icon: new Icon(Icons.calendar_today),
          title: 'Schedule',
          color: Colors.tealAccent.shade400,
          body: new SchedulePage(title: 'schedule'),
          vsync: this),
      new AppPage(
        icon: new Icon(Icons.map),
        title: 'Map',
        color: Colors.pinkAccent.shade400,
        body: new MapPage(),
        vsync: this,
      ),
      new AppPage(
        icon: new Icon(Icons.camera),
        title: 'TrinSpace',
        color: Colors.teal,
        body: new PhotosPage(),
        vsync: this,
      ),
      new AppPage(
        icon: new Icon(Icons.info_outline),
        title: 'Info',
        color: Colors.blueAccent.shade400,
        body: new InfoPage(),
        vsync: this,
      ),
    ];

    for (AppPage view in _items) view.controller.addListener(_rebuild);

    _items[_currentIndex].controller.value = 1.0;
  }

  void _rebuild() {
    setState(() {});
  }

  @override
  void dispose() {
    for (AppPage page in _items) {
      page.controller.dispose();
    }

    super.dispose();
  }

  Widget _buildPageStack() {
    final List<Widget> transitions = <Widget>[];

    for (int i = 0; i < _items.length; i++) {
      transitions.add(IgnorePointer(ignoring: _currentIndex != i, child: _items[i].buildTransition(context)));
    }
    return new Stack(children: transitions);
  }

  @override
  Widget build(BuildContext context) {
    final BottomNavigationBar navBar = new BottomNavigationBar(
      items: _items.map((page) {
        return page.item;
      }).toList(),
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.shifting,
      onTap: (int) {
        setState(() {
          _items[_currentIndex].controller.reverse();
          _currentIndex = int;
          _items[_currentIndex].controller.forward();
        });
      },
    );

    return new Scaffold(
      body: new Center(
        child: _buildPageStack(),
      ),
      bottomNavigationBar: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Material(child: navBar),
        ],
      ),
    );
  }

  void _handleMessage(Map<String, dynamic> message) {
    if (message.containsKey('event')) {
      String documentReference = message['event'];
      print('document received: $documentReference');
      Firestore.instance.document('events/$documentReference').get().then((snapshot) {
        print(snapshot);
        if (snapshot != null) {
          Navigator.of(context).push(
            new MyCoolPageRoute(
                builder: (context) {
                  return new EventPage(snapshot);
                },
                fullscreenDialog: true),
          );
        } else {
          print('no document');
        }
      });
    }
  }
}
