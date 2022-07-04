import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart' as cg;
import 'package:bishop/bishop.dart' as bh;
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'widgets.dart';

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
                          name: topPlayer.name,
                          title: topPlayer.title,
                          rating: topPlayer.rating,
                          clock: Duration(seconds: topPlayer.seconds),
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
                          name: bottomPlayer.name,
                          title: bottomPlayer.title,
                          rating: bottomPlayer.rating,
                          clock: Duration(seconds: bottomPlayer.seconds),
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
    final resp = await _client
        .send(http.Request('GET', Uri.parse('$kLichessHost/api/tv/feed')));
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
