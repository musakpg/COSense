import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sendgrid_mailer/sendgrid_mailer.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:fypcosense/page/signInPage.dart';
import 'package:fypcosense/page/settingProfile.dart'; // Import SettingProfile page
import 'package:fypcosense/page/settingEmergency.dart'; // Import SettingEmergency page

// Constant variables for notification initialization (replace icon with your notification icon)
const initializationSettingsAndroid = AndroidInitializationSettings('icon');

class homePage extends StatefulWidget {
  const homePage({Key? key}) : super(key: key);
  @override
  _homePageState createState() => _homePageState();
}

class _homePageState extends State<homePage> {
  double coRate = 0; // Initial value
  double previousCoRate = 0; // Previous CO rate to calculate the change percentage
  String carState = ''; // Variable to hold car state
  List<CODataPoint> coDataPoints = []; // List to hold CO data points

  // Initialize Firebase
  late FirebaseDatabase database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance
  final FirebaseAuth _auth = FirebaseAuth.instance; // FirebaseAuth instance

  @override
  void initState() {
    super.initState();
    initFirebase();
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
        title: Align(
          alignment: Alignment.center,
          child: Text(
            'Carbon Monoxide',
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          IconButton(
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
                            Navigator.pop(context); // Close the bottom sheet
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SettingProfile()), // Navigate to profile settings screen
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.contact_phone),
                          title: Text('Emergency Contact Settings'),
                          onTap: () {
                            Navigator.pop(context); // Close the bottom sheet
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EmergencySetupScreen()), // Navigate to emergency contact settings screen
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Logout'),
                          onTap: () {
                            _signOut(); // Perform logout action
                            Navigator.pop(context); // Close the bottom sheet
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
                SizedBox(height: 5), // Adjust the spacing between lines
                Text(
                  '${coRate.toStringAsFixed(2)} PPM',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5), // Adjust the spacing between lines
                Text(
                  'Now ${_calculateChangePercentage(coRate, previousCoRate).toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 18, color: Colors.green),
                ),
              ],
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              child: coDataPoints.isNotEmpty
                  ? charts.TimeSeriesChart(
                _createLineData(coDataPoints),
                animate: true,
                dateTimeFactory: const charts.LocalDateTimeFactory(),
              )
                  : Center(child: Text('Loading CO Data...')),
            ),
            SizedBox(height: 10),
            Text(
              carState == 'danger' ? 'Danger' : 'Safe',
              style: TextStyle(fontSize: 18, color: carState == 'danger' ? Colors.red : Colors.green),
            ),
            if (carState == 'danger') ...[
              SizedBox(height: 20),
              Text(
                'Actions',
                style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                '• Reduce your exposure to CO',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 5),
              Text(
                '• Turn off the car and get out',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    textStyle: TextStyle(fontSize: 20), // Removed color property
                  ),
                  onPressed: () {
                    // Implement your emergency call action
                  },
                  child: Text(
                    'Call 999',
                    style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold), // Added text color property
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> sendEmail(String userEmail, String emergencyEmail, String userName) async {
    final mailer = Mailer('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');
    final toAddress = Address(emergencyEmail); // Use emergency email fetched from Firestore
    final fromAddress = Address(userEmail); // Use user email fetched from FirebaseAuth
    final content = Content('text/plain', 'Alert!!! $userName\'s vehicle is in danger'); // Use user's name in content
    final subject = 'COSense Alert';
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
  }

  Future<void> initFirebase() async {
    await Firebase.initializeApp();
    database = FirebaseDatabase.instance;
    // Listen to changes in Firebase database
    database.reference().child('rate/coRate').onValue.listen((event) {
      final newCoRate = double.tryParse(event.snapshot.value.toString()) ?? 0;
      setState(() {
        previousCoRate = coRate;
        coRate = newCoRate;
        // Update CO data points
        coDataPoints.add(CODataPoint(DateTime.now(), coRate));
        // Keep only the last 100 data points for display
        if (coDataPoints.length > 100) {
          coDataPoints.removeAt(0);
        }
        // Set car state based on coRate
        if (coRate >= 0.20) { // Change to 0.05 ppm
          carState = 'danger';
          _notifyEmergencyContact(); // Notify if in danger state
        } else {
          carState = 'normal';
        }
      });
    });
  }


  // Function to display an in-app notification using flutter_local_notifications
  void _showInAppNotification() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

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

  // Function to display a local alert
  void _showLocalAlert() {
    // Implement local alert using showDialog or another method to display an alert dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Emergency Alert'),
          content: Text('High CO levels detected. Please take necessary action.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _notifyEmergencyContact() {
    print('CO rate exceeded 0.20 ppm. Notifying emergency contact...'); // Change to 0.05 ppm
    _showInAppNotification(); // Alternative 6: Display in-app notification
    _showLocalAlert(); // Alternative 7: Display local alert

    // Fetch user's data from FirebaseAuth
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userId = user.uid; // Get the user ID
      final userDocRef = _firestore.collection('users').doc(userId);

      userDocRef.get().then((userSnapshot) {
        if (userSnapshot.exists) {
          final userName = userSnapshot.data()?['profile']['name'] ?? ''; // User's name (ensure existence)
          final userEmail = user.email ?? ''; // Null-safe assignment
          final emergencyContacts = userSnapshot.data()?['emergencyContacts'] ?? []; // User's emergency contacts (ensure existence)

          // Loop through all emergency contacts
          for (var contact in emergencyContacts) {
            final contactEmail = contact['email'] ?? '';
            sendEmail(userEmail, contactEmail, userName);
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

  // Function to sign out the user
  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInScreen()),
      );
    } catch (e) {
      print('Error signing out: $e');
      // Handle sign-out errors here
    }
  }

  // Create data for Line Chart
  List<charts.Series<CODataPoint, DateTime>> _createLineData(List<CODataPoint> dataPoints) {
    return [
      charts.Series<CODataPoint, DateTime>(
        id: 'CO Data',
        domainFn: (CODataPoint point, _) => point.time,
        measureFn: (CODataPoint point, _) => point.coRate,
        data: dataPoints,
      )
    ];
  }
}

// Class to represent CO data points
class CODataPoint {
  final DateTime time;
  final double coRate;

  CODataPoint(this.time, this.coRate);
}
