import 'package:flutter/material.dart';

/// Yunido: detects a drag past the top / bottom edge of the scrollable inside
/// [child] and reports it as a switch to the previous (-1) / next (+1)
/// sub-category.
///
/// Works with both Android (clamping, OverscrollNotification) and iOS
/// (bouncing, pixels beyond the extent) scroll physics, and also for lists
/// that are shorter than the screen (the scroll view must use
/// AlwaysScrollableScrollPhysics for those).
class EdgeSwitchListener extends StatefulWidget {
  final Widget child;
  final ValueChanged<int> onSwitch;

  /// Bottom pull is ignored while more pages are still loading, so a normal
  /// scroll to the end of a long list doesn't jump away early.
  final bool canSwitchNext;
  final bool canSwitchPrevious;

  const EdgeSwitchListener({
    super.key,
    required this.child,
    required this.onSwitch,
    this.canSwitchNext = true,
    this.canSwitchPrevious = true,
  });

  @override
  State<EdgeSwitchListener> createState() => _EdgeSwitchListenerState();
}

class _EdgeSwitchListenerState extends State<EdgeSwitchListener> {
  static const double _threshold = 56;
  double _pull = 0; // + = past the bottom, - = past the top
  bool _fired = false;

  void _check() {
    if (_fired) return;
    if (_pull >= _threshold && widget.canSwitchNext) {
      _fired = true;
      widget.onSwitch(1);
    } else if (_pull <= -_threshold && widget.canSwitchPrevious) {
      _fired = true;
      widget.onSwitch(-1);
    }
  }

  bool _onNotification(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      _pull = 0;
      _fired = false;
    } else if (n is OverscrollNotification) {
      if (n.dragDetails == null) return false; // ignore fling overscroll
      _pull += n.overscroll;
      _check();
    } else if (n is ScrollUpdateNotification) {
      if (n.dragDetails == null) return false;
      final m = n.metrics;
      if (m.pixels > m.maxScrollExtent) {
        _pull = m.pixels - m.maxScrollExtent;
        _check();
      } else if (m.pixels < m.minScrollExtent) {
        _pull = m.pixels - m.minScrollExtent;
        _check();
      }
    } else if (n is ScrollEndNotification) {
      _pull = 0;
      _fired = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: widget.child,
    );
  }
}
