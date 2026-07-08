import 'package:karbeat/features/plugins/abstract_plugin_screen.dart';

class KarbeatzerScreen extends AbstractPluginScreen {
  const KarbeatzerScreen({super.key, required super.target});

  @override
  KarbeatzerScreenState createState() {
    return KarbeatzerScreenState();
  }
}

class KarbeatzerScreenState extends AbstractPluginScreenState<KarbeatzerScreen> {
  @override
  String get pluginName => 'Karbeatzer V2';

}