import 'dart:async';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

bool USE_FIRESTORE_EMULATOR = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  if (USE_FIRESTORE_EMULATOR) {
    FirebaseFirestore.instance.settings = Settings(
      host: 'localhost:8080', sslEnabled: false, persistenceEnabled: false);
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  /*
  final FirebaseOptions firebaseOptions = const FirebaseOptions(
    googleAppID: '1:475054392488:android:c79c15235595665267ae9d',
    apiKey: 'AIzaSyAOhVb7JVwxgEXEHh0Bn_q_H451Jk3QEyY',
    projectID: 'mummy-876fc',
  );
  */

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Geolocation(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class Geolocation extends StatefulWidget {
  @override
  _GeolocationState createState() => _GeolocationState();
}

class _AddLog {
  final double lat;
  final double long;
  final Timestamp timestamp;
  final String name;

  _AddLog(this.lat, this.long, this.timestamp, this.name);
}

class _GeolocationState extends State<Geolocation> {

  List<_AddLog> logBuffer = [];

  @override
  Widget build(BuildContext context) {
    Timer.periodic(
        new Duration(minutes: 1),
            (timer) async {
          Position position = await _determinePosition();

          logBuffer.add(_AddLog(position.latitude,
              position.latitude,
              Timestamp.now(),
              "Jaewon"));
        }
    );

    Timer.periodic(
        new Duration(hours: 1),
            (timer) {
          if (logBuffer.length < 1)
            return;
          CollectionReference collectionReference = FirebaseFirestore.instance.collection('log');

          for (var log in logBuffer) {
            DocumentReference location = collectionReference.doc(log.timestamp.toString());
            location.set({
              'lat': log.lat,
              'long': log.long,
              'time': log.timestamp,
              'who': log.name,
            })
                .then((value) => print("Log added"))
                .catchError((error) => print("Failed to add log: $error"));
          }

          logBuffer.clear();
        }
    );

    return FutureBuilder<Position>(
      future: _determinePosition(),
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          return Text("Loading...");
        }

        logBuffer.add(_AddLog(
            snapshot.data.latitude,
            snapshot.data.longitude,
            Timestamp.now(),
            "Jaewon"));

        return Text(snapshot.data.toString());
      },
    );
  }

  Future<Position> _determinePosition() async {
    if (!await Permission.location.request().isGranted) {
      return Future.error('Failed to get location permission.');
    }

    if (!await Permission.locationAlways.request().isGranted) {
      return Future.error('Failed to get locationAlways permission.');
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permantly denied, we cannot request permissions.');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return Future.error(
            'Location permissions are denied (actual value: $permission).');
      }
    }

    return await Geolocator.getCurrentPosition();
  }
}
