import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

String twoDigits(int n) {
  if (n >= 10) return "${n}";
  return "0${n}";
}

int toTwelveHour(int n) {
  return n > 12 ? n % 12 : (n == 0 ? 12 : n);
}

String amOrPm(int n) {
return n >= 12 ? 'p.m.' : 'a.m.';
}

final List<String> months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'Devember'
];

String computeHowLongAgoText(DateTime timestamp) {
  DateTime now = DateTime.now();

  Duration difference = now.difference(timestamp);

  if (difference.inSeconds < 60) {
    return 'Just Now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
  } else if (difference.inHours < 6) {
    return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
  } else {
    bool sameDay =
        new DateTime(now.year, now.month, now.day) == new DateTime(timestamp.year, timestamp.month, timestamp.day);

    String onText = sameDay ? 'Today' : 'on ${months[timestamp.month]} ${timestamp.day}';
    return 'At ${toTwelveHour(timestamp.hour)}:${twoDigits(timestamp.minute)} ${amOrPm(timestamp.hour)} ${onText}';
  }
}

String computeHowLongAgoTextShort(DateTime timestamp) {
  DateTime now = DateTime.now();

  Duration difference = now.difference(timestamp);

  if (difference.inSeconds < 60) {
    return 'Just Now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
  } else if (difference.inHours < 6) {
    return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
  } else {
    bool sameDay =
        new DateTime(now.year, now.month, now.day) == new DateTime(timestamp.year, timestamp.month, timestamp.day);

    String onText = sameDay ? 'Today' : 'On ${months[timestamp.month]} ${timestamp.day}';
    return '${onText}';
  }
}

void openMaps(BuildContext context, GeoPoint location, String title) {
  TargetPlatform platform = Theme.of(context).platform;
  if(platform == TargetPlatform.iOS) {

    Uri uri = Uri.https('maps.apple.com', '/', {
      'll':'${location.latitude},${location.longitude}',
      'z': '19.5',
      'q': title
    });

    launch(uri.toString());
  } else {
    String androidUrl = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
    launch(androidUrl);
  }
}