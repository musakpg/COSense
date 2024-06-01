import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sendgrid_mailer/sendgrid_mailer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fypcosense/page/signInPage.dart'; // Ensure this import is correct
import 'package:fypcosense/page/settingProfile.dart';
import 'package:fypcosense/page/settingEmergency.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const initializationSettingsAndroid = AndroidInitializationSettings('icon');

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double coRate = 0;
  double previousCoRate = 0;
  String carState = '';
  String userName = 'User'; // Define the userName variable
  List<CODataPoint> coDataPoints = [];
  bool showArrowIcon = false;

  late FirebaseDatabase database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    initFirebase();
    _loadDataPoints();
    Workmanager().registerPeriodicTask(
      "1",
      "fetchCOData",
      frequency: Duration(minutes: 15),
    );
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge) {
        bool isTop = _scrollController.position.pixels == 0;
        setState(() {
          showArrowIcon = !isTop;
        });
      }
    });
  }

  Future<void> _loadDataPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final dataPoints = prefs.getStringList('coDataPoints') ?? [];
    setState(() {
      coDataPoints = dataPoints.map((e) {
        final parts = e.split(':');
        return CODataPoint(DateTime.parse(parts[0]), double.parse(parts[1]));
      }).toList();
      if (coDataPoints.isNotEmpty) {
        coRate = coDataPoints.last.coRate;
        previousCoRate = coDataPoints.length > 1 ? coDataPoints[coDataPoints.length - 2].coRate : 0;
      }
    });
  }

  double _calculateChangePercentage(double newRate, double oldRate) {
    if (oldRate == 0) return 0;
    return ((newRate - oldRate) / oldRate) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Text(
                'Carbon Monoxide',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.settings),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (BuildContext context) {
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              leading: Icon(Icons.person),
                              title: Text('Profile Settings'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SettingProfile()),
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.contact_phone),
                              title: Text('Emergency Contact Settings'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => EmergencySetupScreen()),
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.logout),
                              title: Text('Logout'),
                              onTap: () {
                                _signOut();
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current level',
              style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CO',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  '${coRate.toStringAsFixed(2)} PPM',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      'Now',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                    SizedBox(width: 5), // Adjust the spacing between the text widgets
                    Text(
                      '${_calculateChangePercentage(coRate, previousCoRate).toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 18,
                        color: _calculateChangePercentage(coRate, previousCoRate) < 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _scrollController,
                  child: Container(
                    height: 200,
                    width: coDataPoints.isNotEmpty ? 800 : double.infinity, // Adjust width as needed
                    child: coDataPoints.isNotEmpty
                        ? charts.TimeSeriesChart(
                      _createLineData(coDataPoints),
                      animate: true,
                      dateTimeFactory: const charts.LocalDateTimeFactory(),
                      behaviors: [
                        charts.PanAndZoomBehavior(),
                        charts.SeriesLegend(),
                      ],
                      primaryMeasureAxis: charts.NumericAxisSpec(
                        tickProviderSpec:
                        charts.BasicNumericTickProviderSpec(desiredTickCount: 5),
                      ),
                      domainAxis: charts.DateTimeAxisSpec(
                        tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
                          hour: charts.TimeFormatterSpec(
                            format: 'HH:mm',
                            transitionFormat: 'HH:mm',
                          ),
                        ),
                      ),
                    )
                        : Center(child: Text('Loading CO Data...')),
                  ),
                ),
                if (showArrowIcon)
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: Icon(Icons.arrow_forward),
                      onPressed: () {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10),
            Center(
              child: Text(
                carState == 'danger' ? 'Danger' : 'Safe',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: carState == 'danger' ? Colors.red : Colors.green),
              ),
            ),
            if (carState == 'danger') ...[
              SizedBox(height: 20),
              Text(
                'Actions',
                style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                '   Reduce your exposure to CO',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                '   Turn off the car and get out',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                '   Call emergency services immediately',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                '   If feeling unwell, seek medical attention',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> sendEmail(String userEmail, String emergencyEmail, String userName) async {
    final mailer =
    Mailer('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');
    final toAddress = Address(emergencyEmail);
    final fromAddress = Address(userEmail);
    final content = Content('text/plain', 'Alert!!! $userName\'s vehicle is in danger');
    final subject = 'COSense Alert';
    final personalization = Personalization([toAddress]);

    final email = Email([personalization], fromAddress, subject, content: [content]);
    mailer.send(email).then((result) {
      print('Email sent successfully!');
    }).catchError((error) {
      print('Error sending email: $error');
    });
  }

  void initFirebase() async {
    await Firebase.initializeApp();
    database = FirebaseDatabase.instance;
    database
        .reference()
        .child('rate')
        .onValue
        .listen((DatabaseEvent event) {
      setState(() {
        previousCoRate = coRate;
        coRate = double.tryParse(event.snapshot.value.toString()) ?? 0;
        if (coDataPoints.length >= 100) {
          coDataPoints.removeAt(0);
        }
        _saveDataPoints();
        carState = coRate > 100 ? 'danger' : 'safe';
      });
      if (carState == 'danger') {
        _triggerNotification();
      }
    });
  }

  Future<void> _saveDataPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final dataPoints = coDataPoints.map((e) => '${e.time}:${e.coRate}').toList();
    prefs.setStringList('coDataPoints', dataPoints);
  }

  void _triggerNotification() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    final AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      channelDescription: 'your channel description',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      'Alert! by CoSense',
      '$userName vehicle reach danger level!',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  List<charts.Series<CODataPoint, DateTime>> _createLineData(List<CODataPoint> data) {
    return [
      charts.Series<CODataPoint, DateTime>(
        id: 'CO Data',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (CODataPoint dataPoint, _) => dataPoint.time,
        measureFn: (CODataPoint dataPoint, _) => dataPoint.coRate,
        data: data,
      ),
    ];
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SignInScreen()),
    );
  }
}

class CODataPoint {
  final DateTime time;
  final double coRate;

  CODataPoint(this.time, this.coRate);
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Retrieve the latest CO rate from the database
    final database = FirebaseDatabase.instance;
    final coRateSnapshot = await database.reference().child('rate/coRate').once();
    final coRate = double.tryParse(coRateSnapshot.snapshot.value.toString()) ?? 0;

    // Save the CO rate to shared preferences
    final prefs = await SharedPreferences.getInstance();
    final coDataPoints = prefs.getStringList('coDataPoints') ?? [];
    final newPoint = '${DateTime.now()}:$coRate';
    coDataPoints.add(newPoint);
    if (coDataPoints.length > 100) {
      coDataPoints.removeAt(0);
    }
    prefs.setStringList('coDataPoints', coDataPoints);

    // Check if the vehicle is in danger
    if (coRate > 100) {
      // Trigger a local notification
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      final AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'your channel id',
        'your channel name',
        channelDescription: 'your channel description',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      await flutterLocalNotificationsPlugin.show(
        0,
        'Alert! by CoSense',
        'Vehicle reached danger level!',
        platformChannelSpecifics,
        payload: 'item x',
      );
    }

    return Future.value(true);
  });
}
