import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:location/location.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Encuéntrame',
      theme: ThemeData(
     
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _locationMessage = "";
  String latitude = "";
  String longitude = "";
  var socket, address, port;
  final buttontext = new TextStyle(fontSize: 20.0);
  final coordtext = new TextStyle(fontSize: 22.0);
  bool _sending = false;
  final formKey = GlobalKey<FormState>();
  var favorites = <String>{};
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController = TextEditingController();
  Location locationClass = new Location();
  LocationData? position;
  Stream<LocationData>? positionStream;
  StreamSubscription<LocationData>? _positionStreamSubscription;



  @override
  void initState() {
    super.initState();
    initPlatformState();
    _read();
  }

  Future<void> initPlatformState() async {
   
    await locationClass.requestPermission();
    position = await locationClass.getLocation();
    print(position);
    latitude = position!.latitude!.toStringAsFixed(8);
    longitude = position!.longitude!.toStringAsFixed(8);
    setState(() {
      _locationMessage =
          "Latitud: " + latitude + "\nLongitud: " + longitude;
    });
    locationClass.changeSettings(interval: 8000, distanceFilter: 15);
  }

  _read() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'favorites';
    List<String>? value = prefs.getStringList(key);
    if (value != null) {
      favorites = value.toSet();
    }
  }

  _save() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'favorites';
    prefs.setStringList(key, favorites.toList());
    print('saved favorites');
  }

  void _updateCurrentLocation(LocationData newPosition) async {
    position = newPosition;
    latitude = position!.latitude!.toStringAsFixed(8);
    longitude = position!.longitude!.toStringAsFixed(8);
    setState(() {
      _locationMessage =
          "Latitud: " + latitude + "\nLongitud: " + longitude;
    });
    _sendLocation();
  }
  void _sendLocation() {
    print("Mensaje enviado");
    print(position);
    
    String msg = latitude + "," + longitude;

    String datetime = DateFormat("yyyy-MM-dd,HH:mm:ss").format(DateTime.fromMillisecondsSinceEpoch(position!.time!.toInt()).toLocal());
    
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)
        .then((RawDatagramSocket socket) {
      InternetAddress.lookup(address).then((value) {
        print('Sending to ${address}:${int.parse(port)}');
        socket.send(utf8.encode(msg + "," + datetime), value[0],
            int.parse(port));
      });
    });
  }

  void _pushFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setPageState) {
            final Iterable<ListTile> tiles = favorites.map(
              (String address) {
                List addressSplit = address.split(':');
                return ListTile(
                  title: Text(
                    'IP: ' + addressSplit[0] + '    Port: ' + addressSplit[1],
                    style: TextStyle(fontSize: 20.0),
                  ),
                  trailing: IconButton(
                      onPressed: () {
                        setState(() => favorites.remove(address));
                        setPageState(() => favorites.remove(address));
                        _save();
                      },
                      icon: Icon(Icons.delete)),
                  onTap: () {
                    Navigator.pop(context);
                    _setFormFields(address);
                  },
                );
              },
            );
            final List<Widget> divided = ListTile.divideTiles(
              context: context,
              tiles: tiles,
            ).toList();

            return Scaffold(
              appBar: AppBar(
                title: Text('Favoritos'),
              ),
              body: ListView(children: divided),
            );
          });
        },
      ),
    );
  }

  void _setFormFields(String address) {
    List addressSplit = address.split(':');
    address = addressSplit[0];
    port = addressSplit[1];
    ipController.text = address;
    portController.text = port;
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
            final positionStream = locationClass.onLocationChanged;
            print(positionStream);
            _positionStreamSubscription = positionStream.listen((LocationData newPosition) =>
                _updateCurrentLocation(newPosition));
          }
          else {
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
          primary: Colors.white,
          backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Encuéntrame"),
        actions: [
          IconButton(onPressed: _pushFavorites, icon: Icon(Icons.star))
        ],
      ),
      body: Align(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: EdgeInsets.only(bottom: 40),
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
                padding: EdgeInsets.only(bottom: 30),
                child: Text(
                  _locationMessage,
                  style: coordtext,
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextButton(
                          onPressed: () {
                            final isValid = formKey.currentState!.validate();
                            if (isValid) {
                              formKey.currentState!.save();
                              String newFav = address + ':' + port;
                              if (!favorites.contains(newFav)) {
                                favorites.add(newFav);

                                final snackbar = SnackBar(
                                  content: const Text('Añadido a favoritos.'),
                                  action: SnackBarAction(
                                      label: 'DESHACER',
                                      onPressed: () {
                                        favorites.remove(newFav);
                                      }),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackbar);
                                _save();
                              }
                            }
                          },
                          child: Text("Añadir a favoritos",
                              style: TextStyle(fontSize: 15.0)),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(50, 30),
                          )),
                      TextFormField(
                        decoration: new InputDecoration(
                          labelText: "Dirección de Destino",
                          border: OutlineInputBorder(),
                        ),
                        style: TextStyle(fontSize: 20.0, color: Colors.black),
                        onSaved: (String? value) {
                          setState(() => address = value);
                        },
                        enabled: !_sending,
                        controller: ipController,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 15, 0, 0),
                        child: TextFormField(
                          decoration: new InputDecoration(
                            labelText: "Número de Puerto",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: 20.0, color: Colors.black),
                          onSaved: (String? value) {
                            setState(() => port = value);
                          },
                          validator: (value) {
                            if (value!.length < 1 || int.parse(value) > 65535) {
                              return "Ingrese un número de puerto válido.";
                            } else {
                              return null;
                            }
                          },
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          enabled: !_sending,
                          controller: portController,
                        ),
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
