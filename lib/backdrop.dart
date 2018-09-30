import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'bloc/schedule_provider.dart';
import 'schedule.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'bloc/scroll_bloc.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';

import 'package:path_drawing/path_drawing.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'dart:ui';

const double _kBackAppBarHeight = 56.0;

class BackAppBar extends StatelessWidget {
  const BackAppBar({Key key, this.leading, @required this.title, this.trailing})
      : assert(title != null),
        super(key: key);

  final Widget leading;
  final Widget title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];

    if (leading != null) {
      children.add(new Container(
        alignment: Alignment.center,
        width: 56.0,
        child: leading,
      ));
    }

    children.add(new Expanded(child: title));

    if (trailing != null) {
      children.add(new Container(
        alignment: Alignment.center,
        width: 56.0,
        child: trailing,
      ));
    }

    return new SizedBox(
      height: _kBackAppBarHeight,
      child: new Row(
        children: children,
      ),
    );
  }
}

typedef Widget PhysicsProvidedWidgetBuilder(ScrollPhysics physics);

class BackDrop extends StatefulWidget {
  BackDrop({Key key, this.backLayer, this.backTitle, this.frontLayer, this.frontLayerScrollBuilder, this.scrollBloc})
      : super(key: key);

  final Widget backLayer;
  final Widget backTitle;
  final MyFrontLayer frontLayer;
  final PhysicsProvidedWidgetBuilder frontLayerScrollBuilder;
  final ScrollBloc scrollBloc;

  @override
  BackDropState createState() => new BackDropState();
}

class BackDropState extends State<BackDrop> with SingleTickerProviderStateMixin {
  final GlobalKey _backdropKey = new GlobalKey();

  AnimationController _controller;

  double t = 0.0001;

  bool ignorePointer = false;

  Widget listView;

  StreamSubscription<ScrollState> scrollStateSubscription;
  StreamSubscription<double> initialHorizontalScrollProgressSubscription;

  @override
  void initState() {
    super.initState();

    _controller = new AnimationController(duration: const Duration(milliseconds: 500), vsync: this, value: 1.0);
    _controller.addListener(onControllerChange);

    scrollStateSubscription = widget.scrollBloc.scrollStateOutput.listen(onScrollStateChange);

    initialHorizontalScrollProgressSubscription = widget.scrollBloc.horizontalScrollOutput.listen((value) {
      setState(() {
        t = value;
      });
    });

    listView = widget.frontLayerScrollBuilder(new MyScrollPhysics(
        controller: _controller,
        backdrop: () {
          return _backdropHeight;
        }));
  }

  void onControllerChange() {
    widget.scrollBloc.progressInput.add(_controller.value);
  }

  void onScrollStateChange(ScrollState state) {
    print('$state');
    switch (state) {
      case ScrollState.Open:
        show();
        break;
      case ScrollState.Closed:
        hide();
        break;
    }
  }

  @override
  void dispose() {
    scrollStateSubscription.cancel();
    initialHorizontalScrollProgressSubscription.cancel();

    _controller.removeListener(onControllerChange);
    _controller.dispose();

    super.dispose();
  }

  void show() {
    final AnimationStatus status = _controller.status;
    final bool isOpen = status == AnimationStatus.completed || status == AnimationStatus.forward;
    _controller.fling(velocity: -0.5);
  }

  void hide() {
    final AnimationStatus status = _controller.status;
    final bool isOpen = status == AnimationStatus.completed || status == AnimationStatus.forward;
    _controller.fling(velocity: 0.5);
  }

  double get _backdropHeight {
    final RenderBox renderBox = _backdropKey.currentContext.findRenderObject();
    return math.max(0.0, renderBox.size.height - _kBackAppBarHeight);
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    _controller.value += details.primaryDelta / (_backdropHeight ?? details.primaryDelta);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_controller.isAnimating || _controller.status == AnimationStatus.completed) return;

