import 'package:karbeat/shared/models/menu_group.dart';

abstract class ToolbarConstants {
  static final List<DawToolbarMenuGroup> menuGroups = [
    DawToolbarMenuGroupFactory.createProjectMenuGroup(),
    DawToolbarMenuGroupFactory.createEditMenuGroup(),
    DawToolbarMenuGroupFactory.createViewMenuGroup(),
  ];
}