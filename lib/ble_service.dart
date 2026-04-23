import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class WeatherBLEService{

  static const String SERVICE_UUID = "12345678-1234-1234-1234-123456789abc";
  static const String CHARACTERISTIC_UUID = "abcdefab-1234-5678-1234-56789abcdef0";

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetCharacteristic;

  Future<void> startScanning(Function(String) onDataReceived) async {
    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) async{
      for (ScanResult r in results) {
        if (r.device.platformName == "WeatherStation") {
          print("found device ");
          FlutterBluePlus.stopScan();
          await connectToDevice(r.device, onDataReceived);
          break;
        }
      }
    });
}

  Future<void> connectToDevice(BluetoothDevice device, Function(String) onDataReceived) async {
    await (device as dynamic).connect(
  autoConnect: false,
  license: "none" as dynamic,
).timeout(const Duration(seconds: 10));
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      if (service.uuid.toString() == SERVICE_UUID) {
        for(var char in service.characteristics) {
          if (char.uuid.toString() == CHARACTERISTIC_UUID) {
            targetCharacteristic = char;
            

            await targetCharacteristic!.setNotifyValue(true);
            targetCharacteristic!.lastValueStream.listen((value) {
              String ddecodedData = utf8.decode(value);
              onDataReceived(ddecodedData);
            });
          }
        }
      }
    }
  }
}