    if (details == null) {
      _controller.fling(velocity: -2.0);
      return;
    }
    final double flingVelocity = details.velocity.pixelsPerSecond.dy / _backdropHeight;
    if (flingVelocity < 0.0)
      _controller.fling(velocity: math.max(-2.0, flingVelocity));
    else if (flingVelocity > 0.0)
      _controller.fling(velocity: math.min(2.0, flingVelocity));
    else
      _controller.fling(velocity: _controller.value < 0.5 ? -2.0 : 2.0);
  }

  Widget _buildStack(BuildContext context, BoxConstraints boxConstraints) {
    final Animation<RelativeRect> frontRelativeRect = new RelativeRectTween(
      begin: new RelativeRect.fromLTRB(0.0, _kBackAppBarHeight, 0.0, 0.0),
      end: new RelativeRect.fromLTRB(0.0, boxConstraints.biggest.height, 0.0, 0.0),
    ).animate(_controller);

    final Animation<RelativeRect> backRelativeRect = new RelativeRectTween(
      begin: new RelativeRect.fromLTRB(0.0, _kBackAppBarHeight + 12.0, 0.0, 0.0),
      end: new RelativeRect.fromLTRB(0.0, _kBackAppBarHeight, 0.0, 0.0),
    ).animate(_controller);

    List<Widget> layers = [
      new StreamBuilder(
        stream: ScheduleProvider.of(context).numItemsOutput,
        builder: (context, snapshot) {
          int numItems = snapshot.data;

          if (!snapshot.hasData) {
            numItems = 2;
          }
          return new AnimatedBackground(
            t: t.clamp(0.00001, 1.0),
            numItems: numItems,
            progress: _controller,
          );
        },
      ),
      new SafeArea(
        bottom: false,
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            new BackAppBar(title: widget.backTitle),
          ],
        ),
      ),
      new PositionedTransition(
        rect: backRelativeRect,
        child: SafeArea(
          child: NotificationListener<ScrollUpdateNotification>(
            child: widget.backLayer,
            onNotification: (notification) {
              setState(() {
                t = (notification.metrics.pixels / notification.metrics.maxScrollExtent).clamp(0.00001, 1.0).abs();
              });

              return true;
            },
          ),
        ),
      ),
      new PositionedTransition(
        rect: frontRelativeRect,
        child: Stack(alignment: Alignment.topCenter, children: <Widget>[
          new SafeArea(
            bottom: false,
            child: GestureDetector(
              onVerticalDragUpdate: _handleVerticalDragUpdate,
              onVerticalDragEnd: _handleVerticalDragEnd,
              child: listView,
            ),
          ),
        ]),
      ),
    ];
    return new Stack(
      key: _backdropKey,
      children: layers,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new LayoutBuilder(
      builder: _buildStack,
    );
  }
}

typedef double DoubleCallback();

class MyScrollPhysics extends ScrollPhysics {
  MyScrollPhysics({ScrollPhysics parent, this.controller, DoubleCallback this.backdrop}) : super(parent: parent);

  final AnimationController controller;
  final DoubleCallback backdrop;

  @override
  MyScrollPhysics applyTo(ScrollPhysics ancestor) {
    return new MyScrollPhysics(parent: buildParent(ancestor), controller: controller, backdrop: backdrop);
  }

  double frictionFactor(double overscrollFraction) => 0.52 * math.pow(1 - overscrollFraction, 2);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    assert(offset != 0.0);
    assert(position.minScrollExtent <= position.maxScrollExtent);

    final double overscrollPastStart = math.max(position.minScrollExtent - position.pixels, 0.0);
    final double overscrollPastEnd = math.max(position.pixels - position.maxScrollExtent, 0.0);
    final double overscrollPast = math.max(overscrollPastStart, overscrollPastEnd);
    final bool easing = (overscrollPastStart > 0.0 && offset < 0.0) || (overscrollPastEnd > 0.0 && offset > 0.0);

    final double friction = easing
        // Apply less resistance when easing the overscroll vs tensioning.
        ? frictionFactor((overscrollPast - offset.abs()) / position.viewportDimension)
        : frictionFactor(overscrollPast / position.viewportDimension);
    final double direction = offset.sign;

