import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'schedule.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'photo_page.dart';
import 'dots_indicator.dart';
import 'firebase_cache/cached_firebase_image.dart';
import 'package:flutter/rendering.dart';
import 'firebase_cache/flutter_firebase_cache_manager.dart';
import 'package:flutter/services.dart';
import 'info.dart' as info;
import 'feed_page.dart';

List<CameraDescription> cameras;

Future<List<CameraDescription>> getCameras() async {
  if (cameras != null) {
    return cameras;
  } else {
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      print(e.description);
    }

    return cameras;
  }
}

class PhotosPage extends StatefulWidget {
  @override
  _PhotosPageState createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  final FirebaseStorage _firebaseStorage = FirebaseStorage(storageBucket: 'gs://trinity-orientation-2018-photos');

  PageController _pageController;

  List<dynamic> uploadTask;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: 1, viewportFraction: 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.pink.shade300, Colors.pink.shade100],
              begin: FractionalOffset.topLeft,
              end: FractionalOffset.bottomRight),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: Firestore.instance.collection('events').where('num_photos', isGreaterThan: 0).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.data == null) {
              return Center(child: CircularProgressIndicator());
            }

            List<DocumentSnapshot> startedEvents = snapshot.data.documents
                .where((snapshot) => (snapshot['date_start'] as Timestamp).toDate().isBefore(DateTime.now()))
                .toList();

            Map<DateTime, List<DocumentSnapshot>> eventsOnDays = {};

            for (DocumentSnapshot snapshot in startedEvents) {
              DateTime date = (snapshot['date_start'] as Timestamp).toDate();
              DateTime dateAsDay = DateTime(date.year, date.month, date.day);

              if (eventsOnDays[dateAsDay] == null) {
                eventsOnDays[dateAsDay] = List<DocumentSnapshot>();
              }
              eventsOnDays[dateAsDay].add(snapshot);
            }

            print(eventsOnDays);

            List<DateTime> days = eventsOnDays.keys.toList()
              ..sort(
                (first, second) {
                  return second.compareTo(first);
                },
              );

            return PageView.builder(
              controller: _pageController,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return buildFeedList(context);
                } else if (days.length == 0 && index == 1) {
                  return buildNoEventsPage(context);
                } else {
                  return buildGridPage(context, eventsOnDays[days[index - 1]]);
                }
              },
              itemCount: days.length + 1 + (days.length == 0 ? 1 : 0),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () async {
          if (uploadTask == null) {
            List<dynamic> snapshot = await Navigator.of(context).push<List<dynamic>>(
              MaterialPageRoute(
                builder: (context) {
                  return TakePhotoPage();
                },
                fullscreenDialog: false,
              ),
            );

            if (uploadTask != null) {
              setState(() => uploadTask = snapshot);

              await uploadTask[1];

              setState(() => uploadTask = null);
            }
          }
        },
        backgroundColor:
            uploadTask != null ? (uploadTask[0] != null ? (uploadTask[0] as EventType).color : Colors.pink) : null,
        child: uploadTask != null
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset('assets/ic_camera.png'),
              ),
      ),
    );
  }

  Widget buildFeedList(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          sliver: SliverToBoxAdapter(
            child: SafeArea(
              child: _eventPreviewCard(context, null),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: new Text(
            'Latest',
            textAlign: TextAlign.left,
            style: new TextStyle(color: Colors.white, fontSize: 40.0, fontWeight: FontWeight.w700),
          ),
        ),
        StreamBuilder(
          stream: Firestore.instance.collection('photos').orderBy('timestamp', descending: true).limit(50).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));

            if (snapshot.data.documents.length <= 0) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 128.0),
                    child: Text(
                      'No Photos Yet',
                      style:
                          TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w400, fontSize: 20.0),
                    ),
                  ),
                ),
              );
            }

            return SliverFixedExtentList(
              delegate: SliverChildBuilderDelegate((context, index) {
                DocumentSnapshot photo = snapshot.data.documents[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      GlobalKey<FeedPageState> feedPageKey = new GlobalKey<FeedPageState>();
                      Navigator.of(context).push(
                        PageRouteBuilder(
                            pageBuilder: (context, _, __) {
                              return FeedPage(key: feedPageKey, index: index);
                            },
                            transitionDuration: Duration(milliseconds: 200),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              if (feedPageKey.currentState?.animationStatus == AnimationStatus.completed) {
                                return child;
                              }
                              return ScaleTransition(
                                  scale: Tween<double>(begin: 0.0, end: 1.0)
                                      .animate(new CurvedAnimation(curve: Curves.ease, parent: animation)),
                                  child: child);
                            },
                            opaque: false),
                      );
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            CachedNetworkImage(
                              fadeInDuration: Duration(milliseconds: 200),
                              fadeOutDuration: Duration(milliseconds: 200),
                              imageUrl: photo['med'],
                              bucket: 'gs://trinity-orientation-2018-photos',
                              fit: BoxFit.cover,
                              placeholder: CachedNetworkImage(
                                fadeInDuration: Duration(milliseconds: 200),
                                fadeOutDuration: Duration(milliseconds: 200),
                                imageUrl: photo['low'],
                                bucket: 'gs://trinity-orientation-2018-photos',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }, childCount: snapshot.data.documents.length),
              itemExtent: 500.0,
            );
          },
        ),
      ],
    );
  }

  Widget buildNoEventsPage(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TrinSpace',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w600, fontSize: 48.0),
          ),
          Image.asset(
            'assets/logo.png',
            width: 256.0,
            height: 256.0,
            fit: BoxFit.contain,
          ),
          Text(
            'Once events start, share photos with \n your friends!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          )
        ]);
  }

  Widget buildGridPage(BuildContext context, List<DocumentSnapshot> events) {
    DateTime day = (events.first['date_start'] as Timestamp).toDate();
    day = DateTime(day.year, day.month, day.day);

    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          sliver: SliverAppBar(
            expandedHeight: 75.0,
            backgroundColor: Colors.transparent,
            elevation: 0.0,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                return FittedBox(
                  child: DayTitle(date: day),
                  alignment: Alignment.centerLeft,
                );
              },
            ),
            automaticallyImplyLeading: false,
            centerTitle: false,
          ),
        ),
        SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              return _eventPreviewCard(context, events[index]);
            }, childCount: events.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7))
      ],
    );
  }

  Future<List<dynamic>> getImageDownloadURLs(DocumentSnapshot photoDocument) {
    List<Future<dynamic>> downloadURLs = [
      _firebaseStorage.ref().child(photoDocument.data['low']).getDownloadURL(),
      _firebaseStorage.ref().child(photoDocument.data['med']).getDownloadURL()
    ];

    return Future.wait(downloadURLs);
  }

  Widget _eventPreviewCard(BuildContext context, DocumentSnapshot event) {
    EventType type = event != null ? EventType.fromTitle(event.data['type']) : null;

    return GestureDetector(
      onTap: () {
        GlobalKey<PhotoPageState> photoPageKey = new GlobalKey<PhotoPageState>();
        Navigator.of(context).push(
          PageRouteBuilder(
              pageBuilder: (context, _, __) {
                return PhotoPage(key: photoPageKey, event: event);
              },
              transitionDuration: Duration(milliseconds: 200),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                if (photoPageKey.currentState?.animationStatus == AnimationStatus.completed) {
                  return child;
                }
                return ScaleTransition(
                    scale: Tween<double>(begin: 0.0, end: 1.0)
                        .animate(new CurvedAnimation(curve: Curves.ease, parent: animation)),
                    child: child);
              },
              opaque: false),
        );
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: event != null
            ? Firestore.instance.document((event.data['latest_photo'] as DocumentReference).path).snapshots()
            : Firestore.instance
                .collection('photos')
                .where('event', isNull: true)
                .orderBy('timestamp', descending: false)
                .snapshots()
                .map((querySnapshot) => querySnapshot.documents.last),
        builder: (context, snapshot) {
          if (event == null) {
            print(snapshot.data);
          }

          if (!snapshot.hasData || snapshot.data.data == null) return Container();

          return Container(
            constraints: BoxConstraints.tightFor(height: 200.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CachedNetworkImage(
                      fadeInDuration: Duration(milliseconds: 200),
                      fadeOutDuration: Duration(milliseconds: 200),
                      imageUrl: snapshot.data['med'],
                      bucket: 'gs://trinity-orientation-2018-photos',
                      fit: BoxFit.cover,
                      placeholder: CachedNetworkImage(
                        fadeInDuration: Duration(milliseconds: 200),
                        fadeOutDuration: Duration(milliseconds: 200),
                        imageUrl: snapshot.data['low'],
                        bucket: 'gs://trinity-orientation-2018-photos',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.black.withOpacity(0.3), Colors.transparent],
                              stops: [0.0, 0.3],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter)),
                    ),
                    Positioned(
                      left: 0.0,
                      right: 0.0,
                      top: 0.0,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          event != null ? event['title'] : 'Just Hanging Out',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6), fontSize: 14.0, fontWeight: FontWeight.w400),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0.0,
                      bottom: 0.0,
                      child: IgnorePointer(
                        ignoring: true,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: FloatingActionButton(
                            heroTag: null,
                            onPressed: () {},
                            elevation: 10.0,
                            mini: true,
                            backgroundColor: type != null ? type.color : Colors.pink,
                            child: Icon(
                              type != null ? type.icon : Icons.nature_people,
                              size: 20.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TakePhotoPage extends StatefulWidget {
  @override
  _TakePhotoPageState createState() => _TakePhotoPageState();
}

class _TakePhotoPageState extends State<TakePhotoPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: FutureBuilder<List<CameraDescription>>(
        future: getCameras(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          return CameraPreviewController(cameras);
        },
      ),
    );
  }
}

class CameraPreviewController extends StatefulWidget {
  CameraPreviewController(this.cameras);

  final List<CameraDescription> cameras;

  @override
  _CameraPreviewState createState() => _CameraPreviewState();
}

class _CameraPreviewState extends State<CameraPreviewController> with SingleTickerProviderStateMixin {
  static const MethodChannel methodChannel = MethodChannel('com.tory.trinityOrientation/image');

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseStorage _firebaseStorage = FirebaseStorage(storageBucket: 'gs://trinity-orientation-2018-photos');

  AnimationController _filterController;

  String imagePath;
  String selectedFilter;
  int selectedIndex = 0;

  CameraController controller;
  Size cameraPreviewSize;
  bool uploading = false;
  bool selectingEvent = false;

  dynamic selectedEvent;

  int _cameraDescriptionIndex = 0;

  PersistentBottomSheetController _bottomSheetController;
  TextEditingController _nameController;

  @override
  void initState() {
    super.initState();

    _filterController = new AnimationController(vsync: this, duration: Duration(milliseconds: 500));

    _nameController = TextEditingController();
    onNewCameraSelected(widget.cameras[_cameraDescriptionIndex]);
  }

  @override
  void dispose() {
    controller?.dispose();
    _nameController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(child: _previewWidget()),
          Positioned(
            child: AnimatedBuilder(
              animation: _filterController,
              builder: (context, child) {
                return Opacity(
                  opacity: 1 - _filterController.value,
                  child: child,
                );
              },
              child: Center(
                child: Text(
                  'Swipe Left for Filters',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 20.0,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ),
          //Positioned.fill(child: _filterWidget()),
          Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            child: AppBar(
              elevation: 0.0,
              backgroundColor: Colors.transparent,
              automaticallyImplyLeading: true,
              leading: _appBarLeading(),
              actions: <Widget>[_cameraLensSelectionWidget()],
            ),
          ),
          Positioned(
            bottom: 0.0,
            left: 0.0,
            child: _uploadImageButton(),
          ),
        ],
      ),
      floatingActionButtonLocation: _actionButtonLocation(),
      floatingActionButton: _actionButton(),
    );
  }

  Widget _uploadImageButton() {
    if (imagePath != null) {
      return Container();
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: IconButton(
          color: Colors.white,
          icon: Icon(Icons.file_upload),
          onPressed: () async {
            File image = await ImagePicker.pickImage(source: ImageSource.gallery);
            setState(() {
              imagePath = image.path;
            });
          }),
    );
  }

  Widget _actionButton() {
    if (imagePath == null) {
      return _captureControlButton();
    } else if (!selectingEvent) {
      return _sendImageButton();
    } else {
      return _closeEventSelectionButton();
    }
  }

  FloatingActionButtonLocation _actionButtonLocation() {
    if (imagePath == null) {
      return FloatingActionButtonLocation.centerFloat;
    } else {
      return FloatingActionButtonLocation.endFloat;
    }
  }

  Widget _appBarLeading() {
    if (imagePath == null) {
      return null;
    } else if (!uploading) {
      return IconButton(
          color: Colors.white,
          icon: Icon(Icons.close),
          onPressed: () {
            if (selectingEvent) {
              Navigator.pop(context);
            }
            setState(() {
              selectingEvent = false;

              imagePath = null;
            });
          });
    } else {
      return Container();
    }
  }

  Widget _previewWidget() {
    if (imagePath == null) {
      return GestureDetector(
        onDoubleTap: () => _toggleCameraLens(),
        child: _cameraPreviewWidget(),
      );
    } else {
      return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.pink.shade300, Colors.pink.shade100],
                begin: FractionalOffset.topLeft,
                end: FractionalOffset.bottomRight),
          ),
          child: Image.file(
            File(imagePath),
            fit: BoxFit.fitWidth,
          ));
    }
  }

  Widget _filterWidget() {
    if (imagePath == null) {
      return StreamBuilder<QuerySnapshot>(
          stream: Firestore.instance.collection('filters').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            List<DocumentSnapshot> filters = snapshot.data.documents;

            return PageView.builder(
              onPageChanged: (index) {
                if (index > 0) {
                  setState(() {
                    selectedFilter = filters[index - 1]['path'];
                    selectedIndex = index;
                  });
                } else {
                  setState(() {
                    selectedFilter = null;
                    selectedIndex = 0;
                  });
                }
              },
              itemBuilder: (context, index) {
                if (index == 0) return Container();

                DocumentSnapshot snapshot = filters[index - 1];
                print(snapshot['path']);

                return CachedNetworkImage(
                  fadeInDuration: Duration(milliseconds: 200),
                  fadeOutDuration: Duration(milliseconds: 200),
                  imageUrl: snapshot['path'],
                  bucket: 'gs://trinity-orientation-2018.appspot.com',
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                  placeholder: new Center(child: CircularProgressIndicator()),
                );
              },
              itemCount: filters.length + 1,
              controller: PageController(initialPage: selectedIndex),
            );
          });
    } else {
      return Container();
    }
  }

  Widget _closeEventSelectionButton() {
    return FloatingActionButton(
      heroTag: null,
      onPressed: () {
        Navigator.of(context).pop();
      },
      mini: false,
      child: Icon(Icons.close),
    );
  }

  Widget _sendImageButton() {
    return FloatingActionButton(
      heroTag: null,
      onPressed: () async {
        if (imagePath == null) {
          print('cannot upload null image');
          return;
        } else if (uploading) {
          return;
        }

        _bottomSheetController = _scaffoldKey.currentState.showBottomSheet(_buildBottomSheet);
        setState(() {
          selectingEvent = true;
        });
        await _bottomSheetController.closed;
        setState(() {
          selectingEvent = false;
        });

        if (selectedEvent != null) {
          setState(() {
            uploading = true;
          });

          if (await info.isUserRegistered(context, _nameController, true)) {
            Navigator.of(context).pop([
              !(selectedEvent is int) ? EventType.fromTitle(selectedEvent['type']) : null,
              _uploadPicture(context, imagePath)
            ]);
          } else {
            setState(() => uploading = false);
          }
        }
      },
      backgroundColor: selectedEvent != null
          ? (selectedEvent is DocumentSnapshot
              ? EventType.fromTitle(selectedEvent['type']).color
              : Colors.pink.shade300)
          : null,
      child: uploading
          ? Padding(
              padding: const EdgeInsets.all(10.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(Icons.send),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    DateTime now = DateTime.now();
    //DateTime now = DateTime(2018, DateTime.september, 4, 17, 30);
    return StreamBuilder<QuerySnapshot>(
        stream: Firestore.instance.collection('events').where('date_start', isLessThanOrEqualTo: now).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              constraints: BoxConstraints.tightFor(width: 0.0, height: 0.0),
            );
          }

          List<DocumentSnapshot> events = snapshot.data.documents.where((snapshot) {
            return (snapshot['date_end'] as DateTime).isAfter(now);
          }).toList();

          List<Widget> children = [];

          print('found ${events.length} for bottom');

          for (int index = 0; index < events.length; index++) {
            DocumentSnapshot event = events[index];

            EventType type = EventType.fromTitle(event['type']);

            children.add(
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListTile(
                  onTap: () {
                    _bottomSheetController.close();

                    setState(() {
                      selectedEvent = event;
                    });
                  },
                  title: Text(event['title']),
                  leading: IgnorePointer(
                    ignoring: true,
                    child: FloatingActionButton(
                      onPressed: null,
                      heroTag: null,
                      child: Icon(
                        type.icon,
                        color: Colors.white,
                      ),
                      backgroundColor: type.color,
                    ),
                  ),
                ),
              ),
            );
          }

          children.add(
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListTile(
                onTap: () {
                  _bottomSheetController.close();

                  setState(() {
                    selectedEvent = 1;
                  });
                },
                title: Text('Just Hanging Out'),
                leading: IgnorePointer(
                  ignoring: true,
                  child: FloatingActionButton(
                    heroTag: null,
                    onPressed: null,
                    child: Icon(
                      Icons.nature_people,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.pink.shade300,
                  ),
                ),
              ),
            ),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.body2,
                        child: Opacity(
                            opacity: 0.5,
                            child: Text(
                              'What Are You Doing?',
                              textAlign: TextAlign.left,
                            ))),
                  )
                ] +
                children,
          );
        });
  }

  Widget _captureControlButton() {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 100.0, height: 100.0),
      child: GestureDetector(
        onLongPress: () {
          print('long press');
        },
        onTap: () async {
          print(selectedFilter);

          String path = await takePicture();
          print(selectedFilter);
          if (selectedFilter != null) {
            CacheManager cacheManager = await CacheManager.getInstance('gs://trinity-orientation-2018.appspot.com');
            File imageFile = await cacheManager.getFile(selectedFilter);

            path = await methodChannel.invokeMethod('addOverlayToImage', <String, dynamic>{
              'imagePath': path,
              'overlayPath': imageFile.path,
            });
          }

          print(path);

          setState(() {
            imagePath = path;
          });
        },
        child: Image.asset('assets/ic_camera.png'),
      ),
    );
  }

  Future<String> applyFilterToPicture(String path) async {
    CacheManager cacheManager = await CacheManager.getInstance('gs://trinity-orientation-2018.appspot.com');
    File imageFile = await cacheManager.getFile('filters/filter_2.png');

    final Uint8List bytes = await imageFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.Image image = (await codec.getNextFrame()).image;

    final ui.PictureRecorder recorder = new ui.PictureRecorder();
    final Canvas canvas = new Canvas(recorder);

    canvas.drawLine(
        Offset.zero,
        Offset(100.0, 100.0),
        new Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0);
    canvas.drawImage(image, Offset.zero, new Paint());

    ui.Picture picture = recorder.endRecording();
    ui.Image pictureToImage = await picture.toImage(image.width, image.height);
    ByteData data = await pictureToImage.toByteData(format: ui.ImageByteFormat.png);

    await new File(path).writeAsBytes(Uint8List.view(data.buffer));

    return path;
  }

  Future<StorageUploadTask> _uploadPicture(BuildContext context, String path) async {
    FirebaseUser user = await FirebaseAuth.instance.currentUser();

    final File file = File(path);

    final StorageReference ref = _firebaseStorage.ref().child('${user.uid}/${path.split('/').last}');

    String eventData = selectedEvent is int
        ? null
        : ((selectedEvent is DocumentSnapshot) ? (selectedEvent as DocumentSnapshot).documentID : null);

    return ref.putFile(file, StorageMetadata(contentType: 'image/jpeg', customMetadata: {'event': eventData}));
  }

  Widget _cameraLensSelectionWidget() {
    if (imagePath != null || controller == null || !controller.value.isInitialized) {
      return Container();
    } else {
      return IconButton(
        color: Colors.white,
        disabledColor: Colors.grey,
        icon: Icon(getCameraLensIcon(controller.description.lensDirection)),
        onPressed: () => _toggleCameraLens(),
      );
    }
  }

  void _toggleCameraLens() {
    _cameraDescriptionIndex++;
    if (_cameraDescriptionIndex >= widget.cameras.length) {
      _cameraDescriptionIndex = 0;
    }

    onNewCameraSelected(widget.cameras[_cameraDescriptionIndex]);
  }

  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      double width = MediaQuery.of(context).size.width;
      Size size = Size(width, width * (cameraPreviewSize.width / cameraPreviewSize.height));

      return Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.pink.shade300, Colors.pink.shade100],
                    begin: FractionalOffset.topLeft,
                    end: FractionalOffset.bottomRight),
              ),
            ),
          ),
          SizedBox(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CameraPreview(controller),
                _filterWidget(),
              ],
            ),
            width: size.width,
            height: size.height,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.pink.shade300, Colors.pink.shade100],
                    begin: FractionalOffset.topLeft,
                    end: FractionalOffset.bottomRight),
              ),
            ),
          ),
        ],
      );
    }
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      print('Error: cannot take photo without initializing camera.');
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/';
    Directory directory = await Directory(dirPath).create(recursive: true);

    List<FileSystemEntity> files = await directory.list(recursive: true).toList();
    for (FileSystemEntity entity in files) {
      await entity.delete(recursive: true);
    }

    final String filePath = '$dirPath/${DateTime.now().toIso8601String()}.jpg';

    if (controller.value.isTakingPicture) {
      return null;
    }

    File imageFile = File(filePath);
    bool exists = await imageFile.exists();
    if (exists) {
      await imageFile.delete(recursive: true);
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      print(e.description);
      return null;
    }

    return filePath;
  }

  IconData getCameraLensIcon(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.back:
        return Icons.camera_rear;
      case CameraLensDirection.front:
        return Icons.camera_front;
      case CameraLensDirection.external:
        return Icons.camera;
    }
    throw ArgumentError('Unknown lens direction');
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }

    if(_filterController.status == AnimationStatus.dismissed) {
      Future.delayed(Duration(seconds: 3, milliseconds: 500), () {
        _filterController.forward();
      });
    }

    controller = CameraController(cameraDescription, ResolutionPreset.high);

    controller.addListener(() {
      CameraValue value = controller.value;

      if (mounted)
        setState(() {
          cameraPreviewSize = value.previewSize;
        });
      if (controller.value.hasError) {
        print(controller.value.errorDescription);
      }
    });

    try {
      await controller.initialize();
    } on CameraException catch (e) {
      print(e.description);
    }

    if (mounted) {
      setState(() {});
    }
  }
}
