import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart' as cg;
import 'package:bishop/bishop.dart' as bh;
import 'package:http/http.dart' as http;
import 'constants.dart';

const emptyFen = '8/8/8/8/8/8/8/8 w - - 0 1';

class TV extends StatefulWidget {
  const TV({super.key});

  @override
  State<TV> createState() => _TVState();
}

class _TVState extends State<TV> {
  final http.Client _client = http.Client();
  late final Stream<FeaturedEvent> _tvStream;
  cg.Color _orientation = cg.Color.white;
  bh.Game? _game;
  cg.Color? _turn;
  FeaturedPlayer? _whitePlayer;
  FeaturedPlayer? _blackPlayer;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool ongoingGame = _game != null &&
        !_game!.insufficientMaterial &&
        !_game!.stalemate &&
        !_game!.checkmate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lichess TV'),
      ),
      body: Center(
        child: StreamBuilder<FeaturedEvent>(
          stream: _tvStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Could not load tv stream');
            } else if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.data == null) {
              return cg.Board(
                theme: cg.BoardTheme.green,
                size: screenWidth,
                orientation: cg.Color.white,
                fen: emptyFen,
              );
            } else {
              final topPlayer =
                  _orientation == cg.Color.white ? _blackPlayer : _whitePlayer;
              final bottomPlayer =
                  _orientation == cg.Color.white ? _whitePlayer : _blackPlayer;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  topPlayer != null
                      ? Player(
                          player: topPlayer,
                          active: ongoingGame && _turn == topPlayer.color)
                      : const SizedBox.shrink(),
                  cg.Board(
                    theme: cg.BoardTheme.green,
                    size: screenWidth,
                    orientation: _orientation,
                    fen: snapshot.data!.fen,
                    lastMove: snapshot.data!.lm,
                  ),
                  bottomPlayer != null
                      ? Player(
                          player: bottomPlayer,
                          active: ongoingGame && _turn == bottomPlayer.color)
                      : const SizedBox.shrink(),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Stream<FeaturedEvent> startStreaming() async* {
    final resp = await _client.send(
        http.Request('GET', Uri.parse('$kLichessHost/api/tv/feed')));
    yield* resp.stream
        .toStringStream()
        .where((event) => event.isNotEmpty && event != '\n')
        .map((event) => jsonDecode(event))
        .map((event) {
      switch (event['t']) {
        case 'featured':
          setState(() {
            _orientation = event['d']['orientation'] == 'white'
                ? cg.Color.white
                : cg.Color.black;

            _whitePlayer = FeaturedPlayer.fromJson(
                event['d']['players'].firstWhere((p) => p['color'] == 'white'));
            _blackPlayer = FeaturedPlayer.fromJson(
                event['d']['players'].firstWhere((p) => p['color'] == 'black'));
          });
          break;
        case 'fen':
          setState(() {
            _whitePlayer = _whitePlayer?.withSeconds(event['d']['wc']);
            _blackPlayer = _blackPlayer?.withSeconds(event['d']['bc']);
          });
          break;
      }
      final String fen = event['d']['fen'] ?? emptyFen;
      _game = bh.Game(variant: bh.Variant.standard(), fen: fen);
      setState(() {
        final letter = fen.substring(fen.length - 1);
        _turn = letter == 'w' ? cg.Color.white : cg.Color.black;
      });
      final String? lm = event['d']['lm'];
      return FeaturedEvent(
          fen: fen, lm: lm != null ? cg.Move.fromUci(lm) : null);
    });
  }

  @override
  void initState() {
    super.initState();
    _tvStream = startStreaming();
  }

  @override
  void dispose() {
    super.dispose();
    _client.close();
  }
}

class CountdownClock extends StatefulWidget {
  final int seconds;
  final bool active;

  const CountdownClock({required this.seconds, required this.active, Key? key})
      : super(key: key);

  @override
  State<CountdownClock> createState() => _CountdownClockState();
}

class _CountdownClockState extends State<CountdownClock> {
  static const _period = Duration(milliseconds: 100);
  Timer? _timer;
  late Duration timeLeft;

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
    timeLeft = Duration(seconds: widget.seconds);
    if (widget.active) {
      _timer = startTimer();
    }
  }

  @override
  void didUpdateWidget(CountdownClock oldClock) {
    super.didUpdateWidget(oldClock);
    _timer?.cancel();
    timeLeft = Duration(seconds: widget.seconds);
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
    return Text('$min:$secs',
        style: TextStyle(
          color: widget.active ? Colors.orange : Colors.grey,
          fontSize: 30,
          fontFeatures: const [
            FontFeature.tabularFigures(),
            FontFeature.slashedZero()
          ],
        ));
  }
}

class Player extends StatelessWidget {
  final FeaturedPlayer player;
  final bool active;

  const Player({required this.player, required this.active, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget name = Text(player.name,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600));
    final Widget rating =
        Text(player.rating.toString(), style: const TextStyle(fontSize: 13));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: player.title != null
              ? [
                  Text(player.title!,
                      style:
                          const TextStyle(fontSize: 20, color: Colors.orange)),
                  const SizedBox(width: 5),
                  name,
                  const SizedBox(width: 3),
                  rating,
                ]
              : [
                  name,
                  const SizedBox(width: 3),
                  rating,
                ],
        ),
        CountdownClock(
          seconds: player.seconds,
          active: active,
        ),
      ],
    );
  }
}

class FeaturedEvent {
  final String fen;
  final cg.Move? lm;

  FeaturedEvent({required this.fen, this.lm});
}

class FeaturedPlayer {
  final cg.Color color;
  final String name;
  final String? title;
  final int rating;
  final int seconds;

  FeaturedPlayer(
      {required this.color,
      required this.name,
      this.title,
      required this.rating,
      required this.seconds});

  FeaturedPlayer.fromJson(Map<String, dynamic> json)
      : color = json['color'] == 'white' ? cg.Color.white : cg.Color.black,
        name = json['user']['name'],
        title = json['user']['title'],
        rating = json['rating'],
        seconds = json['seconds'];

  FeaturedPlayer withSeconds(int newSeconds) {
    return FeaturedPlayer(
      color: color,
      name: name,
      title: title,
      rating: rating,
      seconds: newSeconds,
    );
  }
}
