import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'adminPage.dart';
import 'homePage.dart';  // Assuming CODataPoint is defined here

class AdminLoginPage extends StatefulWidget {
  @override
  _AdminLoginPageState createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _adminIdController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _errorMessage;

  Future<void> _signIn() async {
    try {
      final adminDoc = await _firestore.collection('admins').doc('adminID').get();
      if (adminDoc.exists) {
        List<dynamic> adminList = adminDoc['admin'];
        bool isValidAdmin = adminList.any((admin) => admin['name'] == _adminIdController.text);

        if (isValidAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminPage(
              onUpdateData: (data) {
                // handle update data here
              },
              initialDataPoints: [],
            )),
          );
        } else {
          setState(() {
            _errorMessage = "Invalid Admin ID.";
          });
        }
      } else {
        setState(() {
          _errorMessage = "Invalid Admin ID.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error signing in: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 10),
            ],
            TextField(
              controller: _adminIdController,
              decoration: InputDecoration(labelText: 'Admin ID'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signIn,
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
