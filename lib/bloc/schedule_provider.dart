import 'package:flutter/material.dart';
import 'schedule_bloc.dart';

class ScheduleProvider extends InheritedWidget {

  final ScheduleBloc scheduleBloc;

  ScheduleProvider({
    Key key,
    this.scheduleBloc,
    Widget child
  }) : super(key: key, child: child);

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    return true;
  }

  static ScheduleBloc of(BuildContext context) =>
      (context.inheritFromWidgetOfExactType(ScheduleProvider) as ScheduleProvider)
          .scheduleBloc;
}