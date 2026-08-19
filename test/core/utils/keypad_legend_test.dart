import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/core/utils/keypad_legend.dart';
import 'package:order_master_kds/models/order_model.dart';

KeypadLegendEntry _entry(List<KeypadLegendEntry> rows, String keyLabel) {
  return rows.firstWhere((KeypadLegendEntry e) => e.keyLabel == keyLabel);
}

void main() {
  test(
    '+/- is Tab on the board, Scroll items in sidebar, Scroll lines in panel',
    () {
      expect(
        _entry(
          keypadLegendFor(
            const KeypadLegendContext(surface: KeypadLegendSurface.board),
          ),
          '+/-',
        ).action,
        'Tab',
      );
      expect(
        _entry(
          keypadLegendFor(
            const KeypadLegendContext(surface: KeypadLegendSurface.sidebar),
          ),
          '+/-',
        ).action,
        'Scroll items',
      );
      expect(
        _entry(
          keypadLegendFor(
            const KeypadLegendContext(
              surface: KeypadLegendSurface.breakdownPanel,
            ),
          ),
          '+/-',
        ).action,
        'Scroll lines',
      );
    },
  );

  test('+/- reads Next ticket once a ticket is ringed', () {
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.board,
            focusedStatus: OrderStatus.cooking,
          ),
        ),
        '+/-',
      ).action,
      'Next ticket',
    );
  });

  test('Enter reads Pick ticket on a calm board', () {
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(surface: KeypadLegendSurface.board),
        ),
        'Enter',
      ).action,
      'Pick ticket',
    );
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.board,
            hasDigits: true,
          ),
        ),
        'Enter',
      ).action,
      'Confirm',
    );
  });

  test('Enter reads Start / Complete / Toggle item / Complete all', () {
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.board,
            focusedStatus: OrderStatus.newOrder,
          ),
        ),
        'Enter',
      ).action,
      'Start',
    );
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.board,
            focusedStatus: OrderStatus.cooking,
          ),
        ),
        'Enter',
      ).action,
      'Complete',
    );
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.board,
            focusedStatus: OrderStatus.cooking,
            hasDigits: true,
          ),
        ),
        'Enter',
      ).action,
      'Toggle item',
    );
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.breakdownPanel,
          ),
        ),
        'Enter',
      ).action,
      'Complete all',
    );
  });

  test('Enter is a dash on completed and cancelled with no digits', () {
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.board,
            focusedStatus: OrderStatus.completed,
          ),
        ),
        'Enter',
      ).action,
      '—',
    );
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.board,
            focusedStatus: OrderStatus.cancelled,
          ),
        ),
        'Enter',
      ).action,
      '—',
    );
  });

  test('* reads Rollback only when a completed order is focused', () {
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.board,
            focusedStatus: OrderStatus.completed,
          ),
        ),
        '*',
      ).action,
      'Rollback',
    );
    expect(
      _entry(
        keypadLegendFor(
          const KeypadLegendContext(
            surface: KeypadLegendSurface.board,
            focusedStatus: OrderStatus.cooking,
          ),
        ),
        '*',
      ).action,
      '—',
    );
  });
}
