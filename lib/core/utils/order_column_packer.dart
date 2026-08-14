import '../constants/kds_layout.dart';
import '../../models/order_item_model.dart';
import '../../models/order_model.dart';

class BoardLayoutConstraints {
  const BoardLayoutConstraints({
    required this.boardWidth,
    required this.boardHeight,
  });

  final double boardWidth;
  final double boardHeight;

  @override
  bool operator ==(Object other) {
    return other is BoardLayoutConstraints &&
        other.boardWidth == boardWidth &&
        other.boardHeight == boardHeight;
  }

  @override
  int get hashCode => Object.hash(boardWidth, boardHeight);
}

class CardSegment {
  const CardSegment({
    required this.orderId,
    required this.segmentIndex,
    required this.itemStartIndex,
    required this.itemEndIndex,
    required this.isPrimary,
    required this.isFinal,
    required this.showIncomingContinued,
    required this.showOutgoingContinued,
    required this.estimatedHeight,
  });

  final String orderId;
  final int segmentIndex;
  final int itemStartIndex;
  final int itemEndIndex;
  final bool isPrimary;
  final bool isFinal;
  final bool showIncomingContinued;
  final bool showOutgoingContinued;
  final double estimatedHeight;

  List<OrderItem> itemsFor(Order order) {
    return order.items.sublist(itemStartIndex, itemEndIndex);
  }
}

class PackedOrderBoard {
  const PackedOrderBoard({
    required this.columns,
    required this.columnWidth,
  });

  final List<List<CardSegment>> columns;
  final double columnWidth;
}

int computeColumnCount(double boardWidth) {
  if (boardWidth <= 0) {
    return KdsLayout.minColumns;
  }

  final int fitted =
      ((boardWidth + KdsLayout.cardGap) /
              (KdsLayout.minimumColumnWidth + KdsLayout.cardGap))
          .floor();
  return fitted.clamp(KdsLayout.minColumns, KdsLayout.maxColumns);
}

double computeColumnWidth(double boardWidth, int columnCount) {
  if (columnCount <= 0) {
    return boardWidth;
  }
  final double totalGaps = KdsLayout.cardGap * (columnCount - 1);
  return (boardWidth - totalGaps) / columnCount;
}

int estimateWrappedLineCount(String text, double availableWidth) {
  if (text.isEmpty || availableWidth <= 0) {
    return 1;
  }
  final double charsPerLine = (availableWidth / KdsLayout.averageCharWidth)
      .clamp(1, 1000);
  return (text.length / charsPerLine).ceil().clamp(1, 40);
}

/// Height of one item row. Intentionally ignores [OrderItem.isCompleted].
double estimateItemHeight(OrderItem item, double columnWidth) {
  double textWidth =
      columnWidth -
      (KdsLayout.cardBodyHorizontalPadding * 2) -
      KdsLayout.qtyColumnWidth -
      KdsLayout.itemTextGap;

  if (item.isRemoved && item.isRemovedUnseen) {
    textWidth -= KdsLayout.acknowledgeButtonWidth;
  }

  final String displayName = item.isRemoved
      ? 'Removed · ${item.nameSnapshot}'
      : item.nameSnapshot;

  final int nameLines = estimateWrappedLineCount(displayName, textWidth);
  double height = nameLines * KdsLayout.nameLineHeight;

  final String? modifier = item.modifierText;
  if (modifier != null && modifier.isNotEmpty) {
    final int modifierLines = estimateWrappedLineCount(modifier, textWidth);
    height +=
        KdsLayout.secondaryTextTopPadding +
        modifierLines * KdsLayout.modifierLineHeight;
  }

  final String? note = item.note;
  if (note != null && note.isNotEmpty) {
    final int noteLines = estimateWrappedLineCount('Note: $note', textWidth);
    height +=
        KdsLayout.secondaryTextTopPadding +
        noteLines * KdsLayout.noteLineHeight;
  }

  // OrderItemList always appends a trailing gutter after each row.
  return height + KdsLayout.itemVerticalGap;
}

double estimateSegmentChrome({
  required bool isPrimary,
  required bool isFinal,
  required bool showIncomingContinued,
  required bool showOutgoingContinued,
}) {
  double height =
      KdsLayout.cardBorderWidth * 2 +
      KdsLayout.cardPulseBorderWidth * 2 +
      KdsLayout.cardBodyVerticalPadding;
  if (isPrimary) {
    height += KdsLayout.headerBandHeight + KdsLayout.orderTypeRowHeight;
  }
  if (showIncomingContinued) {
    height += KdsLayout.continuedLabelHeight;
  }
  if (showOutgoingContinued) {
    height += KdsLayout.continuedLabelHeight;
  }
  if (isFinal) {
    height += KdsLayout.footerHeight;
  }
  return height + KdsLayout.heightSafetyAllowance;
}

