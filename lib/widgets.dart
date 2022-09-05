import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

class Player extends StatelessWidget {
  final String name;
  final int rating;
  final String? title;
  final Duration clock;
  final bool active;

  const Player(
      {required this.name,
      this.title,
      required this.rating,
      required this.active,
      required this.clock,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget _name =
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600));
    final Widget _rating = Text(rating.toString(), style: const TextStyle(fontSize: 13));
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: title != null
                ? [
                    Text(title!, style: const TextStyle(fontSize: 20, color: Colors.orange)),
                    const SizedBox(width: 5),
                    _name,
                    const SizedBox(width: 3),
                    _rating,
                  ]
                : [
                    _name,
                    const SizedBox(width: 3),
                    _rating,
                  ],
          ),
          CountdownClock(
            duration: clock,
            active: active,
          ),
        ],
      ),
    );
  }
}

class CountdownClock extends StatefulWidget {
  final Duration duration;
  final bool active;

  const CountdownClock({required this.duration, required this.active, Key? key}) : super(key: key);

  @override
  State<CountdownClock> createState() => _CountdownClockState();
}

class _CountdownClockState extends State<CountdownClock> {
  static const _period = Duration(milliseconds: 100);
  Timer? _timer;
  Duration timeLeft = Duration.zero;

  Timer startTimer() {
    return Timer.periodic(_period, (timer) {
      setState(() {
        timeLeft = timeLeft - _period;
        if (timeLeft <= Duration.zero) {
          timer.cancel();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    timeLeft = widget.duration;
    if (widget.active) {
      _timer = startTimer();
    }
  }

  @override
  void didUpdateWidget(CountdownClock oldClock) {
    super.didUpdateWidget(oldClock);
    _timer?.cancel();
    timeLeft = widget.duration;
    if (widget.active) {
      _timer = startTimer();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final min = timeLeft.inMinutes.remainder(60);
    final secs = timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0),
        color: widget.active ? Colors.white : Colors.black,
      ),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 5.0),
          child: Text('$min:$secs',
              style: TextStyle(
                color: widget.active ? Colors.black : Colors.grey,
                fontSize: 30,
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                ],
              ))),
    );
  }
}
