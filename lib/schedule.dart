import 'package:flutter/material.dart';
import 'backdrop.dart';
import 'bloc/schedule_bloc.dart';
import 'bloc/schedule_provider.dart';
import 'bloc/scroll_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'event_page.dart';
import 'utils.dart' as utils;

class SchedulePage extends StatefulWidget {
  SchedulePage({@required this.title});

  final String title;

  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final GlobalKey<BackDropState> _backdropKey = GlobalKey<BackDropState>();

  ScheduleBloc scheduleBloc;
  ScrollBloc scrollBloc;

  @override
  void initState() {
    super.initState();

    scheduleBloc = ScheduleBloc();
    scrollBloc = ScrollBloc();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScheduleProvider(
        scheduleBloc: scheduleBloc,
        child: ScrollProvider(
          scrollBloc: scrollBloc,
          child: StreamBuilder(
            stream: Firestore.instance.collection('events').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

              return BackDrop(
                key: _backdropKey,
                scrollBloc: scrollBloc,
                backLayer: MyBackLayer(
                  title: widget.title,
                  events: snapshot.data.documents,
                ),
                backTitle: Text(
                  '${widget.title}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 20.0,
                  ),
                ),
                frontLayer: MyFrontLayer(),
                frontLayerScrollBuilder: (physics) {
                  return MyFrontLayer(
                    scrollPhysics: physics,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class MyFrontLayer extends StatefulWidget {
  MyFrontLayer({this.scrollPhysics});

  final ScrollPhysics scrollPhysics;

  @override
  State<StatefulWidget> createState() {
    return MyFrontLayerState();
  }
}

class MyFrontLayerState extends State<MyFrontLayer> {
  @override
  Widget build(BuildContext context) {
    ScheduleBloc schedule = ScheduleProvider.of(context);

    return PhysicalShape(
        child: ClipRRect(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20.0), topRight: Radius.circular(20.0)),
          child: Container(
            color: Colors.white,
            child: StreamBuilder(
              stream: schedule.latestItem,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  List<DocumentSnapshot> events = snapshot.data as List<DocumentSnapshot>;
                  events.sort((snapshot1, snapshot2) {
                    if (snapshot1 == null || snapshot2 == null) {
                      return 0;
                    }

                    DateTime firstDate = (snapshot1['date_start'] as Timestamp).toDate();
                    DateTime secondDate = (snapshot2['date_start'] as Timestamp).toDate();

                    return firstDate.compareTo(secondDate);
                  });

                  return Center(
                    child: EventList(events: events, scrollPhysics: widget.scrollPhysics),
                  );
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
        ),
        elevation: 12.0,
        clipper: ShapeBorderClipper(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.0),
              topRight: Radius.circular(20.0),
            ),
          ),
        ),
        color: Colors.white);
  }
}

typedef void ScheduleTapDelegate(List<DocumentSnapshot> day);

class MyBackLayer extends StatefulWidget {
  MyBackLayer({Key key, @required this.title, @required this.events}) : super(key: key);

  final String title;
  final List<DocumentSnapshot> events;

  @override
  MyBackLayerState createState() => MyBackLayerState();
}

class MyBackLayerState extends State<MyBackLayer> with SingleTickerProviderStateMixin {
  AnimationController _controller;

  PageController _pageController;

  Map<DateTime, List<DocumentSnapshot>> eventsOnDays;
  List<DateTime> days;

  @override
  void initState() {
    super.initState();

    int initialPage = _updateDays();

    if (_pageController != null) {
      _pageController.removeListener(_handlePageScroll);
    }
    _pageController = PageController(viewportFraction: 0.8, initialPage: initialPage, keepPage: true)
      ..addListener(_handlePageScroll);
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this, value: 0.0);
    _controller.value = (initialPage / (days.length - 1));
  }

  int _updateDays() {
    eventsOnDays = {};

    for (DocumentSnapshot snapshot in widget.events) {
      DateTime date = (snapshot['date_start'] as Timestamp).toDate();
      DateTime day = DateTime(date.year, date.month, date.day);

      if (eventsOnDays[day] == null) {
        eventsOnDays[day] = List<DocumentSnapshot>();
      }
      eventsOnDays[day].add(snapshot);
    }

    days = eventsOnDays.keys.toList()
      ..sort(
        (first, second) {
          return first.compareTo(second);
        },
      );

    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    int initialPage;
    int latestDay;

    if (days.length > 0) {
      for (int i = 0; i < days.length; i++) {
        DateTime day = days[i];

        if (day.isBefore(today)) {
          latestDay = i;
        }
        if (day.isAtSameMomentAs(today)) {
          initialPage = i;
        }
      }

      if (initialPage == null) {
        if (today.isBefore(days.first)) {
          initialPage = 0;
        } else {
          if (latestDay != null) {
            initialPage = latestDay;
          } else {
            initialPage = days.length - 1;
          }
        }
      }

      print('initial page: $initialPage');

      return initialPage;
    } else {
      return 0;
    }
  }

  @override
  void didUpdateWidget(MyBackLayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    _updateDays();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    ScrollProvider.of(context).horizontalScrollInput.add(_controller.value);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageScroll);
    _controller.dispose();

    super.dispose();
  }

  void _handlePageScroll() {
    _controller.value =
        (_pageController.position.pixels / _pageController.position.maxScrollExtent).clamp(0.0, 1.0).abs();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: <Widget>[_buildPageSelector(context, _controller, widget.events)],
      ),
    );
  }