double estimateSegmentHeight({
  required Order order,
  required int itemStartIndex,
  required int itemEndIndex,
  required double columnWidth,
  required bool isPrimary,
  required bool isFinal,
  required bool showIncomingContinued,
  required bool showOutgoingContinued,
}) {
  double itemsHeight = 0;
  for (int i = itemStartIndex; i < itemEndIndex; i++) {
    itemsHeight += estimateItemHeight(order.items[i], columnWidth);
  }

  return itemsHeight +
      estimateSegmentChrome(
        isPrimary: isPrimary,
        isFinal: isFinal,
        showIncomingContinued: showIncomingContinued,
        showOutgoingContinued: showOutgoingContinued,
      );
}

PackedOrderBoard packOrderColumns({
  required List<Order> orders,
  required double boardWidth,
  required double boardHeight,
}) {
  final List<Order> sorted = List<Order>.of(orders)
    ..sort((Order a, Order b) => a.createdAt.compareTo(b.createdAt));

  final int viewportColumnCount = computeColumnCount(boardWidth);
  final double columnWidth = computeColumnWidth(
    boardWidth,
    viewportColumnCount,
  );
  final List<List<CardSegment>> columns = List<List<CardSegment>>.generate(
    viewportColumnCount,
    (_) => <CardSegment>[],
    growable: true,
  );
  final List<double> usedHeights = List<double>.filled(
    viewportColumnCount,
    0,
    growable: true,
  );

  int columnIndex = 0;

  for (final Order order in sorted) {
    int itemCursor = 0;
    int segmentIndex = 0;

    while (itemCursor < order.items.length) {
      _ensureColumn(columns, usedHeights, columnIndex);

      final bool isPrimary = segmentIndex == 0;
      final double remaining = boardHeight - usedHeights[columnIndex];
      final double gap = columns[columnIndex].isEmpty ? 0 : KdsLayout.cardGap;
      final int remainingEnd = order.items.length;

      final double fullFinalHeight =
          gap +
          estimateSegmentHeight(
            order: order,
            itemStartIndex: itemCursor,
            itemEndIndex: remainingEnd,
            columnWidth: columnWidth,
            isPrimary: isPrimary,
            isFinal: true,
            showIncomingContinued: !isPrimary,
            showOutgoingContinued: false,
          );

      if (fullFinalHeight <= remaining) {
        columns[columnIndex].add(
          CardSegment(
            orderId: order.id,
            segmentIndex: segmentIndex,
            itemStartIndex: itemCursor,
            itemEndIndex: remainingEnd,
            isPrimary: isPrimary,
            isFinal: true,
            showIncomingContinued: !isPrimary,
            showOutgoingContinued: false,
            estimatedHeight: fullFinalHeight - gap,
          ),
        );
        usedHeights[columnIndex] += fullFinalHeight;
        break;
      }

      int bestEnd = itemCursor;
      for (int end = itemCursor + 1; end <= remainingEnd; end++) {
        final bool wouldContinue = end < remainingEnd;
        final double candidate =
            gap +
            estimateSegmentHeight(
              order: order,
              itemStartIndex: itemCursor,
              itemEndIndex: end,
              columnWidth: columnWidth,
              isPrimary: isPrimary,
              isFinal: !wouldContinue,
              showIncomingContinued: !isPrimary,
              showOutgoingContinued: wouldContinue,
            );
        if (candidate <= remaining) {
          bestEnd = end;
        } else {
          break;
        }
      }

      if (bestEnd == itemCursor) {
        if (columns[columnIndex].isNotEmpty) {
          columnIndex++;
          continue;
        }
        // Empty lane still too short: place one item and continue right.
        bestEnd = itemCursor + 1;
      }

      final bool willContinue = bestEnd < remainingEnd;
      final double segmentHeight = estimateSegmentHeight(
        order: order,
        itemStartIndex: itemCursor,
        itemEndIndex: bestEnd,
        columnWidth: columnWidth,
        isPrimary: isPrimary,
        isFinal: !willContinue,
        showIncomingContinued: !isPrimary,
        showOutgoingContinued: willContinue,
      );
      columns[columnIndex].add(
        CardSegment(
          orderId: order.id,
          segmentIndex: segmentIndex,
          itemStartIndex: itemCursor,
          itemEndIndex: bestEnd,
          isPrimary: isPrimary,
          isFinal: !willContinue,
          showIncomingContinued: !isPrimary,
          showOutgoingContinued: willContinue,
          estimatedHeight: segmentHeight,
        ),
      );
      usedHeights[columnIndex] += gap + segmentHeight;
      itemCursor = bestEnd;
      segmentIndex++;

      if (willContinue) {
        columnIndex++;
      }
    }
  }

  return PackedOrderBoard(
    columns: columns,
    columnWidth: columnWidth,
  );
}

void _ensureColumn(
  List<List<CardSegment>> columns,
  List<double> usedHeights,
  int index,
) {
  while (columns.length <= index) {
    columns.add(<CardSegment>[]);
    usedHeights.add(0);
  }
}
