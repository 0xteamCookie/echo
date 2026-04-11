// import 'package:sqflite/sqflite.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'dart:typed_data';

// class MeshController {
//   final Database db;

//   MeshController(this.db);

//   // 1. Phone B receives a message from Phone A (e.g. via a GATT Write)
//   Future<List<int>> handleIncomingMessage(List<int> rawData, String senderDeviceId) async {
//     // rawData format: [ttl, msgId_byte1, msgId_byte2, msgId_byte3, msgId_byte4, ...payload]
//     if (rawData.length < 5) return [0x02]; // Malformed packet fallback

//     int ttl = rawData[0];
//     String messageId = _extractMessageId(rawData);
//     List<int> payload = rawData.sublist(5);

//     // 2. Validate TTL
//     if (ttl <= 0) {
//       print("Message expired. Dropping.");
//       return [0x02]; // Reject
//     }

//     // 3. Check if MessageID exists in Database
//     bool exists = await _checkIfMessageExists(messageId);

//     if (exists) {
//       // 4. Message already seen, return Rejected Hex (0x02)
//       print("Duplicate message $messageId received.");
//       return [0x02];
//     } else {
//       // 5. New message: Store it
//       await _storeMessage(messageId, payload, senderDeviceId);
      
//       // 6. Pre-decrement TTL for the next hop and re-broadcast
//       int newTtl = ttl - 1;
//       if (newTtl > 0) {
//          List<int> newRawData = [newTtl, ...rawData.sublist(1, 5), ...payload];
//         _broadcastMessageToNearbyDevices(newRawData, messageId);
//       }

//       // 7. Send Acknowledgement (0x00) back to Phone A
//       return [0x00]; 
//     }
//   }

//   // --- Database operations ---

//   Future<bool> _checkIfMessageExists(String messageId) async {
//     final List<Map<String, dynamic>> maps = await db.query(
//       'messages',
//       where: 'messageId = ?',
//       whereArgs: [messageId],
//     );
//     return maps.isNotEmpty;
//   }

//   Future<void> _storeMessage(String messageId, List<int> payload, String senderDeviceId) async {
//     await db.insert(
//       'messages',
//       {
//         'messageId': messageId,
//         'payload': payload,
//         'senderId': senderDeviceId, // The person who gave it to us initially
//         'timestamp': DateTime.now().millisecondsSinceEpoch,
//       },
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   // --- Broadcasting operations ---

//   void _broadcastMessageToNearbyDevices(List<int> dataToForward, String messageId) async {
//     // 1. Scan for nearby devices using flutter_blue_plus
//     FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

//     FlutterBluePlus.scanResults.listen((results) async {
//       for (ScanResult result in results) {
//         // Filter to ensure we only connect to SOS mesh nodes
//         if (_isMeshNode(result)) {
//            String targetDeviceId = result.device.remoteId.str;
           
//            // Optimization: Check DB so we don't send to a device that already ACk'd this
//            if (await _hasDeviceAcknowledged(messageId, targetDeviceId)) continue;

//            await _forwardDataToDevice(result.device, dataToForward, messageId);
//         }
//       }
//     });
//   }

//   Future<void> _forwardDataToDevice(BluetoothDevice device, List<int> data, String messageId) async {
//     try {
//       // Connect. autoConnect: false is usually faster and prevents background silent bonding.
//       await device.connect(autoConnect: false);
      
//       // Discover SOS Characterstic
//       // Write data to Characteristic without response
//       // Or Wait for the returned [0x00] or [0x02] from device.
      
//       // Assume `response` is the hex returned by the connected device
//       List<int> response = await _writeAndAwaitResponse(device, data); 
      
//       if (response.isNotEmpty && response[0] == 0x00) {
//          // Success! Store this deviceID alongside messageID so we never send it to them again.
//          await _storeDeviceAcknowledgement(messageId, device.remoteId.str);
//       }
      
//       await device.disconnect();
//     } catch (e) {
//       print("Failed to forward to ${device.remoteId.str}: $e");
//     }
//   }

//   // ... SQLite Helpers for _storeDeviceAcknowledgement and _hasDeviceAcknowledged
//   String _extractMessageId(List<int> rawData) {
//     // Just a placeholder. Decode bytes 1-4 into a hex string or UUID.
//     return rawData.sublist(1, 5).join('-');
//   }
// }