  Widget _buildPageSelector(BuildContext context, AnimationController controller, List<DocumentSnapshot> snapshots) {
    if (snapshots.length == 0)
      return Center(
          child: Text('No Internet Connection',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16.0)));
    ScheduleProvider.of(context).numItemsInput.add(days.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 48.0, bottom: 16.0),
          child: _CrossFadeTransition(
            alignment: Alignment.centerLeft,
            progress: _controller,
            children: days.map((date) {
              return DayTitle(date: date);
            }).toList(),
          ),
        ),
        SizedBox.fromSize(
          size: Size.fromHeight(MediaQuery.of(context).size.height * 0.575),
          child: PageView(
            scrollDirection: Axis.horizontal,
            controller: _pageController,
            children: days.map((day) {
              List<DocumentSnapshot> eventsOnDay = eventsOnDays[day]
                ..sort((first, second) {
                  if (first == null || second == null) {
                    return 0;
                  }

                  int firstPriority = first['priority'];
                  int secondPriority = second['priority'];

                  return secondPriority - firstPriority;
                });
              List<DocumentSnapshot> eventsOnDayForCard = eventsOnDay.sublist(0, math.min(eventsOnDay.length, 4));

              return GestureDetector(
                onTap: () {
                  ScheduleProvider.of(context).addition.add(eventsOnDay);
                  ScrollProvider.of(context).scrollStateInput.add(ScrollState.Open);
                },
                child: DayCard(
                  snapshots: eventsOnDayForCard,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _CrossFadeTransition extends AnimatedWidget {
  const _CrossFadeTransition({
    Key key,
    this.alignment: Alignment.center,
    Animation<double> progress,
    this.child0,
    this.child1,
    this.children,
  }) : super(key: key, listenable: progress);

  final AlignmentGeometry alignment;
  final Widget child0;
  final Widget child1;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final Animation<double> progress = listenable;

    final double progressPerChild = 1.0 / (children.length - 1);

    final List<Widget> opacityChildren = [];

    for (int i = 0; i < children.length; i++) {
      Animation<double> parent;
      Curve curve;

      double progressAtFull = i * progressPerChild;

      double start, end;

      if (progress.value <= progressAtFull) {
        parent = progress;

        start = (i - 1) * progressPerChild;
        end = (i) * progressPerChild;

        start = start.clamp(0.0, 1.0);
        end = end.clamp(0.0, 1.0);

        curve = Interval(start, end);
      } else {
        parent = ReverseAnimation(progress);

        start = (i * progressPerChild);
        end = (i + 1) * progressPerChild;

        start = start.clamp(0.0, 1.0);
        end = end.clamp(0.0, 1.0);

        curve = Interval(start, end).flipped;
      }

      double opacity = CurvedAnimation(parent: parent, curve: curve).value;
      if (progress.value < start || progress.value > end) {
        opacity = 0.0;
      } else if (start == end) {
        opacity = 1.0;
      }

      opacityChildren.add(
        Opacity(
          opacity: opacity,
          child: children[i],
        ),
      );
    }

    return Stack(alignment: alignment, children: opacityChildren);
  }
}

class DayCard extends StatelessWidget {
  DayCard({this.snapshots});

  final List<DocumentSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20.0))),
      margin: EdgeInsets.all(10.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: snapshots.map((snapshot) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: EventRow(
                  (snapshot['date_start'] as Timestamp).toDate(),
                  snapshot['title'],
                  EventType.fromTitle(snapshot['type']),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class EventRow extends StatelessWidget {
  EventRow(this.date, this.title, this.type);

  DateTime date;
  String title;
  EventType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        IgnorePointer(
          ignoring: true,
          child: FloatingActionButton(
            onPressed: () {},
            heroTag: '$date-$title-back',
            child: Icon(type.icon),
            backgroundColor: type.color,
            elevation: 4.0,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15.0),
            ),
          ),
        )
      ],
    );
  }
}

class EventList extends StatefulWidget {
  EventList({Key key, this.events, this.scrollPhysics}) : super(key: key);

  final List<DocumentSnapshot> events;
  final ScrollPhysics scrollPhysics;

  @override
  State<StatefulWidget> createState() {
    return EventListState();
  }
}

class EventListState extends State<EventList> {
  final ScrollController _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    Widget slider = StreamBuilder(
      stream: ScrollProvider.of(context).progressOutput,
      builder: (context, snapshot) {
        double t = 0.0;
        if (snapshot.hasData) {
          t = snapshot.data;
        }

        return CustomDragSlider(t);
      },
    );
    List<Widget> children = [
      Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ScrollProvider.of(context).scrollStateInput.add(ScrollState.Closed);
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
              child: slider,
            ),
          ),
        ],
      )
    ];

    for (int index = 0; index < widget.events.length; index++) {
      final DocumentSnapshot event = widget.events[index];

      children.add(GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          Navigator.push(
            context,
            MyCoolPageRoute(
              fullscreenDialog: true,
              builder: (context) {
                return EventPage(event);
              },
            ),
          );
        },
        child: Padding(
          padding:
              EdgeInsets.only(top: index == 0 ? 8.0 : 0.0, bottom: index == (widget.events.length - 1) ? 32.0 : 0.0),
          child: EventListTile(
            event: event,
            previousEventInList: index > 0 ? widget.events[index - 1] : null,
            nextEventInList: index < widget.events.length - 1 ? widget.events[index + 1] : null,
          ),
        ),
      ));
    }

    return ListView(
      physics: widget.scrollPhysics,
      controller: _controller,
      children: children,
    );
  }
}

