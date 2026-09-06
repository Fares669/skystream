import 'package:animewitcher/features/details/presentation/widgets/details_poster_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The body of the similar / related tabs is a fixed height, and the grid
/// inside it is laid out by a delegate that decides its own column count. If
/// the two disagree, the difference is empty page: the height was measured
/// for two rows of wide cards while the grid drew one row of narrow ones.
void main() {
  testWidgets('the reserved height matches the row the grid actually draws', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late int columns;
    late double oneRow;
    late double twoRows;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            columns = detailsExtraTabRenderedColumns(context, 1680);
            oneRow = detailsExtraTabBodyHeight(context, 1680, rows: 1);
            twoRows = detailsExtraTabBodyHeight(context, 1680, rows: 2);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // The measurement asks the same question the grid's delegate does, of
    // the width the grid is actually given, rather than assuming the three
    // columns this used to hardcode.
    expect(
      columns,
      greaterThan(detailsExtraTabGridColumns),
      reason: 'a grid this wide fits more than the old fixed three',
    );
    // And one row must be meaningfully shorter than two, or the row count
    // being passed is not doing anything.
    expect(oneRow, lessThan(twoRows * 0.6));
  });
}
