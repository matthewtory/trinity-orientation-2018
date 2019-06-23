import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'utils.dart';
import 'schedule.dart';
import 'map.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class EventPage extends StatefulWidget {
  EventPage(this.event);

  final DocumentSnapshot event;

  @override
  State<StatefulWidget> createState() => new EventPageState();
}

class EventPageState extends State<EventPage> with SingleTickerProviderStateMixin {
  static final _kAppBarHeight = 128.0;
  static final double _kToolbarHeight = 56.0;

  AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = new AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    List<Widget> children = [
      _createEventHeader(context, widget.event),
      new EventCategoryCard(
        controller: _controller,
        heading: 'Description',
        body: new Text(
          widget.event['description'],
          style: new TextStyle(fontWeight: FontWeight.w400, fontSize: 18.0),
        ),
      ),
    ];

    if (widget.event['to_wear'] != null) {
      List toWear = widget.event['to_wear'];

      children.add(new EventCategoryCard(
        controller: _controller,
        heading: 'What to Wear',
        body: new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: toWear.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: new Text(
                '•  ${(item as String)}',
                style: new TextStyle(fontSize: 16.0),
              ),
            );
          }).toList(),
        ),
      ));
    }

    if (widget.event['to_bring'] != null) {
      List toWear = widget.event['to_bring'];

      children.add(new EventCategoryCard(
        controller: _controller,
        heading: 'What to Bring',
        body: new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: toWear.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: new Text(
                '•  ${(item as String)}',
                style: new TextStyle(fontSize: 16.0),
              ),
            );
          }).toList(),
        ),
      ));
    }

    if (widget.event['location'] != null) {
      GeoPoint location = widget.event['location'];

      children.add(new EventCategoryCard(
        controller: _controller,
        heading: 'Where to Go',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Container(
              height: 200.0,
              child: new FlutterMap(
                options: new MapOptions(
                  center: new LatLng(location.latitude, location.longitude),
                  zoom: 17.0,
                ),
                layers: [
                  new TileLayerOptions(
                    urlTemplate: "https://api.tiles.mapbox.com/v4/"
                        "{id}/{z}/{x}/{y}@2x.png?access_token={accessToken}",
                    additionalOptions: {
                      'accessToken':
                          'pk.eyJ1IjoibWF0dGhld3RvcnkiLCJhIjoiY2pleDU3czl6MDI3YTJ6bms5ZnA0cWF1YyJ9.8_zTUzsIjhhucc2K0n-_Fg',
                      'id': 'mapbox.streets',
                    },
                  ),
                  new MarkerLayerOptions(
                    markers: [
                      new Marker(
                        width: 80.0,
                        height: 80.0,
                        anchor: AnchorPos.top,
                        point: new LatLng(location.latitude, location.longitude),
                        builder: (ctx) => new Container(
                              child: new AnimatedMarker(widget.event, null),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: new OutlineButton(
                child: const Text('Directions'),
                textColor: Colors.pink,
                highlightedBorderColor: Colors.pink,
                onPressed: () {
                  openMaps(context, widget.event['location'], widget.event['title']);
                },
              ),
            )
          ],
        ),
      ));
    }

    EventType type = EventType.fromTitle(widget.event['type']);

    return new Scaffold(
      body: Stack(fit: StackFit.expand, children: <Widget>[
        new Container(
          decoration: new BoxDecoration(
            gradient: new LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [type.color.shade500, type.color.shade200],
            ),
          ),
        ),
        new CustomScrollView(
          slivers: <Widget>[
            new SliverAppBar(
              backgroundColor: Colors.transparent,
              actions: <Widget>[
                FutureBuilder<FirebaseUser>(
                  future: FirebaseAuth.instance.currentUser(),
                  builder: (context, user) {
                    if (!user.hasData) return Container();

                    if (!user.data.isAnonymous) {
                      return IconButton(
                        icon: Icon(Icons.edit),
                        tooltip: 'Edit Event',
                        onPressed: () async {
                          bool didChange = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (context) {
                                return EditEventPage(ref: widget.event.reference);
                              },
                            ),
                          );

                          if (didChange != null && didChange) {
                            Navigator.pop(context);
                          }
                        },
                      );
                    }

                    return Container();
                  },
                ),
                FutureBuilder<FirebaseUser>(
                  future: FirebaseAuth.instance.currentUser(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Container();

                    if (!snapshot.data.isAnonymous) {
                      return IconButton(
                        icon: Icon(Icons.notifications_active),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (context) {
                                return EventNotificationPage(ref: widget.event.reference);
                              },
                            ),
                          );
                        },
                      );
                    }

                    return Container();
                  },
                )
              ],
            ),
            new SliverList(
              delegate: new SliverChildListDelegate(children),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _createEventHeader(BuildContext context, DocumentSnapshot event) {
    DateTime startDate = (widget.event['date_start'] as Timestamp).toDate();
    DateTime endDate = (widget.event['date_end'] as Timestamp).toDate();

    String startString = '${toTwelveHour(startDate.hour)}:${twoDigits(startDate.minute)} ${amOrPm(startDate.hour)}';
    String endString = '${toTwelveHour(endDate.hour)}:${twoDigits(endDate.minute)} ${amOrPm(endDate.hour)}';

    String timeString = '$startString to $endString';

    return new Container(
      padding: EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: new Text(
              widget.event['title'],
              style: new TextStyle(
                color: Colors.white,
                fontSize: 32.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.place,
                  size: 16.0,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    widget.event['location_title'],
                    style: new TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.timer,
                  size: 16.0,
                  color: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    timeString,
                    style: new TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EventCategoryCard extends StatelessWidget {
  EventCategoryCard({@required this.controller, @required this.heading, @required this.body});

  final Animation<double> controller;
  final String heading;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: new Tween<Offset>(
        begin: const Offset(0.0, 0.5),
        end: Offset.zero,
      ).animate(new CurvedAnimation(
          parent: controller,
          curve: new Interval(
            0.25,
            0.6,
            curve: Curves.decelerate,
          ))),
      child: new Container(
        padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
        child: new Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20.0))),
          child: new Padding(
            padding: EdgeInsets.all(16.0),
            child: new Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                new Text(
                  heading,
                  style: new TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 16.0,
                    color: Colors.black.withOpacity(0.25),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: body,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyCoolPageRoute<T> extends PageRoute<T> {
  MyCoolPageRoute({
    @required this.builder,
    RouteSettings settings,
    bool fullscreenDialog: true,
  }) : super(settings: settings, fullscreenDialog: fullscreenDialog);

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  bool get maintainState => true;

  @override
  Color get barrierColor => null;

  @override
  String get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return new MyCoolPageTransition(routeAnimation: animation, child: child);
  }
}

class MyCoolPageTransition extends StatelessWidget {
  MyCoolPageTransition({Key key, @required this.routeAnimation, @required this.child}) : super(key: key);

  final Animation<double> routeAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return new ClipOval(
      clipper: new CircleRevealClipper(routeAnimation.value),
      child: new SlideTransition(
          position: new Tween<Offset>(begin: const Offset(0.0, 0.25), end: Offset.zero).animate(routeAnimation),
          child: child),
    );
  }
}

class CircleRevealClipper extends CustomClipper<Rect> {
  CircleRevealClipper(this.revealPercent);

  final double revealPercent;
  @override
  Rect getClip(Size size) {
    final epicenter = new Offset(size.width / 0.9, size.height / 0.9);

    double theta = math.atan(epicenter.dy / epicenter.dx);
    final distanceToCorner = epicenter.dy / math.sin(theta);

    final radius = distanceToCorner * revealPercent;
    final diameter = 2 * radius;

    return new Rect.fromLTWH(epicenter.dx - radius, epicenter.dy - radius, diameter, diameter);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return true;
  }
}

class EditEventPage extends StatefulWidget {
  EditEventPage({this.ref});

  DocumentReference ref;

  @override
  _EditEventPageState createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final GlobalKey<FormFieldState<String>> _titleKey = GlobalKey<FormFieldState<String>>();
  final GlobalKey<FormFieldState<String>> _descriptionKey = GlobalKey<FormFieldState<String>>();

  DateTime startDate;
  DateTime endDate;
  String type;
  int priority;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Event'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: widget.ref.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

            DocumentSnapshot document = snapshot.data;

            return ListView(
              children: <Widget>[
                Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextFormField(
                          key: _titleKey,
                          initialValue: document['title'],
                          decoration: InputDecoration(labelText: 'Event Title'),
                          maxLines: 1,
                          maxLength: 30,
                          validator: (value) {
                            if (value.length <= 0) return 'Must enter a title';
                            if (value.length > 30) return 'Title too long';
                          },
                        ),
                        Flexible(
                          child: TextFormField(
                            key: _descriptionKey,
                            initialValue: document['description'],
                            keyboardType: TextInputType.multiline,
                            maxLines: null,
                            decoration: InputDecoration(labelText: 'Event Description'),
                            validator: (value) {
                              if (value.length <= 0) return 'Must enter a description';
                            },
                          ),
                        ),
                        _DateTimePicker(
                          labelText: 'Start Date',
                          selectedDate: startDate ?? document['date_start'],
                          selectedTime: _toTimeOfDay(startDate) ?? _toTimeOfDay(document['date_start']),
                          selectDate: (date) {
                            int hour = startDate != null ? startDate.hour : date.hour;
                            int minute = startDate != null ? startDate.minute : date.minute;

                            setState(() {
                              startDate = DateTime(date.year, date.month, date.day, hour, minute);
                            });
                          },
                          selectTime: (timeOfDay) {
                            int year = startDate != null ? startDate.year : document['date_start'].year;
                            int month = startDate != null ? startDate.month : document['date_start'].month;
                            int day = startDate != null ? startDate.day : document['date_start'].day;

                            setState(() {
                              startDate = DateTime(year, month, day, timeOfDay.hour, timeOfDay.minute);
                            });
                          },
                        ),
                        _DateTimePicker(
                          labelText: 'End Date',
                          selectedDate: endDate ?? document['date_end'],
                          selectedTime: _toTimeOfDay(endDate) ?? _toTimeOfDay(document['date_end']),
                          selectDate: (date) {
                            int hour = endDate != null ? endDate.hour : date.hour;
                            int minute = endDate != null ? endDate.minute : date.minute;

                            setState(() {
                              endDate = DateTime(date.year, date.month, date.day, hour, minute);
                            });
                          },
                          selectTime: (timeOfDay) {
                            int year = endDate != null ? endDate.year : document['date_end'].year;
                            int month = endDate != null ? endDate.month : document['date_end'].month;
                            int day = endDate != null ? endDate.day : document['date_end'].day;

                            setState(() {
                              endDate = DateTime(year, month, day, timeOfDay.hour, timeOfDay.minute);
                            });
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(),
                        ),
                        Text('Event Type'),
                        DropdownButton<String>(
                          items: <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              child: Text('Party'),
                              value: 'party',
                            ),
                            DropdownMenuItem(
                              child: Text('Info'),
                              value: 'info',
                            ),
                            DropdownMenuItem(
                              child: Text('Social'),
                              value: 'social',
                            ),
                            DropdownMenuItem(
                              child: Text('excursion'),
                              value: 'excursion',
                            ),
                            DropdownMenuItem(
                              child: Text('Activity'),
                              value: 'activity',
                            ),
                            DropdownMenuItem(
                              child: Text('Meal'),
                              value: 'meal',
                            ),
                          ],
                          value: type ?? document['type'],
                          onChanged: (type) => setState(() {
                                this.type = type;
                              }),
                        ),
                        Text('Event Priority'),
                        DropdownButton<int>(
                          items: <DropdownMenuItem<int>>[
                            DropdownMenuItem(
                              child: Text('0'),
                              value: 0,
                            ),
                            DropdownMenuItem(
                              child: Text('1'),
                              value: 1,
                            ),
                            DropdownMenuItem(
                              child: Text('2'),
                              value: 2,
                            ),
                            DropdownMenuItem(
                              child: Text('3'),
                              value: 3,
                            ),
                            DropdownMenuItem(
                              child: Text('4'),
                              value: 4,
                            ),
                          ],
                          value: priority ?? document['priority'],
                          onChanged: (priority) => setState(() {
                                this.priority = priority;
                              }),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: RaisedButton(
                    child: Text('Save'),
                    onPressed: () async {
                      if (_formKey.currentState.validate()) {
                        await document.reference.updateData({
                          'title': _titleKey.currentState.value,
                          'description': _descriptionKey.currentState.value,
                          'date_start': startDate ?? document['date_start'],
                          'date_end': endDate ?? document['date_end'],
                          'type': type ?? document['type'],
                          'priority': priority ?? document['priority'],
                        });

                        Navigator.pop(context, true);
                      }
                    },
                  ),
                ),
              ],
            );
          }),
    );
  }
}

class EventNotificationPage extends StatefulWidget {
  EventNotificationPage({this.ref});

  final DocumentReference ref;

  @override
  _EventNotificationPageState createState() => _EventNotificationPageState();
}

class _EventNotificationPageState extends State<EventNotificationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  TextEditingController _subjectController;
  TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();

    _subjectController = TextEditingController();
    _bodyController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Notification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(labelText: 'Notification Title'),
                maxLength: 30,
                validator: (value) {
                  if(value.length <= 0) return 'Title cannot be empty';
                },
              ),
              TextFormField(
                controller: _bodyController,
                decoration: InputDecoration(labelText: 'Notification Text'),
                validator: (value) {
                  if(value.length <= 0) return 'Text cannot be empty';
                },
                maxLines: null,
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: RaisedButton(
                    child: Text('Send Notification'),
                    onPressed: () async {
                      if(_formKey.currentState.validate()) {

                        await Firestore.instance.collection('notifications').add({
                          'text': _bodyController.value.text,
                          'title': _subjectController.value.text,
                          'event': widget.ref.documentID,
                          'delivered': false,
                          'click_action': 'FLUTTER_NOTIFICATION_CLICK'
                        });

                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TimeOfDay _toTimeOfDay(DateTime dateTime) {
  return dateTime != null ? TimeOfDay(hour: dateTime.hour, minute: dateTime.minute) : null;
}

class _DateTimePicker extends StatelessWidget {
  const _DateTimePicker(
      {Key key, this.labelText, this.selectedDate, this.selectedTime, this.selectDate, this.selectTime})
      : super(key: key);

  final String labelText;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final ValueChanged<DateTime> selectDate;
  final ValueChanged<TimeOfDay> selectTime;

  Future<Null> _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
        context: context, initialDate: selectedDate, firstDate: new DateTime(2015, 8), lastDate: new DateTime(2101));
    if (picked != null && picked != selectedDate) selectDate(picked);
  }

  Future<Null> _selectTime(BuildContext context) async {
    final TimeOfDay picked = await showTimePicker(context: context, initialTime: selectedTime);
    if (picked != null && picked != selectedTime) selectTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = Theme.of(context).textTheme.title;
    return new Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        new Expanded(
          flex: 4,
          child: new _InputDropdown(
            labelText: labelText,
            valueText: new DateFormat.yMMMd().format(selectedDate),
            valueStyle: valueStyle,
            onPressed: () {
              _selectDate(context);
            },
          ),
        ),
        const SizedBox(width: 12.0),
        new Expanded(
          flex: 3,
          child: new _InputDropdown(
            valueText: selectedTime.format(context),
            valueStyle: valueStyle,
            onPressed: () {
              _selectTime(context);
            },
          ),
        ),
      ],
    );
  }
}

class _InputDropdown extends StatelessWidget {
  const _InputDropdown({Key key, this.child, this.labelText, this.valueText, this.valueStyle, this.onPressed})
      : super(key: key);

  final String labelText;
  final String valueText;
  final TextStyle valueStyle;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return new InkWell(
      onTap: onPressed,
      child: new InputDecorator(
        decoration: new InputDecoration(
          labelText: labelText,
        ),
        baseStyle: valueStyle,
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            new Text(valueText, style: valueStyle),
            new Icon(Icons.arrow_drop_down,
                color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade700 : Colors.white70),
          ],
        ),
      ),
    );
  }
}
