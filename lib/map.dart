import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'schedule.dart';
import 'event_page.dart';
import 'buildings.dart';

class MarkerSelectionController {
  Sink<GeoPoint> get markerSelectionInputSink => _markerSelectionInputController.sink;
  StreamController<GeoPoint> _markerSelectionInputController = new StreamController<GeoPoint>();

  Stream<GeoPoint> get markerSelectionOutputStream => _markerSelectionOutputController.stream;
  StreamController<GeoPoint> _markerSelectionOutputController = BehaviorSubject<GeoPoint>();

  Sink<String> get eventSelectionInputSink => _eventSelectionInputController.sink;
  StreamController<String> _eventSelectionInputController = new StreamController<String>();

  Stream<String> get eventSelectionOutputStream => _eventSelectionOutputController.stream;
  StreamController<String> _eventSelectionOutputController = BehaviorSubject<String>();

  MarkerSelectionController() {
    _eventSelectionInputController.stream.listen((title) {
      _eventSelectionOutputController.add(title);
    });

    _markerSelectionInputController.stream.listen((title) {
      _markerSelectionOutputController.add(title);
    });
  }
}

class MapTab {
  MapTab({
    this.body,
    TickerProvider vsync,
  }) : this.controller = new AnimationController(vsync: vsync, duration: Duration(milliseconds: 300)) {
    _animation = new CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);
  }

  final AnimationController controller;
  final Widget body;
  CurvedAnimation _animation;

  FadeTransition buildTransition(BuildContext context) {
    return new FadeTransition(opacity: _animation, child: body);
  }
}

class BuildingsMap extends StatefulWidget {
  BuildingsMap({@required this.documents});

  final List<DocumentSnapshot> documents;

  LatLng topRight;
  LatLng botLeft;

  @override
  _BuildingsMapState createState() => _BuildingsMapState();
}

class _BuildingsMapState extends State<BuildingsMap> with TickerProviderStateMixin {
  static final LatLng _kTrinityLatLng = new LatLng(43.6652, -79.3956);

  MarkerSelectionController markerSelectionController;
  MapController mapController;

  List<AnimationController> markerControllers = [];

  DocumentSnapshot selectedBuilding;

  @override
  void initState() {
    super.initState();

    mapController = MapController();
    mapController.onReady.then((_) {
      if (widget.topRight != null && widget.botLeft != null) {
        mapController.fitBounds(new LatLngBounds(widget.topRight, widget.botLeft));
      } else {
        mapController.move(_kTrinityLatLng, 16.5);
      }
    });

    markerSelectionController = MarkerSelectionController();
  }

  @override
  Widget build(BuildContext context) {
    List<CustomMarker> markers = [];

    if (selectedBuilding != null) {
      GeoPoint geoPoint = selectedBuilding['location'];
      LatLng position = new LatLng(geoPoint.latitude, geoPoint.longitude);

      BuildingMapMarker marker = new BuildingMapMarker(
        building: selectedBuilding,
        selectionController: markerSelectionController,
        tapDelegate: () {},
        vsync: this,
      );

      markers.add(
        new CustomMarker(
          point: position,
          width: 500.0,
          height: 60.0,
          anchor: AnchorPos.top,
          builder: (context) {
            return marker;
          },
        ),
      );
    }

    return Stack(
      children: <Widget>[
        new FlutterMap(
          options: new MapOptions(
            zoom: 13.0,
            center: _kTrinityLatLng,
            plugins: [
              new CustomMapMarkersPlugin(),
            ],
          ),
          mapController: mapController,
          layers: [
            new TileLayerOptions(
              keepBuffer: 6,
              urlTemplate: "https://api.tiles.mapbox.com/v4/"
                  "{id}/{z}/{x}/{y}@2x.png?access_token={accessToken}",
              additionalOptions: {
                'accessToken':
                    'pk.eyJ1IjoibWF0dGhld3RvcnkiLCJhIjoiY2pleDU3czl6MDI3YTJ6bms5ZnA0cWF1YyJ9.8_zTUzsIjhhucc2K0n-_Fg',
                'id': 'mapbox.streets',
              },
            ),
            new CustomMapMarkersLayerOptions(markers: markers),
            //new MarkerLayerOptions(markers: markers),
          ],
        ),
        new Positioned(
            bottom: 16.0,
            right: 16.0,
            child: new FloatingActionButton(
              onPressed: () async {
                final DocumentSnapshot selected = await showSearch<DocumentSnapshot>(
                  context: context,
                  delegate: new BuildingSearchDelegate(buildings: widget.documents),
                );

                if (selected != null) {
                  GeoPoint location = selected['location'];
                  mapController.move(new LatLng(location.latitude, location.longitude), 17.75);
                  setState(() {
                    selectedBuilding = selected;
                  });
                }
              },
              child: new Icon(Icons.search),
              backgroundColor: Colors.white,
              foregroundColor: Colors.pink,
            )),
      ],
    );
  }
}

