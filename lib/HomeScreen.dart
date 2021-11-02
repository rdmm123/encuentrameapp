import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:location_app/SelectBondedDevicePage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class HomeScreen extends StatefulWidget {
  final BluetoothDevice? device;
  final BluetoothConnection? connection;
  const HomeScreen({required this.device, required this.connection});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _locationMessage = "";
  String latitude = "";
  String longitude = "";
  String address = "encuentrameapp.sytes.net";
  String port = "5000";
  String plate = "";
  var socket;
  final buttontext = new TextStyle(fontSize: 20.0);
  final coordtext = new TextStyle(fontSize: 22.0);
  bool _sending = false;
  final formKey = GlobalKey<FormState>();
  final TextEditingController plateController = TextEditingController();
  Position? position;
  Stream<Position>? positionStream;
  StreamSubscription<Position>? _positionStreamSubscription;
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  AndroidDeviceInfo? androidInfo;
  String deviceBrand = "";

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _read();
    setState(() {
      plateController.text = plate;
    });
  }

  Future<void> initPlatformState() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    androidInfo = await deviceInfo.androidInfo;
    deviceBrand = androidInfo!.brand!.toLowerCase();
    await Geolocator.requestPermission();
    // await locationClass.requestPermission();
    position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        forceAndroidLocationManager:
            deviceBrand != "xiaomi" && deviceBrand != 'redmi');
    // position = await locationClass.getLocation();
    print(position);
    latitude = position!.latitude.toStringAsFixed(8);
    longitude = position!.longitude.toStringAsFixed(8);
    setState(() {
      _locationMessage = "Latitud: " + latitude + "\nLongitud: " + longitude;
    });
  }

  _read() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'plate';
    String? value = prefs.getString(key);
    if (value != null) {
      setState(() {
        plate = value;
      });
    }
  }

  _save() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'plate';
    prefs.setString(key, plate);
    print('saved plate');
  }

  void _updateCurrentLocation(Position newPosition) {
    position = newPosition;
    latitude = position!.latitude.toStringAsFixed(8);
    longitude = position!.longitude.toStringAsFixed(8);
    setState(() {
      _locationMessage = "Latitud: " + latitude + "\nLongitud: " + longitude;
    });
    _sendLocation();
  }

  void _sendLocation() {
    print("Mensaje enviado");
    print(position);

    String msg = latitude + "," + longitude;

    String datetime = DateFormat("yyyy-MM-dd,HH:mm:ss")
        .format(position!.timestamp!.toLocal());

    RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
        .then((RawDatagramSocket socket) {
      InternetAddress.lookup(address).then((value) {
        print('Sending to ${address}:${int.parse(port)}');
        socket.send(utf8.encode(msg + "," + datetime + "," + plate), value[0],
            int.parse(port));
      });
    });
    print(msg + "," + datetime + "," + plate);
  }

  void _setFormFields() {
    if (plate != null) {
      plateController.text = plate;
    }
  }

  Widget sendButton() {
    return ElevatedButton(
      onPressed: () {
        final isValid = formKey.currentState!.validate();
        if (isValid) {
          formKey.currentState!.save();

          setState(() {
            _sending = true;
          });
          if (positionStream == null) {
            final positionStream = Geolocator.getPositionStream(
                desiredAccuracy: LocationAccuracy.bestForNavigation,
                intervalDuration: Duration(seconds: 4),
                distanceFilter: 15,
                forceAndroidLocationManager:
                    deviceBrand != "xiaomi" && deviceBrand != 'redmi');
            print(positionStream);
            _positionStreamSubscription = positionStream.listen(
                (Position newPosition) => _updateCurrentLocation(newPosition));
          } else {
            setState(() {
              _positionStreamSubscription!.resume();
            });
          }

          Fluttertoast.showToast(
              msg: "Envío de ubicación iniciado.",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              fontSize: 16);
        }
      },
      child: Text(
        "Enviar ubicación",
        style: buttontext,
      ),
      style: TextButton.styleFrom(
          primary: Colors.white,
          backgroundColor: Theme.of(context).primaryColor),
    );
  }

  Widget stopButton() {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _positionStreamSubscription!.pause();
          _sending = false;
        });
      },
      child: Text(
        "Detener",
        style: buttontext,
      ),
      style: TextButton.styleFrom(
          primary: Colors.white, backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Encuéntrame"),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => SelectBondedDevicePage(allowSkip: false,)));
            },
            icon: Icon(
              Icons.bluetooth,
              color: Colors.white,
            ),
            label: Text(
              widget.device == null ? "N/A" : widget.device!.name!,
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
      body: Align(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(bottom: 60),
                child: SizedBox(
                  width: 130,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Icon(
                      Icons.location_on,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 70),
                child: Text(
                  _locationMessage,
                  style: coordtext,
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 90),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextButton(
                          onPressed: () {
                            final isValid = formKey.currentState!.validate();
                            if (isValid) {
                              formKey.currentState!.save();

                              final snackbar = SnackBar(
                                content: const Text(
                                    'Placa establecida como predeterminada.'),
                              );
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackbar);
                              _save();
                            }
                          },
                          child: Text("Establecer como predeterminado",
                              style: TextStyle(fontSize: 15.0)),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(50, 30),
                            // backgroundColor: Colors.blue
                          )),
                      TextFormField(
                        decoration: new InputDecoration(
                          labelText: "Placa",
                          border: OutlineInputBorder(),
                        ),
                        style: TextStyle(fontSize: 20.0, color: Colors.black),
                        // onSaved: ,
                        onSaved: (String? value) {
                          setState(() => plate = value!);
                        },
                        enabled: !_sending,
                        controller: plateController,
                        validator: (value) {
                          if (value == "") {
                            return "La placa no puede estar vacía.";
                          } else {
                            return null;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 40, right: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: !_sending ? sendButton() : stopButton(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
