import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/services/timeline_pointer.dart';

/// A row that keeps itself alive while [dragging], the way timeline rows
/// keep a running drag alive.
class _Row extends StatefulWidget {
  const _Row({required this.index, required this.dragging});

  final int index;
  final ValueNotifier<bool> dragging;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> with AutomaticKeepAliveClientMixin<_Row> {
  static final Set<int> alive = {};

  @override
  bool get wantKeepAlive => widget.dragging.value;

  @override
  void initState() {
    super.initState();
    alive.add(widget.index);
    widget.dragging.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.dragging.removeListener(_rebuild);
    alive.remove(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    updateKeepAlive();
    return const SizedBox(height: 100);
  }
}

void main() {
  testWidgets('timelineXOf adds the horizontal scroll offset', (tester) async {
    final controller = ScrollController();
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: controller,
              child: SizedBox(key: key, width: 2000, height: 50),
            ),
          ),
        ),
      ),
    );
    final context = key.currentContext!;
    expect(timelineXOf(context, const Offset(50, 10)), 50);

    controller.jumpTo(300);
    // Same screen position, no relayout yet: the scroll offset alone moves it.
    expect(timelineXOf(context, const Offset(50, 10)), 350);
  });

  testWidgets('a row that is dragging survives scrolling out of view', (
    tester,
  ) async {
    final controller = ScrollController();
    final dragging = ValueNotifier(false);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 300,
          child: CustomScrollView(
            controller: controller,
            scrollCacheExtent: const ScrollCacheExtent.viewport(0),
            slivers: [
              SliverList.builder(
                itemCount: 50,
                itemBuilder: (context, index) => _Row(
                  index: index,
                  dragging: index == 0 ? dragging : ValueNotifier(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(_RowState.alive, contains(0));

    dragging.value = true;
    await tester.pump();
    controller.jumpTo(2000);
    await tester.pump();
    expect(_RowState.alive, contains(0), reason: 'kept alive mid-drag');

    dragging.value = false;
    await tester.pump();
    await tester.pump();
    expect(_RowState.alive, isNot(contains(0)), reason: 'released after drag');
  });
}
