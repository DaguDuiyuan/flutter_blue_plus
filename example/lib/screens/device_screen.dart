import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../widgets/service_tile.dart';
import '../widgets/characteristic_tile.dart';
import '../widgets/descriptor_tile.dart';
import '../utils/snackbar.dart';
import '../utils/extra.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription =
        widget.device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _services = []; // must rediscover services
      }
      if (state == BluetoothConnectionState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }
      if (mounted) {
        setState(() {});
      }
    });

    _mtuSubscription = widget.device.mtu.listen((value) async {
      _mtuSize = value;
      if (mounted) {
        setState(() {});
      }

      for (final s in (await widget.device.discoverServices())
          .where((e) => e.serviceUuid == Guid(_serviceUuid))) {
        for (final c in s.characteristics.where(
            (e) => e.characteristicUuid == Guid(_notifyCharacteristicUUID))) {
          if (await c.setNotifyValue(true)) {
            if (kDebugMode) {
              print(
                'authenticatedSignedWrites: ${c.properties.authenticatedSignedWrites}',
              );
            }
            return;
          }
        }
      }
    });

    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isDisconnectingSubscription =
        widget.device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    FlutterBluePlus.events.onCharacteristicReceived.listen((cr) async {
      print(cr);
      String result = String.fromCharCodes(cr.value);
      final json = jsonDecode(result);
      print("-------------------");
      print(json);
      print("-------------------");
      switch (json['ST_RevType_Key']) {
        case 2:
          var content = "语言（0英语 1中文）：${json['object']['ST_LanguageDataKey']}"
              "\n亮度：${json['object']['ST_BrightnessKey']}"
              "\n背光时长（秒）：${json['object']['ST_BrightDurationKey']}"
              "\n时间格式：${json['object']['ST_HourSystemKey']}"
              "\n抬手亮开光：${json['object']['ST_TrunWristKey']}";

          showStarMaxAttachDialog(title: '设备信息', content: content);
          break;
        case 8:
          var obj = json['object'];
          // 获取时区、时间
          var content = "时区：${obj['ST_ZoneKey']}"
              "\n时间：${obj['ST_YearKey']}-${obj['ST_MonthKey']}-${obj['ST_DayKey']}"
              " ${obj['ST_HourKey']}:${obj['ST_MinuteKey']}:${obj['ST_SecondKey']}";
          showStarMaxAttachDialog(title: '设备时间', content: content);
          break;
        case 136:
          var error = json['ST_ErrorType_Key'];
          if (error == 0) {
            Snackbar.show(ABC.c, "同步成功", success: true);
          }
          break;
        case 129:
          var content =
              "设备绑定 ：${json['object']['ST_DeviceBindKey'] ? "成功" : "失败"}";
          showStarMaxAttachDialog(title: '设备绑定', content: content);
          break;
        case 134:
          var content = "电池电量 ：${json['object']['ST_GetElectricityKey']}\n"
              "是否充电：${json['object']['ST_GetElectricityStateKey'] == 128 ? "是" : "否"}";
          showStarMaxAttachDialog(title: '电池电量', content: content);
          break;

        case 228: // 血压
          if (json['object'].keys.isEmpty) {
            Snackbar.show(ABC.c, "数据为空", success: false);
            break;
          }

          // 数据日期
          final date = json['object']['ST_GetRecordDateTimeKey'] as String;
          var dateTime = DateTime.parse(date);
          var dataList = json['object']['ST_GetRecordValueDataKey']
              .trim()
              .split(" ") as List;

          // 隔一个循环
          var _newValueList = [];
          for (var i = 0; i < dataList.length; i += 2) {
            var high = dataList[i];
            var low = dataList[i + 1];
            var data = {
              "time": dateTime,
              "value": [high, low],
            };
            _newValueList.add(data);
            dateTime = dateTime.add(Duration(minutes: 1));
          }

          _newValueList = _newValueList.where((e) {
            var _t = Set.of((e['value'] as List));
            return _t.length != 1 && _t.first != '255';
          }).toList();

          showStarMaxAttachDialog(
              title: '血压列表',
              content: _newValueList
                  .map((e) =>
                      e['time'].toString().split(".")[0] +
                      ":" +
                      e['value'][0] +
                      "/" +
                      e['value'][1])
                  .join("\n"));
          break;
        case 227: // 心率
        case 229: // 血氧
        case 230: // 压力
          // 判断是否为空
          if (json['object'].keys.isEmpty) {
            Snackbar.show(ABC.c, "数据为空", success: false);
            break;
          }

          // 数据日期
          final date = json['object']['ST_GetRecordDateTimeKey'] as String;
          // 检测间隔
          final interval = json['object']['ST_GetRecordIntervalKey'] as int;
          print(interval);

          // 数据列表
          var dateTime = DateTime.parse(date);
          final dataList = (json['object']['ST_GetRecordValueDataKey']
                  .trim()
                  .split(" ") as List)
              .map((e) {
                var value = {"time": dateTime, "value": e};
                dateTime = dateTime.add(Duration(minutes: 1));
                return value;
              })
              .where((e1) => e1['value'] != '255')
              .toList();
          showStarMaxAttachDialog(
              title: '数据列表',
              content: dataList
                  .map((e) =>
                      e['time'].toString().split(".")[0] + ":" + e['value'])
                  .join("\n"));
          break;
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothConnectionState.connected;
  }

  Future onConnectPressed() async {
    try {
      await widget.device.connectAndUpdateStream();
      Snackbar.show(ABC.c, "Connect: Success", success: true);
    } catch (e) {
      if (e is FlutterBluePlusException &&
          e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        Snackbar.show(ABC.c, prettyException("Connect Error:", e),
            success: false);
      }
    }
  }

  Future onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
    }
  }

  Future onDisconnectPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream();
      Snackbar.show(ABC.c, "Disconnect: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Disconnect Error:", e),
          success: false);
    }
  }

  Future onDiscoverServicesPressed() async {
    if (mounted) {
      setState(() {
        _isDiscoveringServices = true;
      });
    }
    try {
      _services = await widget.device.discoverServices();
      Snackbar.show(ABC.c, "Discover Services: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Discover Services Error:", e),
          success: false);
    }
    if (mounted) {
      setState(() {
        _isDiscoveringServices = false;
      });
    }
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223, predelay: 0);
      Snackbar.show(ABC.c, "Request Mtu: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Change Mtu Error:", e),
          success: false);
    }
  }

  List<Widget> _buildServiceTiles(BuildContext context, BluetoothDevice d) {
    return _services
        .map(
          (s) => ServiceTile(
            service: s,
            characteristicTiles: s.characteristics
                .map((c) => _buildCharacteristicTile(c))
                .toList(),
          ),
        )
        .toList();
  }

  CharacteristicTile _buildCharacteristicTile(BluetoothCharacteristic c) {
    return CharacteristicTile(
      characteristic: c,
      descriptorTiles:
          c.descriptors.map((d) => DescriptorTile(descriptor: d)).toList(),
    );
  }

  Widget buildSpinner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('${widget.device.remoteId}'),
    );
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected
            ? const Icon(Icons.bluetooth_connected)
            : const Icon(Icons.bluetooth_disabled),
        Text(((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''),
            style: Theme.of(context).textTheme.bodySmall)
      ],
    );
  }

  Widget buildGetServices(BuildContext context) {
    return IndexedStack(
      index: (_isDiscoveringServices) ? 1 : 0,
      children: <Widget>[
        TextButton(
          child: const Text("Get Services"),
          onPressed: onDiscoverServicesPressed,
        ),
        const IconButton(
          icon: SizedBox(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.grey),
            ),
            width: 18.0,
            height: 18.0,
          ),
          onPressed: null,
        )
      ],
    );
  }

  Widget buildMtuTile(BuildContext context) {
    return ListTile(
        title: const Text('MTU Size'),
        subtitle: Text('$_mtuSize bytes'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onRequestMtuPressed,
        ));
  }

  Widget buildMtuTile1(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
            title: const Text('获取设备信息'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res =
                    await FlutterBluePlus.starMaxSender('readDeviceState');
                _request(res);
              },
            )),
        ListTile(
            title: const Text('绑定设备'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res =
                await FlutterBluePlus.starMaxSender('writeDeviceBind');
                _request(res);
              },
            )),
        ListTile(
            title: const Text('获取电池电量'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res =
                    await FlutterBluePlus.starMaxSender('readDeviceBattery');
                _request(res);
              },
            )),
        ListTile(
            title: const Text('获取时间/时区'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res =
                    await FlutterBluePlus.starMaxSender('readDeviceDateTime');
                _request(res);
              },
            )),
        ListTile(
            title: const Text('同步时间/时区'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res =
                    await FlutterBluePlus.starMaxSender('writeDeviceDateTime');
                _request(res);
              },
            )),
        ListTile(
            title: const Text('查找设备'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res =
                    await FlutterBluePlus.starMaxSender('writeFindDevice');
                _request(res);
              },
            )),
        ListTile(
            title: const Text('获取心率'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res = await FlutterBluePlus.starMaxSender(
                    'readHeartRateHistoryWithDate');
                _request(res);
              },
            )),
        ListTile(
            title: const Text('获取血压'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res = await FlutterBluePlus.starMaxSender(
                    'readBloodPressureHistoryWithDate');
                _request(res);
              },
            )),
        ListTile(
            title: const Text('获取血氧'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res = await FlutterBluePlus.starMaxSender(
                    'readBloodOxygenHistoryWithDate');
                _request(res);
              },
            )),
        ListTile(
            title: const Text('获取压力'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res = await FlutterBluePlus.starMaxSenderArgs({
                  'type':'readPhysicalPressureHistoryWithDate',
                  'dateStr':'20240930'
                });
                _request(res);
              },
            )),
        ListTile(
            title: const Text('获取数据有效日期列表'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res =
                    await FlutterBluePlus.starMaxSenderArgs({
                      'type':'readHistoryValidDate',
                      'historyType': 2
                    });
                _request(res);
              },
            )),
        ListTile(
            title: const Text('获取步数'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                Snackbar.show(ABC.c, "接入中", success: false);
                // var res = await FlutterBluePlus.starMaxSender('writeFindDevice');
                // _request(res);
              },
            )),
        ListTile(
            title: const Text('推送天气（FIXME）'),
            trailing: IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                var res = await FlutterBluePlus.starMaxSender('writeWeather');
                _request(res);
              },
            )),
      ],
    );
  }

  Future _request(Uint8List value) async {
    for (final s in (await widget.device.discoverServices())
        .where((e) => e.serviceUuid == Guid(_serviceUuid))) {
      for (final c in s.characteristics.where(
          (e) => Guid(_writeCharacteristicsUuid) == e.characteristicUuid)) {
        try {
          await c.write(value);
        } catch (error) {
          if (kDebugMode) {
            print('$value:: $error');
          }
        }
      }
    }
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(children: [
      if (_isConnecting || _isDisconnecting) buildSpinner(context),
      TextButton(
          onPressed: _isConnecting
              ? onCancelPressed
              : (isConnected ? onDisconnectPressed : onConnectPressed),
          child: Text(
            _isConnecting ? "CANCEL" : (isConnected ? "DISCONNECT" : "CONNECT"),
            style: Theme.of(context)
                .primaryTextTheme
                .labelLarge
                ?.copyWith(color: Colors.black),
          ))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName),
          actions: [buildConnectButton(context)],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              buildRemoteId(context),
              ListTile(
                leading: buildRssiTile(context),
                title: Text(
                    'Device is ${_connectionState.toString().split('.')[1]}.'),
                trailing: buildGetServices(context),
              ),
              buildMtuTile(context),
              buildMtuTile1(context),
              ..._buildServiceTiles(context, widget.device),
            ],
          ),
        ),
      ),
    );
  }

  showStarMaxAttachDialog({
    required String title,
    required String content,
  }) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: Text(content),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context), child: Text("确定"))
              ],
            ));
  }
}

final String _serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9d";
final String _notifyCharacteristicUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9d";
final String _writeCharacteristicsUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9d";
