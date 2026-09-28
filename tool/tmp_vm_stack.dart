import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> request(
  WebSocket socket,
  StreamIterator<dynamic> messages,
  int id,
  String method, [
  Map<String, dynamic> params = const {},
]) async {
  socket.add(jsonEncode({
    'jsonrpc': '2.0',
    'id': '$id',
    'method': method,
    'params': params,
  }));
  while (await messages.moveNext()) {
    final decoded = jsonDecode(messages.current as String) as Map<String, dynamic>;
    if (decoded['id'] == '$id') return decoded;
  }
  throw StateError('VM service disconnected');
}

Future<void> main(List<String> arguments) async {
  final socket = await WebSocket.connect(arguments.single);
  final messages = StreamIterator<dynamic>(socket);
  final vm = await request(socket, messages, 1, 'getVM');
  stdout.writeln(jsonEncode(vm));
  final isolates = vm['result']['isolates'] as List<dynamic>;
  var id = 2;
  for (final isolate in isolates) {
    final isolateId = isolate['id'] as String;
    final stack = await request(socket, messages, id++, 'getStack', {
      'isolateId': isolateId,
      'limit': 100,
    });
    stdout.writeln(jsonEncode({
      'isolate': isolate,
      'stack': stack['result'],
    }));
  }
  await socket.close();
}
