import 'package:flutter/material.dart';
import 'map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'event_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'utils.dart';

class BuildingMapMarker extends StatefulWidget {

  BuildingMapMarker({Key key, @required this.building, @required this.selectionController, @required this.tapDelegate, this.vsync}) : super(key: key);

  final DocumentSnapshot building;
  final MarkerSelectionController selectionController;
  final MarkerTapCallback tapDelegate;
  final TickerProvider vsync;

  bool selected = false;

  @override
  _BuildingMapMarkerState createState() => _BuildingMapMarkerState();
}

class _BuildingMapMarkerState extends State<BuildingMapMarker> {
  static final double kMarkerIndicatorSize = 36.0;

  AnimationController controller;

  StreamSubscription _buildingSelectionSub;

  @override
  void initState() {
    super.initState();

    controller = new AnimationController(vsync: widget.vsync, duration: const Duration(milliseconds: 300));

    _buildingSelectionSub = widget.selectionController.eventSelectionOutputStream.listen((title) {
      if (title == widget.building['name']) {
        controller.forward();
      } else {
        controller.reverse();
      }
    });
  }

  @override
  void didUpdateWidget(BuildingMapMarker oldWidget) {
    super.didUpdateWidget(oldWidget);

    _buildingSelectionSub = widget.selectionController.eventSelectionOutputStream.listen((title) {
      if (title == widget.building['name']) {
        controller.forward();
      } else {
        controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _buildingSelectionSub.cancel();
    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //print('${controller.value} for ${widget.building['name']}');

    return new BuildingMapMarkerGrowTransition(
        child: new IgnorePointer(
          ignoring: true,
          child: new RawMaterialButton(
            fillColor: colorForBuildingCode('A'),
            shape: const CircleBorder(),
            constraints: new BoxConstraints(minHeight: kMarkerIndicatorSize, minWidth: kMarkerIndicatorSize),
            child: _CrossFadeTransition(
              progress: controller,
              child1: new Icon(
                Icons.domain,
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
        ),
        animation: controller,
        building: widget.building,
        selectionController: widget.selectionController);
  }
}

class BuildingMapMarkerGrowTransition extends AnimatedWidget {
  BuildingMapMarkerGrowTransition(
      {@required this.child, @required this.animation, @required this.building, @required this.selectionController})
      : scaleAnimation =
            new Tween(begin: 1.0, end: 1.5).animate(new CurvedAnimation(parent: animation, curve: Curves.ease)),
        opacityAnimation = new Tween(begin: 0.0, end: 1.0)
            .animate(new CurvedAnimation(parent: animation, curve: new Interval(0.75, 1.0, curve: Curves.easeInOut))),
        slideAnimation = new Tween<Offset>(begin: new Offset(0.0, 0.0), end: new Offset(0.0, -0.7)).animate(animation),
        super(listenable: animation);

  final Widget child;
  final Animation<double> animation;
  final DocumentSnapshot building;
  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;
  final Animation<Offset> slideAnimation;
  final MarkerSelectionController selectionController;

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      Transform.scale(scale: scaleAnimation.value, alignment: Alignment.bottomCenter, child: child),
      Padding(
        padding: new EdgeInsets.only(top: scaleAnimation.value * 2.0),
        child: Container(
          width: 5.0,
          height: 5.0,
          decoration: new BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ];

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
                        new Text(building['name']),
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
              selectionController.markerSelectionInputSink.add(building['location']);
              selectionController.eventSelectionInputSink.add(building['name']);
            } else {
              openMaps(context, building['location'], building['name']);

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

Color colorForBuildingCode(String code) {
  int letterOfAlphabet = code[0].codeUnitAt(0);

  return Colors.teal.shade400;
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