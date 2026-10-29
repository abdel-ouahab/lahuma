import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_motion.dart';

/// Rows from this index on show at once: a long list never keeps the user
/// waiting, and rows built while scrolling don't fade in one by one.
const int _kStaggeredRows = 10;
const Duration _kStagger = Duration(milliseconds: 40);

extension AppEntrance on Widget {
  /// Fades the row in and lifts it a few points, delayed by its [index] in
  /// the list. Plays once, when the row is first built.
  Widget listEntrance(int index) => _Entrance(index: index, child: this);
}

extension AppEntranceList on List<Widget> {
  /// [AppEntrance.listEntrance] on every child, in order.
  List<Widget> listEntrance() =>
      [for (var i = 0; i < length; i++) this[i].listEntrance(i)];
}

class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (index >= _kStaggeredRows || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return child
        .animate(delay: _kStagger * index)
        .fadeIn(duration: AppMotion.standard, curve: AppMotion.curve)
        .moveY(
            begin: 12,
            end: 0,
            duration: AppMotion.standard,
            curve: AppMotion.curve);
  }
}
