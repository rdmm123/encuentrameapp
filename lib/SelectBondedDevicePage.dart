import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import './BluetoothDeviceListEntry.dart';
import 'HomeScreen.dart';

import 'package:fluttertoast/fluttertoast.dart';


class SelectBondedDevicePage extends StatefulWidget {
  /// If true, on page start there is performed discovery upon the bonded devices.
  /// Then, if they are not avaliable, they would be disabled from the selection.
  final bool allowSkip;

  const SelectBondedDevicePage({this.allowSkip = false});

  @override
  _SelectBondedDevicePage createState() => new _SelectBondedDevicePage();
}

class _SelectBondedDevicePage extends State<SelectBondedDevicePage> {
  List<BluetoothDevice> devices = List<BluetoothDevice>.empty(growable: true);
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  _SelectBondedDevicePage();

  _enableBluetooth() async {
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      setState(() {
        _bluetoothState = BluetoothState.STATE_ON;
      });
      _getDevices();
    }
  }

  _getDevices() {
    FlutterBluetoothSerial.instance
        .getBondedDevices()
        .then((List<BluetoothDevice> bondedDevices) {
      setState(() {
        devices = bondedDevices.toList();
      });
    });
  }

  _getActions() {
    List actions = <Widget>[
          IconButton(
            icon: Icon(Icons.replay),
            onPressed: () => _bluetoothState.isEnabled ? _getDevices() : null,
          ),
        ];
    if (widget.allowSkip) {
      actions.insert(0,
        TextButton(
            onPressed: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => HomeScreen(device: null, connection: null,)));
            },
            child: Text("OMITIR", style: TextStyle(color: Colors.white),)
          ),
      );
    }
      return actions;
  }

  showErrorDialog(BuildContext context) {
    // set up the button
    Widget okButton = TextButton(
      child: Text("OK"),
      onPressed: () => Navigator.of(context).pop(),
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Error en la conexión"),
      content: Text("No fue posible conectarse al dispositivo, por favor intente de nuevo."),
      actions: [
        okButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  @override
  void initState() {
    super.initState();

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
      print(_bluetoothState);
      _enableBluetooth();
    });

    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
      });
      print(_bluetoothState);
      _enableBluetooth();
    });

    _getDevices();
  }

  @override
  Widget build(BuildContext context) {
    List<BluetoothDeviceListEntry> list = devices
        .map((_device) => BluetoothDeviceListEntry(
              device: _device,
              onTap: _device.isConnected ? null : () {
                BluetoothConnection.toAddress(_device.address).then((_connection) {
                  print('Connected to the device');
                  Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => HomeScreen(device: _device, connection: _connection,)));
                }).catchError((error) {
                  print('Cannot connect, exception occured');
                  print(error);
                  showErrorDialog(context);
                });
              },
            ))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Seleccionar dispositivo'),
        actions: _getActions(),
      ),
      body: ListView(children: list),
    );
  }
}
