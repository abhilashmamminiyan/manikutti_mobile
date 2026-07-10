import 'dart:mirrors';
import 'package:local_auth/local_auth.dart';

void main() {
  var classMirror = reflectClass(LocalAuthentication);
  for (var entry in classMirror.declarations.entries) {
    var key = entry.key;
    var value = entry.value;
    if (value is MethodMirror && MirrorSystem.getName(key) == 'authenticate') {
      print('Method: ${MirrorSystem.getName(key)}');
      for (var p in value.parameters) {
        print('  Param: ${MirrorSystem.getName(p.simpleName)}, type: ${MirrorSystem.getName(p.type.simpleName)}, isNamed: ${p.isNamed}');
      }
    }
  }
}
