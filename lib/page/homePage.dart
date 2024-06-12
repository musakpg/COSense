import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sendgrid_mailer/sendgrid_mailer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmanager/workmanager.dart';
import 'signInPage.dart';
import 'settingProfile.dart';
import 'settingEmergency.dart';
import 'adminPage.dart';
import 'dart:io' show Platform;

const initializationSettingsAndroid = AndroidInitializationSettings('icon');

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double coRate = 0;
  double previousCoRate = 0;
  String carState = 'safe';
  List<CODataPoint> coDataPoints = [];
  double latitude = 0;
  double longitude = 0;

  CODataPoint? selectedDataPoint;

  late FirebaseDatabase database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    coRate = 0; // Initialize CO rate to 0 PPM
    initFirebase();
    _initializeNotifications();

    Workmanager().registerPeriodicTask(
      'fetchCoData',
      'fetchCoDataTask',
      frequency: Duration(minutes: 15),
    );
    _loadDataFromFirestore(); // Load data from Firestore when the app starts
  }

  void updateDataPoints(List<CODataPoint> newPoints) {
    setState(() {
      if (newPoints.isNotEmpty) {
        previousCoRate = coRate;
        coRate = newPoints.last.coRate;
        carState = _determineCarState(coRate);
        coDataPoints = newPoints;
      }
    });
    _saveDataToFirestore();
    if (carState == 'danger') {
      _notifyEmergencyContact();
    } else if (carState == 'warning') {
      _showWarningAlert();
    } else if (carState == 'caution') {
      _showCautionNotification();
    }
  }

  String _determineCarState(double coRate) {
    if (coRate < 0.3) {
      return 'safe';
    } else if (coRate < 1.7) {
      return 'warning';
    } else {
      return 'danger';
    }
  }

  double _calculateChangePercentage(double newRate, double oldRate) {
    if (oldRate == 0) return 0;
    return ((newRate - oldRate) / oldRate) * 100;
  }

  void _loadDataFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final coDataPointsRef = _firestore.collection('users').doc(userId).collection('coDataPoints');
      final snapshot = await coDataPointsRef.orderBy('time', descending: false).get();

      final newPoints = snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = (data['time'] as Timestamp).toDate(); // Convert Firestore Timestamp to DateTime
        final coRate = data['coRate'] as double; // Retrieve the double value
        return CODataPoint(timestamp, coRate);
      }).toList();

      print("Fetched data points: $newPoints");

      setState(() {
        coDataPoints = newPoints;
        if (newPoints.isNotEmpty) {
          previousCoRate = coRate;
          coRate = newPoints.last.coRate;
          carState = _determineCarState(coRate);
        }
      });

      print("Updated state with data points: $coDataPoints");
    }
  }

  void _saveDataToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final batch = _firestore.batch();
      final collectionRef = _firestore.collection('users').doc(userId).collection('coDataPoints');

      for (var point in coDataPoints) {
        final docRef = collectionRef.doc(point.time.toIso8601String());
        batch.set(docRef, {
          'time': Timestamp.fromDate(point.time), // Convert DateTime to Firestore Timestamp
          'coRate': point.coRate, // Store as double
        });
      }

      await batch.commit();
      print("Saved data points to Firestore: $coDataPoints");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.only(left: 290.0),
          child: Text(
            'Carbon Monoxide',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
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
                          leading: Icon(Icons.person, color: Colors.blue),
                          title: Text('Profile Settings', style: TextStyle(color: Colors.blue)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SettingProfile()),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.contact_phone, color: Colors.blue),
                          title: Text('Emergency Contact Settings', style: TextStyle(color: Colors.blue)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EmergencySetupScreen()),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.admin_panel_settings, color: Colors.blue),
                          title: Text('Admin Page', style: TextStyle(color: Colors.blue)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminPage(onUpdateData: updateDataPoints, initialDataPoints: coDataPoints)),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.blue),
                          title: Text('Logout', style: TextStyle(color: Colors.blue)),
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
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                elevation: 5.0,  // Adjust the elevation value as needed
                shadowColor: Colors.black,  // Black shadow color
                borderRadius: BorderRadius.circular(15.0),
                child: ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current level',
                        style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'CO',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '${coRate.toStringAsFixed(2)} PPM',
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Now ${_calculateChangePercentage(coRate, previousCoRate).toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 18, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Material(
                elevation: 5.0,
                shadowColor: Colors.black,
                borderRadius: BorderRadius.circular(15.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 450,
                        child: coDataPoints.isNotEmpty
                            ? charts.TimeSeriesChart(
                          _createLineData(coDataPoints),
                          animate: true,
                          dateTimeFactory: const charts.LocalDateTimeFactory(),
                          primaryMeasureAxis: charts.NumericAxisSpec(
                            renderSpec: charts.GridlineRendererSpec(
                              labelStyle: charts.TextStyleSpec(
                                fontSize: 10,
                                color: charts.MaterialPalette.black,
                              ),
                              lineStyle: charts.LineStyleSpec(
                                thickness: 0,
                                color: charts.MaterialPalette.transparent,
                              ),
                            ),
                          ),
                          domainAxis: charts.DateTimeAxisSpec(
                            renderSpec: charts.SmallTickRendererSpec(
                              labelStyle: charts.TextStyleSpec(
                                fontSize: 10,
                                color: charts.MaterialPalette.black,
                              ),
                              lineStyle: charts.LineStyleSpec(
                                thickness: 0,
                                color: charts.MaterialPalette.transparent,
                              ),
                            ),
                          ),
                          defaultRenderer: charts.LineRendererConfig(
                            includeArea: true,
                            stacked: false,
                            areaOpacity: 0.2,
                            strokeWidthPx: 2.0,
                          ),
                          selectionModels: [
                            charts.SelectionModelConfig(
                              type: charts.SelectionModelType.info,
                              changedListener: _onSelectionChanged,
                            ),
                          ],
                        )
                            : Center(child: Text('Loading CO Data...')),
                      ),
                      SizedBox(height: 10),
                      GestureDetector(
                        onLongPressStart: (_) => _showThresholdsDialog(context),
                        onLongPressEnd: (_) => _hideThresholdsDialog(),
                        child: Center(
                          child: Text(
                            carState == 'danger'
                                ? 'Danger'
                                : carState == 'warning'
                                ? 'Warning'
                                : 'Safe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: carState == 'danger'
                                  ? Colors.red
                                  : carState == 'warning'
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              if (selectedDataPoint != null)
                Material(
                  elevation: 5.0, // Adjust the elevation as needed
                  shadowColor: Colors.black,
                  borderRadius: BorderRadius.circular(15.0),
                  child: ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    title: Text('Selected CO Rate', style: TextStyle(color: Colors.blue)),
                    subtitle: Text(
                      'Rate: ${selectedDataPoint!.coRate} PPM\nTime: ${selectedDataPoint!.time}',
                      style: TextStyle(color: Colors.black),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.clear, color: Colors.blue),
                      onPressed: () {
                        setState(() {
                          selectedDataPoint = null;
                        });
                      },
                    ),
                  ),
                ),
              SizedBox(height: 20.0),
              Material(
                elevation: 5.0,  // Adjust the elevation value as needed
                shadowColor: Colors.black,  // Black shadow color
                borderRadius: BorderRadius.circular(15.0),
                child: Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Column(
                    children: [
                      if (carState == 'danger' || carState == 'warning') ...[
                        SizedBox(height: 20),
                        Text(
                          'Actions',
                          style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        SizedBox(height: 10),
                        ListTile(
                          tileColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                          ),
                          leading: Icon(Icons.medical_services, color: Colors.white),
                          title: Text(
                            'Reduce your exposure to CO',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        Divider(height: 10, thickness: 1, color: Colors.white), // Add divider for separation
                        ListTile(
                          tileColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(15.0), top: Radius.circular(15.0)),
                          ),
                          leading: Icon(Icons.power_off, color: Colors.white),
                          title: Text(
                            'Turn off the car and get out',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        Divider(height: 10, thickness: 1, color: Colors.white), // Add divider for separation
                        ListTile(
                          tileColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(15.0), top: Radius.circular(15.0)),
                          ),
                          leading: Icon(Icons.phone, color: Colors.white),
                          title: Text(
                            'Call 999',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        Divider(height: 10, thickness: 1, color: Colors.white), // Add divider for separation
                        ListTile(
                          tileColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(15.0), top: Radius.circular(15.0)),
                          ),
                          leading: Icon(Icons.sentiment_satisfied_alt, color: Colors.white),
                          title: Text(
                            'Stay calm and don\'t panic',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> sendEmail(_HomePageState state, String userEmail, String emergencyEmail, String emergencyName, String userName) async {
    final mailer = Mailer('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');
    final toAddress = Address(emergencyEmail);
    final fromAddress = Address(userEmail);
    final latitude = state.latitude;
    final longitude = state.longitude;
    final coRateValue = state.coRate.toStringAsFixed(2);

    final subject = 'URGENT: COSense Alert';
    final locationLink = Platform.isAndroid
        ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
        : 'https://maps.apple.com/?q=$latitude,$longitude';

    final content = Content('text/html',
        '''
        <html>
        <body>
            <h2 style="color: red;">URGENT: COSense Alert</h2>
            <p>Attention to <b>$emergencyName</b>,</p>
            <p><b style="color: red;">$userName's vehicle is in danger.</b></p>
            <p><b>Vehicle CO Rate:</b> <span style="color: red;">$coRateValue PPM (danger level)</span></p>
            <p><b>Current Location of the Car:</b> <a href="$locationLink">Open in Maps</a></p>
            <p><b>Latitude:</b> $latitude</p>
            <p><b>Longitude:</b> $longitude</p>
            <br>
            <p style="color: red;"><b>Please take necessary action immediately to ensure the safety of the vehicle's occupants.</b></p>
            <br>
            <p>Thank you,</p>
            <p><b>COSense Team</b></p>
        </body>
        </html>
        ''');

    final personalization = Personalization([toAddress]);
    final email = Email([personalization], fromAddress, subject, content: [content]);

    mailer.send(email).then((result) {
      print('Email sent successfully!');
    }).catchError((error) {
      print('Error sending email: $error');
    });

    print('Emergency contact is: $emergencyEmail');
    print('User contact is: $userEmail');
    print('User name is: $userName');
    print('CO Rate: $coRateValue PPM');
    print('Latitude: $latitude, Longitude: $longitude');
  }

  Future<void> initFirebase() async {
    try {
      await Firebase.initializeApp();
      database = FirebaseDatabase.instance;
      database.reference().child('rate/coRate').onValue.listen((event) {
        final newCoRate = double.tryParse(event.snapshot.value.toString()) ?? 0;
        setState(() {
          previousCoRate = coRate;
          coRate = newCoRate;
          carState = _determineCarState(coRate);
          coDataPoints.add(CODataPoint(DateTime.now(), coRate));
          if (coDataPoints.length > 100) {
            coDataPoints.removeAt(0);
          }
          _saveDataToFirestore();
        });
        if (carState == 'danger') {
          _notifyEmergencyContact();
        } else if (carState == 'warning') {
          _showWarningAlert();
        } else if (carState == 'caution') {
          _showCautionNotification();
        }
      });

      database.reference().child('gps/latitude').onValue.listen((event) {
        final newLatitude = double.tryParse(event.snapshot.value.toString()) ?? 0;
        setState(() {
          latitude = newLatitude;
        });
      });

      database.reference().child('gps/longitude').onValue.listen((event) {
        final newLongitude = double.tryParse(event.snapshot.value.toString()) ?? 0;
        setState(() {
          longitude = newLongitude;
        });
      });
    } catch (e) {
      print('Error initializing Firebase: $e');
      // Optionally, show an error dialog or message to the user
    }
  }

  void _initializeNotifications() async {
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _showInAppNotification() async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_co_channel',
        'CO Level Alert',
        channelDescription: 'High CO level detected in your car.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'CO Alert',
      ),
    );

    await flutterLocalNotificationsPlugin.show(0, 'High CO Level Detected', 'Please take necessary action.', notificationDetails);
  }

  void _showLocalAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Emergency Alert', style: TextStyle(color: Colors.blue)),
          content: Text('High CO levels detected. Please take necessary action.', style: TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showWarningAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Warning', style: TextStyle(color: Colors.blue)),
          content: Text('Warning: Elevated CO levels detected. Please take caution.', style: TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showCautionNotification() async {
    print('Caution state reached. Showing caution notification.');
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'caution_co_channel',
        'CO Level Caution',
        channelDescription: 'Elevated CO level detected in your car.',
        importance: Importance.low,
        priority: Priority.low,
        ticker: 'CO Caution',
      ),
    );

    await flutterLocalNotificationsPlugin.show(1, 'Elevated CO Level Detected', 'Please be cautious.', notificationDetails);
  }

  Future<void> _notifyEmergencyContact() async {
    print('CO rate exceeded 1.7 ppm. Notifying emergency contact...');
    _showInAppNotification();
    _showLocalAlert();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userId = user.uid;
      final userDocRef = _firestore.collection('users').doc(userId);

      userDocRef.get().then((userSnapshot) {
        if (userSnapshot.exists) {
          final userName = userSnapshot.data()?['profile']['name'] ?? '';
          final userEmail = user.email ?? '';
          final emergencyContacts = userSnapshot.data()?['emergencyContacts'] ?? [];

          for (var contact in emergencyContacts) {
            final contactEmail = contact['email'] ?? '';
            final contactName = contact['name'] ?? ''; // Extract the emergency contact's name
            sendEmail(this, userEmail, contactEmail, contactName, userName); // Pass the emergency contact's name
          }

          if (emergencyContacts.isEmpty) {
            print('No emergency contacts found for user.');
          }
        } else {
          print('Error: User document not found.');
        }
      }).catchError((error) {
        print('Error fetching user data: $error');
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInScreen()),
      );
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  void _showThresholdsDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Barrier',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
        return WillPopScope(
          onWillPop: () async => false, // Disable back button
          child: Center(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CO Level Thresholds',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Safe: CO rate < 0.3 PPM\n'
                          'Warning: 0.3 <= CO rate < 1.7 PPM\n'
                          'Danger: CO rate >= 1.7 PPM',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideThresholdsDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _onSelectionChanged(charts.SelectionModel model) {
    final selectedDatum = model.selectedDatum;
    if (selectedDatum.isNotEmpty) {
      final CODataPoint dataPoint = selectedDatum.first.datum;
      setState(() {
        selectedDataPoint = dataPoint;
      });
    } else {
      setState(() {
        selectedDataPoint = null;
      });
    }
  }

  List<charts.Series<CODataPoint, DateTime>> _createLineData(List<CODataPoint> dataPoints) {
    return [
      charts.Series<CODataPoint, DateTime>(
        id: 'CO Data',
        domainFn: (CODataPoint point, _) => point.time,
        measureFn: (CODataPoint point, _) => point.coRate,
        data: dataPoints,
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
      )
    ];
  }
}

class CODataPoint {
  final DateTime time;
  final double coRate;

  CODataPoint(this.time, this.coRate);
}