    if (direction == 1.0) {
      if (position.pixels < position.minScrollExtent || position.pixels - offset < position.minScrollExtent) {
        controller.value += direction * _applyFriction(overscrollPast, offset.abs(), friction) / backdrop();

        if (position.pixels - offset < position.minScrollExtent) {
          return position.pixels;
        }
        return 0.0;
      }
      return offset;
    } else {
      if (controller.value > 0.0) {
        controller.value += direction * _applyFriction(overscrollPast, offset.abs(), friction) / backdrop();
        return 0.0;
      }

      if (position.outOfRange) {
        return direction * _applyFriction(overscrollPast, offset.abs(), friction);
      }

      return offset;
    }
  }

  static double _applyFriction(double extentOutside, double absDelta, double gamma) {
    assert(absDelta > 0);
    double total = 0.0;
    if (extentOutside > 0) {
      final double deltaToLimit = extentOutside / gamma;
      if (absDelta < deltaToLimit) return absDelta * gamma;
      total += extentOutside;
      absDelta -= deltaToLimit;
    }
    return total + absDelta;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    return 0.0;
  }

  @override
  Simulation createBallisticSimulation(ScrollMetrics position, double velocity) {
    final Tolerance tolerance = this.tolerance;

    if (position.pixels <= position.minScrollExtent &&
        velocity >= 0.0 &&
        !controller.isAnimating &&
        controller.value != 0.0) {
      if (velocity > 0.0 || controller.value != 1.0) {
        controller.fling(velocity: math.min(-velocity / backdrop(), -0.1));
      }
    }

    if (position.pixels <= position.minScrollExtent && velocity < -200) {
      controller.fling(velocity: -velocity / backdrop());
    } else if (velocity.abs() >= tolerance.velocity || position.outOfRange) {
      return new CoolScrollSimulation(
          spring: spring,
          position: position.pixels,
          velocity: velocity * 0.91,
          leadingExtent: position.minScrollExtent,
          trailingExtent: position.maxScrollExtent,
          tolerance: tolerance,
          controller: controller,
          backdrop: backdrop);
    }
    return null;
  }

  @override
  double get minFlingVelocity => 50.0 * 2.0;

  @override
  double carriedMomentum(double existingVelocity) {
    return existingVelocity.sign * math.min(0.000816 * math.pow(existingVelocity.abs(), 1.967).toDouble(), 40000.0);
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // TODO: implement shouldAcceptUserOffset
    return super.shouldAcceptUserOffset(position);
  }

  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

class CoolScrollSimulation extends Simulation {
  CoolScrollSimulation({
    @required this.position,
    @required this.velocity,
    @required this.leadingExtent,
    @required this.trailingExtent,
    @required this.spring,
    @required this.controller,
    @required this.backdrop,
    Tolerance tolerance: Tolerance.defaultTolerance,
  })  : assert(position != null),
        assert(velocity != null),
        assert(leadingExtent != null),
        assert(trailingExtent != null),
        assert(leadingExtent <= trailingExtent),
        assert(spring != null),
        super(tolerance: tolerance) {
    if (position < leadingExtent) {
      _springSimulation = _underscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
      topSpring = false;
    } else if (position > trailingExtent) {
      _springSimulation = _overscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
    } else {
      _frictionSimulation = new FrictionSimulation(0.135, position, velocity);
      final double finalX = _frictionSimulation.finalX;
      if (velocity > 0.0 && finalX > trailingExtent) {
        _springTime = _frictionSimulation.timeAtX(trailingExtent);
        _springSimulation = _overscrollSimulation(
          trailingExtent,
          math.min(_frictionSimulation.dx(_springTime), maxSpringTransferVelocity),
        );
        assert(_springTime.isFinite);
      } else if (velocity < 0.0 && finalX < leadingExtent) {
        _springTime = _frictionSimulation.timeAtX(leadingExtent);
        _springSimulation = new StopSimulation(tolerance: tolerance, stopPosition: leadingExtent);
        topSpring = true;
        assert(_springTime.isFinite);
      } else {
        _springTime = double.infinity;
      }
    }
    assert(_springTime != null);
  }

