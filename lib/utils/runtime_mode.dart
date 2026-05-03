import 'package:statusxp/utils/runtime_mode_stub.dart'
    if (dart.library.io) 'package:statusxp/utils/runtime_mode_io.dart';

bool get isFlutterTestMode => isFlutterTestEnvironment;