class EventsMap extends StatefulWidget {
  EventsMap({this.documents})
      : eventsOnDay = [],
        eventsAtLocations = {} {
    for (DocumentSnapshot event in documents) {
      eventsOnDay.add(event);
      GeoPoint thisLocation = event['location'];

      if (!eventsAtLocations.containsKey(thisLocation)) {
        eventsAtLocations[thisLocation] = new List<DocumentSnapshot>();
      }

      eventsAtLocations[thisLocation].add(event);
    }

    for (GeoPoint location in eventsAtLocations.keys) {
      if (topRight == null || location.latitude < topRight.latitude) {
        topRight = new LatLng(location.latitude, topRight != null ? topRight.longitude : location.longitude);
      }

      if (topRight == null || location.longitude > topRight.longitude) {
        topRight = new LatLng(topRight != null ? topRight.latitude : location.latitude, location.longitude);
      }

      if (botLeft == null || location.latitude > botLeft.latitude) {
        botLeft = new LatLng(location.latitude, botLeft != null ? botLeft.longitude : location.longitude);
      }

      if (botLeft == null || location.longitude < botLeft.longitude) {
        botLeft = new LatLng(botLeft != null ? botLeft.latitude : location.latitude, location.longitude);
      }
    }
  }

  final List<DocumentSnapshot> documents;
  final List<DocumentSnapshot> eventsOnDay;
  final Map<GeoPoint, List<DocumentSnapshot>> eventsAtLocations;

  LatLng topRight;
  LatLng botLeft;

  @override
  _EventsMapState createState() => _EventsMapState();
}

class _EventsMapState extends State<EventsMap> {
  static final LatLng _kTrinityLatLng = new LatLng(43.6652, -79.3956);

  MarkerSelectionController markerSelectionController;
  MapController mapController;

  @override
  void initState() {
    super.initState();

    mapController = MapController();
    mapController.onReady.then((_) {
      if (widget.topRight != null && widget.botLeft != null) {
        mapController.fitBounds(new LatLngBounds(widget.topRight, widget.botLeft));
      } else {
        mapController.move(_kTrinityLatLng, 8.0);
      }
    });
    markerSelectionController = MarkerSelectionController();
  }