  /// The maximum velocity that can be transferred from the inertia of a ballistic
  /// scroll into overscroll.
  static const double maxSpringTransferVelocity = 5000.0;

  /// When [x] falls below this value the simulation switches from an internal friction
  /// model to a spring model which causes [x] to "spring" back to [leadingExtent].
  final double leadingExtent;

  /// When [x] exceeds this value the simulation switches from an internal friction
  /// model to a spring model which causes [x] to "spring" back to [trailingExtent].
  final double trailingExtent;

  /// The spring used used to return [x] to either [leadingExtent] or [trailingExtent].
  final SpringDescription spring;
  final double position;
  final double velocity;

  FrictionSimulation _frictionSimulation;
  Simulation _springSimulation;
  double _springTime;
  double _timeOffset = 0.0;

  bool topSpring = false;

  final AnimationController controller;
  final DoubleCallback backdrop;

  Simulation _underscrollSimulation(double x, double dx) {
    return new ScrollSpringSimulation(spring, x, leadingExtent, dx);
  }

  Simulation _overscrollSimulation(double x, double dx) {
    return new ScrollSpringSimulation(spring, x, trailingExtent, dx);
  }

  Simulation _simulation(double time) {
    Simulation simulation;
    if (time > _springTime) {
      if (topSpring && !controller.isAnimating) {
        controller.animateWith(
            new ScrollSpringSimulation(spring, 0.0, 0.0, -_frictionSimulation.dx(time) / (backdrop() * 1.25)));
      }
      _timeOffset = _springTime.isFinite ? _springTime : 0.0;
      simulation = _springSimulation;
    } else {
      _timeOffset = 0.0;
      simulation = _frictionSimulation;
    }
    return simulation..tolerance = tolerance;
  }

  @override
  double x(double time) {
    double x = _simulation(time).x(time - _timeOffset);

    return x;
  }

  @override
  double dx(double time) {
    double dx = _simulation(time).dx(time - _timeOffset);
    return dx;
  }

  @override
  bool isDone(double time) => controller.isAnimating || _simulation(time).isDone(time - _timeOffset);

  @override
  String toString() {
    return '$runtimeType(leadingExtent: $leadingExtent, trailingExtent: $trailingExtent)';
  }
}

class StopSimulation extends Simulation {
  StopSimulation({Tolerance tolerance, this.stopPosition}) : super(tolerance: tolerance);

  final double stopPosition;

  @override
  double x(double time) {
    return stopPosition;
  }

  @override
  double dx(double time) {
    return 0.0;
  }

  @override
  bool isDone(double time) {
    return true;
  }
}

class DragSlider extends AnimatedWidget {
  DragSlider({
    Key key,
    Animation<double> listenable,
  })  : _sizeAnimation = new CurvedAnimation(
          parent: listenable,
          curve: new Interval(0.0, 0.1),
        ),
        super(key: key, listenable: listenable);

  final Animation<double> _sizeAnimation;

  @override
  Widget build(BuildContext context) {
    return new CustomPaint(
      painter: new MyCustomPainter(),
      child: new Container(
        height: 5.5 * (1.0 - _sizeAnimation.value),
        width: 200.0,
      ),
    );
  }
}

class MyCustomPainter extends CustomPainter {
  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    Paint line = new Paint()
      ..color = Colors.grey.shade300
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5;

    Offset left = new Offset(size.width * 0.42, 0.0);
    Offset right = new Offset(size.width * 0.58, 0.0);
    Offset center = new Offset(size.width * 0.5, size.height);

    canvas.drawLine(left, center, line);
    canvas.drawLine(right, center, line);
  }
}

