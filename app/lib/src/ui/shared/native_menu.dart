import 'dart:async';

import 'package:tray_manager/tray_manager.dart' as native;

/// The open menu with all its items and submenus. nativeapi pops the menu
/// up asynchronously (next main run loop turn) and frees native handles
/// when their Dart wrappers are collected, so everything must stay
/// reachable until the next menu replaces it — otherwise a GC between
/// `open` and the popup kills the menu and its click listeners.
List<Object> _openMenu = const [];
var _building = <Object>[];

/// Opens a native menu at the cursor with the sections [build] returns,
/// separated, skipping empty ones. Build items with [menuItem],
/// [menuCheck] and [menuSubmenu] inside [build] so they stay alive.
void showNativeMenu(List<List<native.MenuItem>> Function() build) {
  _building = [];
  final sections = build().where((items) => items.isNotEmpty);
  final menu = native.Menu.create()!;
  for (final (i, items) in sections.indexed) {
    if (i > 0) menu.addSeparator();
    items.forEach(menu.addItem);
  }
  if (_openMenu.firstOrNull case final native.Menu previous) previous.close();
  _openMenu = [menu, ..._building];
  menu.open(
    native.PositioningStrategy.cursorPosition()!,
    native.Placement.bottomStart,
  );
}

/// A plain item; disabled when [onClick] is null.
native.MenuItem menuItem(String label, FutureOr<void> Function()? onClick) {
  final item = native.MenuItem.createWithLabelAndType(
    label,
    native.MenuItemType.normal,
  )!;
  if (onClick != null) {
    item.addListener((event) {
      if (event is native.MenuItemClickedEvent) return onClick();
    });
  } else {
    item.isEnabled = false;
  }
  _building.add(item);
  return item;
}

/// A checkbox / radio-style item.
native.MenuItem menuCheck(String label, bool checked, void Function() onClick) {
  final item =
      native.MenuItem.createWithLabelAndType(
          label,
          native.MenuItemType.checkbox,
        )!
        ..state = checked
            ? native.MenuItemState.checked
            : native.MenuItemState.unchecked
        ..addListener((event) {
          if (event is native.MenuItemClickedEvent) onClick();
        });
  _building.add(item);
  return item;
}

/// An item opening [items] as a submenu.
native.MenuItem menuSubmenu(String label, List<native.MenuItem> items) {
  final submenu = native.Menu.create()!;
  items.forEach(submenu.addItem);
  final item = native.MenuItem.createWithLabelAndType(
    label,
    native.MenuItemType.submenu,
  )!..submenu = submenu;
  _building.addAll([submenu, item]);
  return item;
}