  @override
  Widget build(BuildContext context) {
    List<CustomMarker> multipleLocationMarkers = widget.eventsAtLocations.keys.map((geoPoint) {
      List<DocumentSnapshot> eventsAtLocation = widget.eventsAtLocations[geoPoint];

      LatLng position = new LatLng(geoPoint.latitude, geoPoint.longitude);

      if (eventsAtLocation.length > 1) {
        return new CustomMarker(
            width: 500.0,
            height: 55.0,
            anchor: AnchorPos.top,
            point: position,
            builder: (context) {
              return AnimatedMarkerMultipleEvents(eventsAtLocation, markerSelectionController);
            });
      } else {
        return new CustomMarker(
            width: 500.0,
            height: 60.0,
            anchor: AnchorPos.top,
            point: position,
            builder: (context) {
              return AnimatedMarker(eventsAtLocation.first, markerSelectionController);
            });
      }
    }).toList();

    return new FlutterMap(
      options: new MapOptions(
        zoom: 13.0,
        center: _kTrinityLatLng,
        plugins: [
          new CustomMapMarkersPlugin(),
        ],
      ),
      mapController: mapController,
      layers: [
        new TileLayerOptions(
          keepBuffer: 6,
          urlTemplate: "https://api.tiles.mapbox.com/v4/"
              "{id}/{z}/{x}/{y}@2x.png?access_token={accessToken}",
          additionalOptions: {
            'accessToken':
                'pk.eyJ1IjoibWF0dGhld3RvcnkiLCJhIjoiY2pleDU3czl6MDI3YTJ6bms5ZnA0cWF1YyJ9.8_zTUzsIjhhucc2K0n-_Fg',
            'id': 'mapbox.streets',
          },
        ),
        new CustomMapMarkersLayerOptions(markers: multipleLocationMarkers),
        //new MarkerLayerOptions(markers: markers),
      ],
    );
  }
}

class MapTabEvents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();

    DateTime todayStart = new DateTime(now.year, now.month, now.day);
    DateTime todayEnd = new DateTime(now.year, now.month, now.day, 23, 59, 59, 59);

    return StreamBuilder(
      stream: Firestore.instance
          .collection('events')
          .where('date_start', isGreaterThanOrEqualTo: todayStart, isLessThanOrEqualTo: todayEnd)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data.documents.length > 0) {
            return new EventsMap(documents: snapshot.data.documents);
          } else {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade300, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'No Events Today',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontSize: 20.0),
              ),
            );
          }
        } else {
          return new Container(alignment: FractionalOffset.center, child: new CircularProgressIndicator());
        }
      },
    );
  }
}