class AnimatedBackground extends AnimatedWidget {
  static const List<MaterialColor> colors = [Colors.purple, Colors.blue, Colors.green, Colors.deepOrange];

  static final Path trianglePath = parseSvgPathData('M0,61 71.326,61 35.663,0.5 z');
  static final Paint trianglePaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.green;

  static final Path linePath =
      parseSvgPathData('M100,6c0,3.3-2.7,6-6,6H6c-3.3,0-6-2.7-6-6l0,0c0-3.3,2.7-6,6-6h88C97.3,0,100,2.7,100,6L100,6z');
  static final Paint linePaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.pink;

  static final Path squarePath = parseSvgPathData('M0,0 0,100 100,100 100,0 z');
  static final Paint squarePaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.cyan;

  AnimatedBackground({
    Key key,
    this.t,
    this.numItems,
    Animation<double> progress,
  })  : progressPerChild = (1.0 / (numItems - 1)),
        super(listenable: progress);
  final double t;
  final int numItems;
  final double progressPerChild;

  @override
  Widget build(BuildContext context) {
    final Animation<double> progress = this.listenable;

    int currentIndex = (t / progressPerChild).floor();
    double localProgress = ((t - progressPerChild * currentIndex) / progressPerChild).clamp(0.0, 1.0);

    Color firstTopColor = colors[currentIndex % colors.length].shade500;
    Color secondTopColor = colors[(currentIndex + 1) % colors.length].shade500;

    Color firstBottomColor = colors[currentIndex % colors.length].shade300;
    Color secondBottomColor = colors[(currentIndex + 1) % colors.length].shade300;

    Color topColor = Color.lerp(firstTopColor, secondTopColor, localProgress);
    Color bottomColor = Color.lerp(firstBottomColor, secondBottomColor, localProgress);

    List<ShapeBackgroundPainterBuilder> painterBuilders = [
      (t, c) => [
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(0.5 * c.maxWidth, 0.08 * c.maxHeight, c.maxWidth * 1.1, c.maxWidth * 1.1),
                end: new Rect.fromLTWH(c.maxWidth, 0.0, c.maxWidth * 0.9, c.maxWidth * 0.9),
              ).lerp(t),
              child: new Material(
                type: MaterialType.circle,
                color: Colors.transparent,
                elevation: 7.0,
                child: new Container(
                  decoration: new BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: new RadialGradient(
                      center: const Alignment(0.7, -0.6), // near the top right
                      radius: 0.6,
                      colors: [
                        Colors.yellow.shade600, // yellow sun
                        Colors.yellow.shade300, // blue sky
                      ],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(-0.1 * c.maxWidth, 0.75 * c.maxHeight, c.maxWidth * 0.5, c.maxWidth * 0.5),
                end: new Rect.fromLTWH(-0.5 * c.maxWidth, 0.9 * c.maxHeight, c.maxWidth * 0.5, c.maxWidth * 0.5),
              ).lerp(t),
              child: new Material(
                type: MaterialType.circle,
                color: Colors.transparent,
                elevation: 7.0,
                child: new Container(
                  decoration: new BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: new RadialGradient(
                      center: const Alignment(0.7, -0.6), // near the top right
                      radius: 0.6,
                      colors: [
                        Colors.yellow.shade600, // yellow sun
                        Colors.yellow.shade300, // blue sky
                      ],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
      (t, c) => [
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.1, c.maxHeight * 0.1, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(-c.maxWidth * 0.25, 0.0, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 1.0, end: 0.9).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: math.pi / 2.5, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(trianglePath, painter: trianglePaint),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.5, c.maxHeight * 0.01, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(c.maxWidth * 0.5, -c.maxWidth * 0.25, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 0.8, end: 0.7).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: math.pi / 3.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(trianglePath, painter: trianglePaint),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.75, c.maxHeight * 0.21, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(c.maxWidth, c.maxHeight * 0.2, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 1.55, end: 1.0).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: math.pi / 4.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(trianglePath, painter: trianglePaint),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.9, c.maxHeight * 0.9, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(c.maxWidth, c.maxHeight, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 2.0, end: 1.9).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: math.pi / 4.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(trianglePath, painter: trianglePaint),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(-c.maxWidth * 0.05, c.maxHeight * 0.85, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(-c.maxWidth * 0.25, c.maxHeight, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 5.0, end: 4.0).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: -math.pi / 6.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(trianglePath, painter: trianglePaint),
                  ),
                ),
              ),
            ),
          ],
      (t, c) => [
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.5, c.maxHeight * 0.4, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(c.maxWidth, c.maxHeight * 0.6, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 4.0, end: 1.0).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: math.pi / 4.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(linePath, painter: linePaint),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.5, c.maxHeight * 0.5, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(c.maxWidth, c.maxHeight * 0.6, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 3.5, end: 1.0).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: math.pi / 4.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(linePath, painter: linePaint),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.5, c.maxHeight * 0.6, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(c.maxWidth, c.maxHeight * 0.6, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 3.0, end: 1.0).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: math.pi / 4.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(linePath, painter: linePaint),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.2, c.maxHeight * 0.8, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(-c.maxWidth, c.maxHeight * 0.8, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 4.0, end: 1.0).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: -math.pi / 4.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(linePath, painter: linePaint),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.2, c.maxHeight * 0.9, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(-c.maxWidth, c.maxHeight * 0.8, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 3.5, end: 1.0).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: -math.pi / 4.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(linePath, painter: linePaint),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: new RectTween(
                begin: new Rect.fromLTWH(c.maxWidth * 0.2, c.maxHeight, c.maxWidth * 0.25, c.maxWidth * 0.25),
                end: Rect.fromLTWH(-c.maxWidth, c.maxHeight * 0.8, c.maxWidth * 0.25, c.maxWidth * 0.25),
              ).lerp(t),
              child: Transform.scale(
                scale: Tween<double>(begin: 3.0, end: 1.0).lerp(t),
                child: Transform.rotate(
                  angle: Tween<double>(begin: -math.pi / 4.0, end: 0.0).lerp(t),
                  child: new CustomPaint(
                    painter: new PathPainter(linePath, painter: linePaint),
                  ),
                ),
              ),
            ),
          ],
      (t, c) => [
        Positioned.fromRect(
          rect: new RectTween(
            begin: new Rect.fromLTWH(c.maxWidth * 0.7, c.maxHeight * 0.2, c.maxWidth * 0.25, c.maxWidth * 0.25),
            end: Rect.fromLTWH(c.maxWidth, c.maxHeight * 0.3, c.maxWidth * 0.25, c.maxWidth * 0.25),
          ).lerp(t),
          child: Transform.scale(
            scale: Tween<double>(begin: 4.0, end: 1.0).lerp(t),
            child: Transform.rotate(
              angle: Tween<double>(begin: -math.pi / 4.0, end: 0.0).lerp(t),
              child: new CustomPaint(
                painter: new PathPainter(squarePath, painter: squarePaint),
              ),
            ),
          ),
        ),

        Positioned.fromRect(
          rect: new RectTween(
            begin: new Rect.fromLTWH(-c.maxWidth * 0.1, c.maxHeight * 0.7, c.maxWidth * 0.25, c.maxWidth * 0.25),
            end: Rect.fromLTWH(-c.maxWidth * 0.4, c.maxHeight * 0.6, c.maxWidth * 0.25, c.maxWidth * 0.25),
          ).lerp(t),
          child: Transform.scale(
            scale: Tween<double>(begin: 3.0, end: 1.0).lerp(t),
            child: Transform.rotate(
              angle: Tween<double>(begin: -math.pi / 4.0, end: 0.0).lerp(t),
              child: new CustomPaint(
                painter: new PathPainter(squarePath, painter: squarePaint),
              ),
            ),
          ),
        ),
      ],
    ];

    return new Container(
      decoration: new BoxDecoration(
        gradient: LinearGradient(
            begin: FractionalOffset.topLeft,
            end: new FractionalOffset(1.0, 1.5 - (1.0 - progress.value * 0.5)),
            colors: [topColor, bottomColor],
            stops: [0.0, 0.5]),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          List<Widget> children = [];
          for (int i = 0; i < painterBuilders.length; i++) {
            children.addAll(painterBuilders[i](
                progressForIndex(i, numItems, painterBuilders.length).clamp(0.00001, 1.0), constraints));
          }

          return new Stack(fit: StackFit.expand, children: children);
        },
      ),
    );
  }

