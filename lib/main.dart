import 'package:backdrop/app_bar.dart';
import 'package:backdrop/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:flutter_beep/flutter_beep.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GeofenceService? _geofenceService;
  final List<String> _messages = List.empty(growable: true);

  @override
  void initState() {
    super.initState();
    _startGeofenceService();
    _hookupListeners();
//    _addGeofences();
  }

  void _startGeofenceService() {
    // Create a [GeofenceService] instance and set options.
    _geofenceService = GeofenceService.instance.setup(
        interval: 300000,
        accuracy: 100,
        loiteringDelayMs: 5000,
        statusChangeDelayMs: 10000,
        useActivityRecognition: true,
        allowMockLocations: false,
        printDevLog: false,
        geofenceRadiusSortType: GeofenceRadiusSortType.DESC);
    _geofenceService?.start([]).catchError(_onError);
  }

  void _hookupListeners() {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      _geofenceService
          ?.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
      _geofenceService?.addLocationChangeListener(_onLocationChanged);
      _geofenceService?.addLocationServicesStatusChangeListener(
          _onLocationServicesStatusChanged);
      _geofenceService?.addActivityChangeListener(_onActivityChanged);
      _geofenceService?.addStreamErrorListener(_onError);
    });
  }

  void _addGeofences() {
    _print("Add geofences");

    // cx = @-23.5976395,-46.6870598
    // home = @-23.5314532,-46.545045
    final _geofenceList = <Geofence>[
      Geofence(
        id: 'cx',
        latitude: -23.5976395,
        longitude: -46.6870598,
        radius: [
          GeofenceRadius(id: 'radius_100m', length: 100),
          GeofenceRadius(id: 'radius_25m', length: 25),
          GeofenceRadius(id: 'radius_250m', length: 250),
          GeofenceRadius(id: 'radius_1000m', length: 1000),
        ],
      ),
      Geofence(
        id: 'home',
        latitude: -23.5314532,
        longitude: -46.545045,
        radius: [
          GeofenceRadius(id: 'radius_25m', length: 25),
          GeofenceRadius(id: 'radius_100m', length: 100),
          GeofenceRadius(id: 'radius_1000m', length: 1000),
        ],
      ),
    ];
    _geofenceService?.start(_geofenceList).catchError(_onError);
  }

  // This function is to be called when the geofence status is changed.
  Future<void> _onGeofenceStatusChanged(
      Geofence geofence,
      GeofenceRadius geofenceRadius,
      GeofenceStatus geofenceStatus,
      Location location) async {
    _print('geofence: ${geofence.toJson()}');
    _print('geofenceRadius: ${geofenceRadius.toJson()}');
    _print('geofenceStatus: ${geofenceStatus.toString()}');
  }

  // This function is to be called when the activity has changed.
  void _onActivityChanged(Activity prevActivity, Activity currActivity) {
    _print('prevActivity: ${prevActivity.toJson()}');
    _print('currActivity: ${currActivity.toJson()}');
  }

  // This function is to be called when the location has changed.
  void _onLocationChanged(Location location) {
    _print('location: ${location.toJson()}');
  }

  // This function is to be called when a location services status change occurs
  // since the service was started.
  void _onLocationServicesStatusChanged(bool status) {
    _print('isLocationServicesEnabled: $status');
  }

  // This function is used to handle errors that occur in the service.
  void _onError(error) {
    final errorCode = getErrorCodesFromError(error);
    if (errorCode == null) {
      _print('Undefined error: $error');
      return;
    }

    _print('ErrorCode: $errorCode');
  }

  void _print(String message) {
    // ignore: avoid_print
    print(message);
    setState(() {
      _messages.add(message);
      while (_messages.length >= 1000) {
        _messages.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WillStartForegroundTask(
        onWillStart: () async {
          // You can add a foreground task start condition.
          return _geofenceService?.isRunningService ?? false;
        },
        androidNotificationOptions: const AndroidNotificationOptions(
          channelId: 'geofence_service_notification_channel',
          channelName: 'Geofence Service Notification',
          channelDescription:
              'This notification appears when the geofence service is running in the background.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          isSticky: false,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        notificationTitle: 'Geofence Service is running',
        notificationText: 'Tap to return to the app',
        child: MyHomePage(
            title: 'Geofences',
            messages: _messages,
            add: _addGeofenceToService),
      ),
    );
  }

  void _addGeofenceToService(String name, double lat, double long) {
    final geofence = Geofence(
      id: name,
      latitude: lat,
      longitude: long,
      radius: [
        GeofenceRadius(id: 'radius_1000m', length: 1000),
      ],
    );

    _geofenceService?.addGeofence(geofence);
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {Key? key,
      required this.title,
      required this.messages,
      required this.add})
      : super(key: key);
  final String title;
  final List<String> messages;
  final Function(String, double, double) add;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return BackdropScaffold(
      appBar: BackdropAppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await _addGeofence();
                if (result != null) {
                  _addGeofenceToService(result);
                }
              }),
        ],
      ),
      backLayer: const GeofencesList(),
      frontLayer: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        reverse: true,
        itemCount: widget.messages.length,
        itemBuilder: (context, index) => ListTile(
          leading: _getIcon(widget.messages[index]),
          title: Text(widget.messages[index]),
          trailing: Text("$index"),
        ),
        separatorBuilder: (context, index) => const Divider(),
      ),
    );
  }

  Future<Map<String, String>?> _addGeofence() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final longController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('AlertDialog Title'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Local"),
                ),
                TextField(
                  controller: latController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Latitude"),
                ),
                TextField(
                  controller: longController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Longitude"),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                Navigator.of(context).pop({
                  "name": nameController.text,
                  "lat": latController.text,
                  "long": longController.text,
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget? _getIcon(String message) {
    final parts = message.split(":");
    if (parts.length == 1) {
      return null;
    }

    switch (parts[0].toLowerCase()) {
      case "geofence":
        processGeofence(parts);
        return const Icon(Icons.explore);
      case "location":
        return const Icon(Icons.location_on);
      case "curractivity":
        return const Icon(Icons.electric_scooter);
      default:
        return null;
    }
  }

  void processGeofence(List<String> parts) {
    FlutterBeep.beep();
  }

  void _addGeofenceToService(Map<String, String> result) {
    if (result["lat"] != null && result["long"] != null) {
      final name = result["name"] ?? "place";
      final lat = double.parse(result["lat"]!);
      final long = double.parse(result["lat"]!);

      widget.add(name, lat, long);
    }
  }
}

class GeofencesList extends StatelessWidget {
  const GeofencesList({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("background"));
  }
}
