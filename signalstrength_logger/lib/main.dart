import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/services.dart';
import 'package:flutter_internet_signal/flutter_internet_signal.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int? _mobileSignal;
  int? _wifiSignal;
  String? _timeString;
  Timer? timer;
  Position? _ps;



  final _internetSignal = FlutterInternetSignal();

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(Duration(milliseconds: 500), (Timer t) => _getInternetSignal());
  }

  Future<void> _getInternetSignal() async {
    int? mobile;
    int? wifi;
    Position? pos;
    String? data;
    try {
      mobile = await _internetSignal.getMobileSignalStrength();
      wifi = await _internetSignal.getWifiSignalStrength();
      pos = await _determinePosition();
      data = '${DateTime.now().toString()},${pos.latitude.toString()}, ${pos.longitude.toString()},$mobile,$wifi\n';
      writeData(data);
    } on PlatformException catch(e){
      print(e);
    }
    setState(() {
      _timeString = DateTime.now().toString();
      _mobileSignal = mobile;
      _wifiSignal = wifi;
      _ps = pos;

    });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  static Future<String> getExternalDocumentPath() async {
    final plugin = DeviceInfoPlugin();
    final android = await plugin.androidInfo;

    final storageStatus = android.version.sdkInt < 33
        ? await Permission.storage.request()
        : PermissionStatus.granted;
    Directory directory = Directory("");
    if (Platform.isAndroid) {
      directory = Directory("/storage/emulated/0/Download");
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final exPath = directory.path;
    await Directory(exPath).create(recursive: true);
    return exPath;
  }

  static Future<String> get _localPath async {
    final String directory = await getExternalDocumentPath();
    return directory;
  }

  static Future<File> writeData(String bytes) async {
    final path = await _localPath;
    final filename = 'log-${DateTime.now().toString().substring(0,10)}.txt';
    File file= File('$path/$filename');

    return file.writeAsString(bytes, mode: FileMode.append);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Signal strength logger'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: (_timeString!=null)?([
              Text('Time: $_timeString \n'),
              Text('Mobile signal: ${_mobileSignal ?? '--'} [dBm]\n'),
              Text('Wifi signal: ${_wifiSignal ?? '--'} [dBm]\n'),
              Text('GPS Coords: ${_ps?.latitude.toString()}, ${_ps?.longitude.toString()}'),
              ElevatedButton(
                onPressed: ()=>{timer?.cancel()},
                child: const Text('Stop'),
              ),
              Text('©Rishi Kesav Mohan - mohanrishikesav@gmail.com')
            ]):[
              Text('Loading...wait'),
              Text('©Rishi Kesav Mohan - mohanrishikesav@gmail.com')
            ],
          ),
        ),
      ),
    );
  }
}