class MapTabBuildings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance.collection('buildings').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return new BuildingsMap(documents: snapshot.data.documents);
        } else {
          return new Center(child: new CircularProgressIndicator());
        }
      },
    );
  }
}

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  List<MapTab> _items;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _items = [
      new MapTab(
        body: new MapTabEvents(),
        vsync: this,
      ),
      new MapTab(
        body: MapTabBuildings(),
        vsync: this,
      )
    ];

    for (MapTab view in _items) view.controller.addListener(_rebuild);

    _items[_currentIndex].controller.value = 1.0;
  }

  void _rebuild() {
    setState(() {});
  }

  @override
  void dispose() {
    for (MapTab tab in _items) {
      tab.controller.dispose();
    }
    super.dispose();
  }

  Widget _buildPageStack() {
    final List<Widget> transitions = <Widget>[];

    for (int i = 0; i < _items.length; i++)
      transitions.add(IgnorePointer(ignoring: _currentIndex != i, child: _items[i].buildTransition(context)));

    return new Stack(children: transitions);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
        children: <Widget>[
          _buildPageStack(),
          new Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            child: new AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0.0,
              centerTitle: true,
              title: new MapTypeSelector(
                items: ['Today', 'Buildings'],
                currentIndex: _currentIndex,
                onTap: (int) {
                  setState(
                    () {
                      _items[_currentIndex].controller.reverse();
                      _currentIndex = int;
                      _items[_currentIndex].controller.forward();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BuildingSearchDelegate extends SearchDelegate<DocumentSnapshot> {
  BuildingSearchDelegate({@required this.buildings});

  final List<DocumentSnapshot> buildings;

  @override
  Widget buildSuggestions(BuildContext context) {
    List<DocumentSnapshot> items = buildings.where((snapshot) {
      return (snapshot['name'] as String).toUpperCase().contains(query.toUpperCase()) ||
          snapshot['code'].contains(query.toUpperCase());
    }).toList()
      ..sort((a, b) {
        if (a['code'] == query.toUpperCase()) return -1;
        if (b['code'] == query.toUpperCase()) return 1;

        return 0;
      });

    return new ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        return new ListTile(
          leading: new Text(items[index]['code']),
          title: new Text(items[index]['name']),
          onTap: () {
            close(context, items[index]);
          },
        );
      },
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return <Widget>[
      query.isEmpty
          ? new Container()
          : new IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear),
              onPressed: () {
                query = '';
                showSuggestions(context);
              },
            )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return new IconButton(
      tooltip: 'Back',
      icon: new AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }
}

class MapTypeSelector extends StatefulWidget {
  MapTypeSelector({@required this.items, @required this.currentIndex, @required this.onTap});

  final List<String> items;

  final Function(int) onTap;

  final int currentIndex;

  @override
  _MapTypeSelectorState createState() => _MapTypeSelectorState();
}

class _MapTypeSelectorState extends State<MapTypeSelector> with SingleTickerProviderStateMixin {
  AnimationController _controller;
  final double _kIndicatorWidth = 90.0;
  final double _kIndicatorHeight = 40.0;

  static final GlobalKey _rowKey = new GlobalKey();

  int oldIndex;

  @override
  void initState() {
    super.initState();

    _controller = new AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    oldIndex = widget.currentIndex;
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  double get _indicatorWidth {
    if (_rowKey.currentContext != null) {
      final RenderBox renderBox = _rowKey.currentContext.findRenderObject();
      return renderBox.size.width / widget.items.length;
    } else {
      return _kIndicatorWidth;
    }
  }

  Animation get _slideAnimation {
    double indicatorWidth = _indicatorWidth;

    return new RelativeRectTween(
      begin: new RelativeRect.fromRect(Rect.fromLTWH(oldIndex * indicatorWidth, 0.0, indicatorWidth, _kIndicatorHeight),
          Rect.fromLTRB(0.0, 0.0, indicatorWidth * widget.items.length, _kIndicatorHeight)),
      end: new RelativeRect.fromRect(
          Rect.fromLTWH(widget.currentIndex * indicatorWidth, 0.0, indicatorWidth, _kIndicatorHeight),
          Rect.fromLTRB(0.0, 0.0, indicatorWidth * widget.items.length, _kIndicatorHeight)),
    ).animate(new CurvedAnimation(parent: _controller, curve: Curves.ease));
  }

  @override
  void didUpdateWidget(MapTypeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIndex != widget.currentIndex) {
      oldIndex = oldWidget.currentIndex;

      _controller.reset();
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Card(
      shape: new RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kIndicatorHeight / 2.0)),
      child: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Stack(
          children: <Widget>[
            new Row(
              key: _rowKey,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.items.map((string) {
                return GestureDetector(
                  onTap: () {
                    widget.onTap(widget.items.indexOf(string));
                  },
                  child: Container(
                    width: _kIndicatorWidth,
                    height: _kIndicatorHeight,
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: new Text(string,
                          style: new TextStyle(color: Colors.black.withOpacity(0.25)), textAlign: TextAlign.center),
                    ),
                  ),
                );
              }).toList(),
            ),
            new PositionedTransition(
              rect: _slideAnimation,
              child: new Card(
                color: Colors.pink,
                shape: new RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kIndicatorHeight / 2.0)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Container(
                    child: new _CrossFadeTransition(
                      progress: _controller,
                      child1: new Text(
                        widget.items[oldIndex],
                        style: new TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
                      ),
                      child0: new Text(
                        widget.items[widget.currentIndex],
                        style: new TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
                      ),
                    ),
                    alignment: Alignment.center,
                    width: _kIndicatorWidth,
                    height: _kIndicatorHeight,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _CrossFadeTransition extends AnimatedWidget {
  const _CrossFadeTransition({
    Key key,
    this.alignment = Alignment.center,
    Animation<double> progress,
    this.child0,
    this.child1,
  }) : super(key: key, listenable: progress);

  final AlignmentGeometry alignment;
  final Widget child0;
  final Widget child1;

  @override
  Widget build(BuildContext context) {
    final Animation<double> progress = listenable;

    final double opacity1 = new CurvedAnimation(
      parent: new ReverseAnimation(progress),
      curve: const Interval(0.5, 1.0),
    ).value;

    final double opacity2 = new CurvedAnimation(
      parent: progress,
      curve: const Interval(0.5, 1.0),
    ).value;

    return new Stack(
      alignment: alignment,
      children: <Widget>[
        new Opacity(
          opacity: opacity1,
          child: new Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            child: child1,
          ),
        ),
        new Opacity(
          opacity: opacity2,
          child: new Semantics(
            scopesRoute: true,
            explicitChildNodes: true,
            child: child0,
          ),
        ),
      ],
    );
  }
}

typedef void MarkerTapCallback();

class AnimatedMarkerMultipleEvents extends StatefulWidget {
  AnimatedMarkerMultipleEvents(this.events, this.selectionController);

  final List<DocumentSnapshot> events;
  final MarkerSelectionController selectionController;

  @override
  _AnimatedMarkerMultipleEventsState createState() => _AnimatedMarkerMultipleEventsState();
}

class _AnimatedMarkerMultipleEventsState extends State<AnimatedMarkerMultipleEvents>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  List<Animation<RelativeRect>> buttonAnimations;

  StreamSubscription selectionSub;

  @override
  void initState() {
    super.initState();

    _controller = new AnimationController(duration: Duration(milliseconds: 300), vsync: this);

    buttonAnimations = [];

    CurvedAnimation expandCurve = new CurvedAnimation(parent: _controller, curve: Curves.ease);

    for (int i = 0; i < widget.events.length; i++) {
      double fromLeftAtEnd = MarkerIndicatorCircle.kMarkerIndicatorSizeWithPadding * i;
      double fromRightAtEnd = MarkerIndicatorCircle.kMarkerIndicatorSizeWithPadding * (widget.events.length - i - 1);
      double fromTopAtStart =
          MarkerIndicatorCircle.kMarkerIndicatorSizeWithPadding * 0.1 * (widget.events.length - i - 1);
      buttonAnimations.add(new RelativeRectTween(
              begin: new RelativeRect.fromLTRB(0.0, -(fromTopAtStart), 0.0, 0.0),
              end: new RelativeRect.fromLTRB(fromLeftAtEnd, 0.0, fromRightAtEnd, 0.0))
          .animate(expandCurve));
    }

    selectionSub = widget.selectionController.markerSelectionOutputStream.listen((geoPoint) {
      if (geoPoint == widget.events.first['location']) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedMarkerMultipleEvents oldWidget) {
    super.didUpdateWidget(oldWidget);

    selectionSub.cancel();
    selectionSub = widget.selectionController.markerSelectionOutputStream.listen((geoPoint) {
      if (geoPoint == widget.events.first['location']) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    selectionSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    for (int i = 0; i < widget.events.length; i++) {
      children.add(
        PositionedTransition(
          rect: buttonAnimations[i],
          child: new AnimatedMarker(
            widget.events[i],
            widget.selectionController,
            showDot: false,
          ),
        ),
      );
    }

    EventType firstType = EventType.fromTitle(widget.events.first['type']);
    EventType lastType = EventType.fromTitle(widget.events.last['type']);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Flexible(
          flex: 1,
          child: Stack(
            fit: StackFit.loose,
            overflow: Overflow.visible,
            children: children,
          ),
        ),
        Padding(
          padding: new EdgeInsets.only(top: _controller.value * 2.0),
          child: Container(
            width: 5.0,
            height: 5.0,
            decoration: new BoxDecoration(
              gradient: new LinearGradient(colors: [firstType.color, lastType.color]),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class AnimatedMarker extends StatefulWidget {
  AnimatedMarker(this.event, this.selectionController, {this.tapDelegate, this.showDot = true});

  final DocumentSnapshot event;
  final MarkerSelectionController selectionController;
  final MarkerTapCallback tapDelegate;
  final bool showDot;

  @override
  _AnimatedMarkerState createState() => _AnimatedMarkerState();
}

class _AnimatedMarkerState extends State<AnimatedMarker> with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<Color> animation;

  StreamSubscription markerSelectionSub;
  StreamSubscription eventSelectionSub;

  @override
  void initState() {
    super.initState();

    _controller = new AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    animation = new ColorTween(begin: Colors.red, end: Colors.blue).animate(_controller);

    if (widget.selectionController != null) {
      markerSelectionSub = widget.selectionController.markerSelectionOutputStream.listen((geoPoint) {
        if (geoPoint == widget.event['location']) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      });

      eventSelectionSub = widget.selectionController.eventSelectionOutputStream.listen((title) {
        if (title == widget.event['title']) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    markerSelectionSub?.cancel();
    eventSelectionSub?.cancel();

    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new GrowTransition(
      widget.showDot,
      event: widget.event,
      selectionController: widget.selectionController,
      child: new MarkerIndicatorCircle(
        listenable: _controller,
        event: EventType.fromTitle(widget.event['type']),
      ),
      animation: _controller,
    );
  }
}

class GrowTransition extends AnimatedWidget {
  GrowTransition(this.showDot, {this.child, this.animation, @required this.event, @required this.selectionController})
      : scaleAnimation =
            new Tween(begin: 1.0, end: 1.5).animate(new CurvedAnimation(parent: animation, curve: Curves.ease)),
        opacityAnimation = new Tween(begin: 0.0, end: 1.0)
            .animate(new CurvedAnimation(parent: animation, curve: new Interval(0.75, 1.0, curve: Curves.easeInOut))),
        type = EventType.fromTitle(event['type']),
        slideAnimation = new Tween<Offset>(begin: new Offset(0.0, 0.0), end: new Offset(0.0, -0.7)).animate(animation),
        super(listenable: animation);

  final Widget child;
  final Animation<double> animation;
  final DocumentSnapshot event;
  final bool showDot;
  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;
  final EventType type;
  final Animation<Offset> slideAnimation;
  final MarkerSelectionController selectionController;

  Widget build(BuildContext context) {
    List<Widget> children = [
      Transform.scale(scale: scaleAnimation.value, alignment: Alignment.bottomCenter, child: child),
    ];

    if (showDot) {
      children.add(
        Padding(
          padding: new EdgeInsets.only(top: scaleAnimation.value * 2.0),
          child: Container(
            width: 5.0,
            height: 5.0,
            decoration: new BoxDecoration(
              color: type.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.loose,
      alignment: Alignment.center,
      overflow: Overflow.visible,
      children: <Widget>[
        IgnorePointer(
          ignoring: true,
          child: SlideTransition(
            position: slideAnimation,
            child: Opacity(
              opacity: opacityAnimation.value,
              child: new Container(
                alignment: Alignment.topCenter,
                child: Container(
                  decoration: new BoxDecoration(
                    color: Colors.white,
                    borderRadius: new BorderRadius.circular(4.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: new Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        new Text(event['title']),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (animation.status == AnimationStatus.dismissed) {
              selectionController?.markerSelectionInputSink?.add(event['location']);
              selectionController?.eventSelectionInputSink?.add(event['title']);
            } else {
              Navigator.push(
                context,
                new MyCoolPageRoute(
                  fullscreenDialog: true,
                  builder: (context) {
                    return new EventPage(event);
                  },
                ),
              );
            }
          },
          child: Container(
            width: 50.0,
            height: 200.0,
            constraints: const BoxConstraints(minWidth: 50.0, minHeight: 200.0),
          ),
        )
      ],
    );
  }
}

class MarkerIndicatorCircle extends StatelessWidget {
  static final double kMarkerIndicatorSize = 36.0;
  static final double kMarkerIndicatorSizeWithPadding = 50.0;

  MarkerIndicatorCircle({Key key, @required this.event, @required this.listenable}) : super(key: key);

  final EventType event;
  final Animation<double> listenable;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: new RawMaterialButton(
        fillColor: event.color,
        shape: const CircleBorder(),
        constraints: new BoxConstraints(minHeight: kMarkerIndicatorSize, minWidth: kMarkerIndicatorSize),
        child: _CrossFadeTransition(
          progress: listenable,
          child1: new Icon(
            event.icon,
            color: Colors.white,
            size: 18.0,
          ),
          child0: new Icon(
            Icons.arrow_forward,
            color: Colors.white,
            size: 18.0,
          ),
        ),
        onPressed: () {},
      ),
    );
  }
}

class CustomMapMarkersPlugin extends MapPlugin {
  @override
  bool supportsLayer(LayerOptions options) {
    return options is CustomMapMarkersLayerOptions;
  }

  @override
  Widget createLayer(LayerOptions options, MapState mapState) {
    return new CustomMapMarkerLayer(options, mapState);
  }
}

class CustomMapMarkersLayerOptions extends LayerOptions {
  CustomMapMarkersLayerOptions({this.markers = const []});

  final List<CustomMarker> markers;
}

class CustomAnchor {
  final double left;
  final double top;

  CustomAnchor(this.left, this.top);

  CustomAnchor._(double width, double height, AnchorPos anchor)
      : left = _leftOffset(width, anchor),
        top = _topOffset(width, anchor);

  static double _leftOffset(double width, AnchorPos anchor) {
    switch (anchor) {
      case AnchorPos.left:
        return 0.0;
      case AnchorPos.right:
        return width;
      case AnchorPos.top:
      case AnchorPos.bottom:
      case AnchorPos.center:
      default:
        return width / 2;
    }
  }

  static double _topOffset(double height, AnchorPos anchor) {
    switch (anchor) {
      case AnchorPos.top:
        return 0.0;
      case AnchorPos.bottom:
        return height;
      case AnchorPos.left:
      case AnchorPos.right:
      case AnchorPos.center:
      default:
        return height / 2;
    }
  }
}

class CustomMarker {
  final LatLng point;
  final WidgetBuilder builder;
  final double width;
  final double height;
  final CustomAnchor _anchor;

  CustomMarker({
    this.point,
    this.builder,
    this.width = 30.0,
    this.height = 30.0,
    AnchorPos anchor,
    CustomAnchor anchorOverride,
  }) : this._anchor = anchorOverride ?? new CustomAnchor._(width, height, anchor);
}

class CustomMapMarkerLayer extends StatelessWidget {
  final CustomMapMarkersLayerOptions markerOpts;
  final MapState map;

  CustomMapMarkerLayer(this.markerOpts, this.map);

  @override
  Widget build(BuildContext context) {
    List<Widget> markers = [];

    for (CustomMarker markerOpt in this.markerOpts.markers) {
      var pos = map.project(markerOpt.point);
      var bounds = map.getPixelBounds(map.zoom);
      var latlngBounds = new LatLngBounds(map.unproject(bounds.bottomLeft), map.unproject(bounds.topRight));
      pos = pos.multiplyBy(map.getZoomScale(map.zoom, map.zoom)) - map.getPixelOrigin();

      var pixelPosX = (pos.x - (markerOpt.width - markerOpt._anchor.left)).toDouble();
      var pixelPosY = (pos.y - (markerOpt.height - markerOpt._anchor.top)).toDouble();

      markers.add(
        new Positioned(
          key: new ValueKey(markerOpt.point),
          width: markerOpt.width,
          height: markerOpt.height,
          left: pixelPosX,
          top: pixelPosY,
          child: markerOpt.builder(context),
        ),
      );
    }

    return new Container(
      child: new Stack(
        children: markers,
      ),
    );
  }
}