  double progressForIndex(int builderIndex, int numItems, int numBuilders) {
    double normalizedProgress = ((t * (numItems - 1) - builderIndex) % numBuilders) / numBuilders;
    int index = builderIndex +
        (normalizedProgress * 2).floor() * numBuilders +
        ((t * (numItems - 1) - builderIndex) / numBuilders).floor() * numBuilders;

    double progress = ((((t * 2) - progressPerChild * index) / progressPerChild) - index).abs();

    return progress;
  }
}

typedef List<Widget> ShapeBackgroundPainterBuilder(double t, BoxConstraints constraints);

abstract class ShapeBackgroundPainter extends CustomPainter {
  ShapeBackgroundPainter(double t) : this.t = t.clamp(0.0, 1.0);

  double t = 0.0;

  @override
  bool shouldRepaint(ShapeBackgroundPainter oldDelegate) {
    return true;
  }
}

class BackgroundPainter extends ShapeBackgroundPainter {
  BackgroundPainter(double t) : super(t);

  @override
  void paint(Canvas canvas, Size size) {
    var gradient = new RadialGradient(
      center: const Alignment(0.7, -0.6), // near the top right
      radius: 0.6,
      colors: [
        Colors.yellow.shade600, // yellow sun
        Colors.yellow.shade300, // blue sky
      ],
      stops: [0.4, 1.0],
    );

    Offset circle1Position = new Tween<Offset>(
            begin: new Offset(size.width * 0.8, size.height * 0.4),
            end: new Offset(size.width * 1.2, size.height * 0.2))
        .lerp(t);
    double circle1Radius = new Tween<double>(begin: size.width * 0.4, end: size.width * 0.2).lerp(t);
    Rect circle1Rect = Rect.fromCircle(center: circle1Position, radius: circle1Radius);
    Paint circle1Line = new Paint()..shader = gradient.createShader(circle1Rect);

    Offset circle2Position = new Tween<Offset>(
            begin: new Offset(size.width * 0.1, size.height * 0.8),
            end: new Offset(-size.width * 0.5, size.height * 0.9))
        .lerp(t);
    double circle2Radius = new Tween<double>(begin: size.width * 0.2, end: size.width * 0.1).lerp(t);
    Rect circle2Rect = Rect.fromCircle(center: circle2Position, radius: circle2Radius);
    Paint circle2Line = new Paint()..shader = gradient.createShader(circle2Rect);

    canvas.drawShadow(new Path()..addOval(circle1Rect), Colors.black.withOpacity(0.5), 10.0, true);
    canvas.drawCircle(circle1Position, circle1Radius, circle1Line);

    canvas.drawShadow(new Path()..addOval(circle2Rect), Colors.black.withOpacity(0.5), 10.0, true);
    canvas.drawCircle(circle2Position, circle2Radius, circle2Line);
  }
}

class SvgPath extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class PathPainter extends CustomPainter {
  PathPainter(this.path, {@required this.painter});

  final Path path;
  final Paint painter;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawShadow(path, Colors.black.withOpacity(0.5), 7.0, true);
    canvas.drawPath(path, painter);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

Path createPolygon(List<Offset> offsets, Offset shift) {
  Path path = new Path();

  path.moveTo(offsets.first.dx + shift.dx, offsets.first.dy + shift.dy);

  for (int i = 1; i < offsets.length; i++) {
    path.lineTo(offsets[i].dx + shift.dx, offsets[i].dy + shift.dy);
  }

  return path;
}
