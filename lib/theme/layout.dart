import 'package:flutter/material.dart';

/// How much horizontal room the window has, and therefore which shape the UI
/// should take.
///
/// The app runs in a browser as often as on a phone, and those are genuinely
/// different products: a phone wants one column and a thumb-reachable bar along
/// the bottom, a laptop wants a side rail and content that does not stretch a
/// single list across 1600 pixels. Guessing from the platform is the wrong test
/// -- a resized browser window on a desktop should behave like a phone -- so
/// every decision here keys off the window width alone.
enum LayoutSize {
  /// Phones, and narrow browser windows. Bottom navigation, one column.
  compact,

  /// Tablets and small laptop windows. Side rail, one wide column.
  medium,

  /// Laptops and desktops. Side rail with labels, content held to a readable
  /// measure, multiple columns where the content earns them.
  expanded;

  /// Whether navigation belongs in a side rail rather than along the bottom.
  bool get usesRail => this != LayoutSize.compact;

  /// Whether there is room to show two panes side by side.
  bool get isWide => this == LayoutSize.expanded;
}

/// Window widths at which the layout changes shape.
///
/// These follow Material's own window size classes rather than device sizes,
/// which stop meaning anything the moment a window can be resized.
abstract final class Breakpoints {
  /// Below this, the window is [LayoutSize.compact].
  static const double medium = 640;

  /// At or above this, the window is [LayoutSize.expanded].
  static const double expanded = 1024;

  /// Widest a single column of text or form fields is allowed to become.
  ///
  /// Long lines are hard to track back from the end of one to the start of the
  /// next, and a settings form stretched across a monitor looks unfinished
  /// rather than spacious.
  static const double readableWidth = 720;

  /// Widest a centred content area grows before it stops filling the window.
  static const double contentWidth = 1180;

  static LayoutSize sizeFor(double width) {
    if (width >= expanded) return LayoutSize.expanded;
    if (width >= medium) return LayoutSize.medium;
    return LayoutSize.compact;
  }
}

extension LayoutSizeContext on BuildContext {
  /// The current window's size class.
  ///
  /// Reads via `MediaQuery.sizeOf`, so a widget using this rebuilds when the
  /// browser window is resized rather than keeping the shape it started with.
  LayoutSize get layoutSize =>
      Breakpoints.sizeFor(MediaQuery.sizeOf(this).width);

  bool get isCompact => layoutSize == LayoutSize.compact;
}

/// Centres [child] and stops it growing past [maxWidth].
///
/// On a phone this is a no-op, which is the point: one widget expresses "fill
/// the screen on mobile, stay readable on a laptop" so screens do not each
/// reinvent it.
class ContentShell extends StatelessWidget {
  final Widget child;

  /// Defaults to [Breakpoints.contentWidth]. Pass
  /// [Breakpoints.readableWidth] for forms and prose.
  final double maxWidth;

  /// Padding applied inside the constrained area.
  final EdgeInsetsGeometry padding;

  /// Whether to take only as much height as [child] needs.
  ///
  /// False by default because the usual child is a list that should fill the
  /// page. It must be **true** anywhere the height is loose rather than bounded
  /// -- a `bottomNavigationBar`, a sheet, an intrinsic-height row. The
  /// alignment this is built on expands to its constraints given the chance,
  /// and in a bottom bar that means claiming the entire window and collapsing
  /// the actual page above it to nothing.
  final bool shrinkWrapHeight;

  const ContentShell({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentWidth,
    this.padding = EdgeInsets.zero,
    this.shrinkWrapHeight = false,
  });

  const ContentShell.readable({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.shrinkWrapHeight = false,
  }) : maxWidth = Breakpoints.readableWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: shrinkWrapHeight ? 1.0 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