class CustomDragSlider extends StatelessWidget {
  CustomDragSlider(this.t);

  final double t;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MyCustomPainter(),
      child: Container(
        height: 5.5 * (1.0 - (t * 4)).clamp(0.0, 1.0),
        width: 200.0,
      ),
    );
  }
}

class EventListTile extends StatelessWidget {
  EventListTile({this.event, this.previousEventInList, this.nextEventInList});

  final DocumentSnapshot previousEventInList;
  final DocumentSnapshot event;
  final DocumentSnapshot nextEventInList;

  @override
  Widget build(BuildContext context) {
    final EventType type = EventType.fromTitle(event['type']);
    bool mini = event['priority'] < 2;
    DateTime date = (event['date_start'] as Timestamp).toDate();

    bool connectsToTop = previousEventInList != null;

    if (connectsToTop) {
      DateTime previousTime = (previousEventInList['date_start'] as Timestamp).toDate();

      if (previousTime == date) {
        connectsToTop = false;
      }
    }

    bool connectsToBottom = nextEventInList != null;

    if (connectsToBottom) {
      DateTime nextTime = (nextEventInList['date_start'] as Timestamp).toDate();

      if (nextTime == date) {
        connectsToBottom = false;
      }
    }

    List<Widget> children = [];

    double containerHeight = 56.0;
    if (connectsToTop) {
      containerHeight += 25.0;

      Color topColor = EventType.fromTitle(previousEventInList['type']).color;
      Color bottomColor = type.color;

      children.add(Positioned(
        top: 0.0,
        child: Container(
          width: 10.0,
          height: 51.0,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Color.lerp(topColor, bottomColor, 0.5), bottomColor],
                begin: FractionalOffset.topCenter,
                end: FractionalOffset.bottomCenter,
                stops: [0.0, 0.5]),
          ),
        ),
      ));
    }

    if (connectsToBottom) {
      containerHeight += 25;

      Color topColor = type.color;
      Color bottomColor = EventType.fromTitle(nextEventInList['type']).color;

      children.add(Positioned(
        bottom: 0.0,
        child: Container(
          width: 10.0,
          height: 51.0,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [topColor, Color.lerp(topColor, bottomColor, 0.5)],
                begin: FractionalOffset.topCenter,
                end: FractionalOffset.bottomCenter,
                stops: [0.5, 1.0]),
          ),
        ),
      ));
    }

    if (!connectsToTop && !connectsToBottom) {
      //containerHeight += mini ? 20.0 : 30.0;
    }

    //if (connectsToBottom || connectsToTop) {
    children.add(Container(
      width: 10.0,
      height: containerHeight,
    ));
    //}

    children.add(IgnorePointer(
      ignoring: true,
      child: FloatingActionButton(
        onPressed: () {},
        heroTag: '${event['title']}-${event['date_start']}',
        child: Icon(
          type.icon,
          size: mini ? IconTheme.of(context).size / 1.25 : IconTheme.of(context).size,
        ),
        backgroundColor: type.color,
        mini: mini,
        elevation: 0.0,
      ),
    ));

    Alignment align = Alignment.center;

    double bottomPadding = 0.0;
    double topPadding = 0.0;
    if (connectsToTop && !connectsToBottom) {
      align = Alignment.bottomCenter;
      topPadding = 25.0;
    } else if (connectsToBottom && !connectsToTop) {
      align = Alignment.topCenter;
      bottomPadding = 25.0;
    }

    String time = '${utils.toTwelveHour(date.hour)}:${utils.twoDigits(date.minute)} ${utils.amOrPm(date.hour)}';

    if (!connectsToTop && previousEventInList != null) {
      time = '';
    }

    return Stack(children: <Widget>[
      Padding(
          padding: EdgeInsets.only(
              left: 16.0, right: 16.0, bottom: (!connectsToBottom ? 4.0 : 0.0), top: (!connectsToTop ? 4.0 : 0.0)),
          child: Row(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding, right: 16.0),
                child: Container(
                  width: 60.0,
                  child: Opacity(
                    opacity: 0.5,
                    child: Text(
                      time,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 56.0,
                child: Stack(
                  alignment: align,
                  children: children,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 16.0, top: topPadding, bottom: bottomPadding),
                child: Text(
                  event['title'],
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15.0),
                ),
              )
            ],
          )),
      Positioned(
        bottom: 0.0,
        right: 0.0,
        left: 150.0,
        child: Container(
          height: 1.0,
          color: Colors.black.withOpacity(connectsToBottom ? 0.12 : 0.0),
        ),
      ),
    ]);
  }
}

