import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_cache/cached_firebase_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math' as math;
import 'photo_page.dart';
import 'dots_indicator.dart';
import 'firebase_cache/flutter_firebase_cache_manager.dart';
import 'dart:io';
import 'dart:async';
import 'schedule.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedPage extends StatefulWidget {
  final int index;

  FeedPage({Key key, this.index}) : super(key: key);

  @override
  FeedPageState createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  static final MethodChannel _methodChannel = new MethodChannel('com.tory.trinityOrientation/save_image');

  final GlobalKey<State<Scaffold>> _scaffoldKey = GlobalKey<State<Scaffold>>();

  final FirebaseStorage _firebaseStorage = FirebaseStorage(storageBucket: 'gs://trinity-orientation-2018-photos');

  AnimationController _controller;
  PageController _pageController;

  AnimationStatus get animationStatus => _controller != null ? _controller.status : AnimationStatus.dismissed;

  List<DocumentSnapshot> photos;

  String currentPhotoUid;
  String currentEventPath;

  double get _scaffoldHeight {
    final RenderBox renderBox = _scaffoldKey.currentContext.findRenderObject();

    return math.max(0.0, renderBox.size.height);
  }

  @override
  void initState() {
    super.initState();

    _controller = new AnimationController(vsync: this, duration: Duration(milliseconds: 500))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Navigator.of(context).pop();
        }
      });

    _pageController = new PageController(initialPage: widget.index)..addListener(pageListener);
  }

  @override
  void dispose() {
    _pageController.removeListener(pageListener);
    super.dispose();
  }

  void pageListener() {
    if (_pageController.page % 1.0 == 0.0) {
      int page = _pageController.page.toInt();

      if (photos != null) {
        setState(() {
          currentPhotoUid = photos[page]['uid'];
          currentEventPath = photos[page]['event'] != null ? photos[page]['event'].path : null;
        });
      }
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    _controller.value += details.primaryDelta / (_scaffoldHeight ?? details.primaryDelta);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_controller.isAnimating || _controller.status == AnimationStatus.completed) return;

    if (details == null) {
      _controller.fling(velocity: -2.0);
      return;
    }
    final double flingVelocity = details.velocity.pixelsPerSecond.dy / _scaffoldHeight;
    if (flingVelocity < 0.0)
      _controller.fling(velocity: math.max(-2.0, flingVelocity));
    else if (flingVelocity > 0.0)
      _controller.fling(velocity: math.min(2.0, flingVelocity));
    else
      _controller.fling(velocity: _controller.value < 0.5 ? -2.0 : 2.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: _handleVerticalDragEnd,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset.zero, end: Offset(0.0, 1.0)).animate(_controller),
        child: Scaffold(
          key: _scaffoldKey,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned.fill(
                child: StreamBuilder<QuerySnapshot>(
                  stream: Firestore.instance.collection('photos').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    photos = snapshot.data.documents;

                    if (currentPhotoUid == null && photos.length > 0) {
                      currentPhotoUid = photos[widget.index]['uid'];
                      currentEventPath =
                          photos[widget.index]['event'] != null ? photos[widget.index]['event'].path : null;
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        PageView.builder(
                          itemBuilder: (context, index) {
                            return _singlePhotoWidget(photos[index]);
                          },
                          itemCount: photos.length,
                          controller: _pageController,
                        ),
                        new Positioned(
                          bottom: 0.0,
                          left: 0.0,
                          right: 0.0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: FutureBuilder<QuerySnapshot>(
                                    future: Firestore.instance
                                        .collection('users')
                                        .where('uid', isEqualTo: currentPhotoUid)
                                        .getDocuments(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) return Container();

                                      DocumentSnapshot user = snapshot.data.documents.first;

                                      String name = user['name'];
                                      if (name == null) name = 'Anonymous';

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Text(
                                          'posted by ${name}',
                                          textAlign: TextAlign.left,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                        ),
                                      );
                                    }),
                              ),
                              new Container(
                                padding: const EdgeInsets.all(20.0),
                                child: new Center(
                                  child: new DotsIndicator(
                                    controller: _pageController,
                                    itemCount: photos.length,
                                    onPageSelected: (int page) {
                                      _pageController.animateToPage(
                                        page,
                                        duration: Duration(milliseconds: 300),
                                        curve: Curves.ease,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        new Positioned(
                          top: 0.0,
                          left: 0.0,
                          right: 0.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              FutureBuilder<dynamic>(
                                future: currentEventPath != null
                                    ? Firestore.instance.document(currentEventPath).get()
                                    : Future.value(1),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData)
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  dynamic event = snapshot.data;
                                  EventType eventType = null;
                                  print('event: $event');

                                  if (!(event is DocumentSnapshot)) {
                                    event = null;
                                  } else {
                                    eventType = EventType.fromTitle(event['type']);
                                  }

                                  return AppBar(
                                    automaticallyImplyLeading: false,
                                    leading: CloseButton(),
                                    backgroundColor: Colors.transparent,
                                    title: event != null ? new Text(event['title']) : new Text('Hanging Out'),
                                    actions: <Widget>[
                                      IgnorePointer(
                                          ignoring: true,
                                          child: FloatingActionButton(
                                            heroTag: null,
                                            backgroundColor: eventType != null ? eventType.color : Colors.pink,
                                            mini: true,
                                            elevation: 0.0,
                                            child: Icon(
                                              eventType != null ? eventType.icon : Icons.nature_people,
                                              size: 20.0,
                                            ),
                                            onPressed: () {},
                                          ))
                                    ],
                                    elevation: 0.0,
                                  );
                                },
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  new Container(
                                    alignment: Alignment.centerRight,
                                    child: SaveButton(
                                      saver: () async {
                                        if (photos != null) {
                                          int currentPage = _pageController.page.toInt();
                                          DocumentSnapshot currentPhoto = photos[currentPage];

                                          CacheManager cacheManager =
                                              await CacheManager.getInstance('gs://trinity-orientation-2018-photos');
                                          File file = await cacheManager.getFile(currentPhoto['content']);

                                          dynamic result = await _methodChannel.invokeMethod(
                                            'saveImage',
                                            {
                                              'imagePath': file.path,
                                            },
                                          );

                                          return result;
                                        }
                                      },
                                    ),
                                  ),
                                  new FutureBuilder<FirebaseUser>(
                                      future: FirebaseAuth.instance.currentUser(),
                                      builder: (context, user) {
                                        if (user != null &&
                                            user.hasData &&
                                            (user.data.uid == currentPhotoUid || !user.data.isAnonymous)) {
                                          print('okay');
                                          return  IconButton(
                                            icon: Icon(Icons.delete),
                                            color: Colors.white,
                                            tooltip: 'Delete Photo',
                                            onPressed: () async {
                                              var result = await showDialog(
                                                context: context,
                                                builder: (context) => new AlertDialog(
                                                      title: new Text('Delete Photo?'),
                                                      actions: <Widget>[
                                                        new FlatButton(
                                                            onPressed: () {
                                                              Navigator.of(context).pop(false);
                                                            },
                                                            child: new Text('Cancel')),
                                                        new FlatButton(
                                                          onPressed: () {
                                                            Navigator.of(context).pop(true);
                                                          },
                                                          child: new Text(
                                                            'Delete',
                                                            style: new TextStyle(color: Colors.red),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                              );

                                              if ((result != null && result)) {
                                                Firestore.instance.runTransaction(
                                                  (transaction) async {
                                                    await transaction
                                                        .delete(photos[_pageController.page.toInt()].reference);

                                                    Navigator.pop(context);
                                                  },
                                                );
                                              }
                                            },
                                          );
                                        }

                                        return Container();
                                      }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _singlePhotoWidget(DocumentSnapshot photo) {
    return Container(
      child: CachedNetworkImage(
        imageUrl: photo['content'],
        fadeInDuration: Duration(milliseconds: 0),
        fadeOutDuration: Duration(milliseconds: 0),
        bucket: 'gs://trinity-orientation-2018-photos',
        fit: BoxFit.cover,
        placeholder: CachedNetworkImage(
          fadeInDuration: Duration(milliseconds: 300),
          fadeOutDuration: Duration(milliseconds: 0),
          bucket: 'gs://trinity-orientation-2018-photos',
          imageUrl: photo['med'],
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
