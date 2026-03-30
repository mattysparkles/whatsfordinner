import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env_config.dart';

final appConfigProvider = Provider<EnvConfig>((_) => EnvConfig.fromDartDefines());
