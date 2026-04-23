import 'package:uuid/uuid.dart';

String generateMessageId() {
  const Uuid uuid = Uuid();
  return uuid.v4();
}