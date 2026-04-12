import './decode.dart';
import '../database//db_hook.dart';
import '../send/send-message.dart';
import '../packet/get-deviceID.dart'

class MeshController {

  // 1. Phone B receives a message from Phone A (e.g. via a GATT Write)
  Future<List<int>> handleIncomingMessage(String rawData) async {

    final decoded = await decodeAndSaveMessage(rawData);
    if (rawData.length < 5 || decoded == null) return [0x01]; // Malformed packet fallback

    final String messageId = decoded['messageId'];
    final String message = decoded['message'];
    final String deviceId = decoded['deviceId'];
    final String expiresAtStr = decoded['expiresAt'];
    final String location = decoded['location'];

    final DateTime expiresAt = DateTime.parse(expiresAtStr).toUtc();
    final DateTime deviceTime = DateTime.now().toUtc();
    final String currentDeviceId = await DeviceIdManager.getDeviceId();


    // 2. Validate expiresAt
    if (expiresAt.isBefore(deviceTime)) {
      print("Message expired. Dropping.");
      return [0x02]; // Message expired
    }

    // 3. Check duplicate (using DB helper)
    final exists = await messageExists(messageId);

    if (exists) {
      print("Duplicate message $messageId received.");
      return [0x03];
    }

    // 4. Store message using db-hook
    await insertMessage(decoded!);

    // 5. Broadcast
    broadcastMessage( currentDeviceId, messageId, location, expiresAtStr, message);

    // 6. ACK
    return [0x00];
  }
  }

  // --- Broadcasting operations ---
  void _broadcastMessageToNearbyDevices(String rawData) async {
    // 1. Scan for nearby devices using flutter_blue_plus
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult result in results) {
        // Filter to ensure we only connect to SOS mesh nodes
        if (_isMeshNode(result)) {
           String targetDeviceId = result.device.remoteId.str;
           
           // Optimization: Check DB so we don't send to a device that already ACk'd this
           if (await _hasDeviceAcknowledged(messageId, targetDeviceId)) continue;

           await _forwardDataToDevice(result.device, dataToForward, messageId);
        }
      }
    });
  }

  Future<void> _forwardDataToDevice(BluetoothDevice device, List<int> data, String messageId) async {
    try {
      // Connect. autoConnect: false is usually faster and prevents background silent bonding.
      await device.connect(autoConnect: false, license: License.free);
      
      // Discover SOS Characterstic
      // Write data to Characteristic without response
      // Or Wait for the returned [0x00] or [0x02] from device.
      
      // Assume `response` is the hex returned by the connected device
      List<int> response = await _writeAndAwaitResponse(device, data); 
      
      if (response.isNotEmpty && response[0] == 0x00) {
         // Success! Store this deviceID alongside messageID so we never send it to them again.
         await _storeDeviceAcknowledgement(messageId, device.remoteId.str);
      }
      
      await device.disconnect();
    } catch (e) {
      print("Failed to forward to ${device.remoteId.str}: $e");
    }
  }

  // ... SQLite Helpers for _storeDeviceAcknowledgement and _hasDeviceAcknowledged
  String _extractMessageId(List<int> rawData) {
    // Just a placeholder. Decode bytes 1-4 into a hex string or UUID.
    return rawData.sublist(1, 5).join('-');
  }
