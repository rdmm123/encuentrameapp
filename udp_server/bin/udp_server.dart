import 'dart:io';
import 'dart:convert';

void main() {
  var port = 3001;

  // listen forever & send response
  RawDatagramSocket.bind(InternetAddress.anyIPv4, port).then((socket) {
    print('Listening on ${InternetAddress.anyIPv4.address}:$port');

    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        var dg = socket.receive();
        if (dg == null) return;
        final recvd = String.fromCharCodes(dg.data);

        print('\nData from client ${dg.address.address}:${dg.port}');
        print(recvd);
      }
    });
  });
}