class EventType {
  static final List<MaterialColor> colors = [
    Colors.lightBlue,
    Colors.red,
    Colors.purple,
    Colors.green,
    Colors.pink,
    Colors.cyan,
    Colors.yellow,
    Colors.teal,
    Colors.red,
    Colors.orange
  ];

  static final Map<String, EventType> _eventTypes = {
    'party': EventType('party', Icons.cake, Colors.lightBlue),
    'info': EventType('info', Icons.info, Colors.red),
    'social': EventType('social', Icons.group, Colors.purple),
    'excursion': EventType('excursion', Icons.directions_run, Colors.green),
    'activity': EventType('activity', Icons.local_play, Colors.pink),
    'meal': EventType('meal', Icons.restaurant, Colors.cyan),
  };

  EventType(this.type, this.icon, this.color);

  factory EventType.fromTitle(String title) {
    return _eventTypes[title];
  }

  final String type;
  final IconData icon;
  final MaterialColor color;
}

class EventTypes {}

class DayTitle extends StatelessWidget {
  static final List<String> weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static final List<String> months = [
    'January',
    'Februrary',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  DayTitle({this.date});

  DateTime date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          weekdays[date.weekday - 1],
          textAlign: TextAlign.left,
          style: TextStyle(color: Colors.white, fontSize: 40.0, fontWeight: FontWeight.w700),
        ),
        Text(
          '${months[date.month - 1]} ${date.day}',
          textAlign: TextAlign.left,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16.0, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
