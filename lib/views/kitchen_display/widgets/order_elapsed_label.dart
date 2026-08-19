import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/order_elapsed.dart';

class OrderElapsedLabel extends StatefulWidget {
  const OrderElapsedLabel({
    super.key,
    required this.orderId,
    required this.createdAt,
    this.frozenAt,
    this.nowBuilder = DateTime.now,
    this.style,
  });

  final String orderId;
  final DateTime createdAt;
  final DateTime? frozenAt;
  final DateTime Function() nowBuilder;
  final TextStyle? style;

  @override
  State<OrderElapsedLabel> createState() => _OrderElapsedLabelState();
}

class _OrderElapsedLabelState extends State<OrderElapsedLabel> {
  Timer? _timer;
  late String _label;

  bool get _frozen => widget.frozenAt != null;

  DateTime _now() => widget.nowBuilder();

  @override
  void initState() {
    super.initState();
    _label = _computeLabel();
    if (!_frozen) {
      _scheduleTimer();
    }
  }

  @override
  void didUpdateWidget(OrderElapsedLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String next = _computeLabel();
    if (next != _label) {
      setState(() => _label = next);
    }
    if (oldWidget.frozenAt != widget.frozenAt ||
        oldWidget.createdAt != widget.createdAt) {
      _timer?.cancel();
      _timer = null;
      if (!_frozen) {
        _scheduleTimer();
      }
    }
  }

  String _computeLabel() {
    final DateTime end = _frozen ? widget.frozenAt! : _now();
    return formatElapsed(elapsedSince(widget.createdAt, end));
  }

  void _scheduleTimer() {
    _timer?.cancel();
    final DateTime now = _now();
    final int msUntilNextMinute =
        60000 - (now.second * 1000 + now.millisecond);
    _timer = Timer(Duration(milliseconds: msUntilNextMinute), () {
      _tick();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    });
  }

  void _tick() {
    if (!mounted || _frozen) {
      return;
    }
    final String next = _computeLabel();
    if (next != _label) {
      setState(() => _label = next);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label,
      key: Key('order-elapsed-${widget.orderId}'),
      style: widget.style,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
    );
  }
}
