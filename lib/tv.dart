import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart' as cg;
import 'package:http/http.dart' as http;

const emptyFen = '8/8/8/8/8/8/8/8 w - - 0 1';

class TV extends StatefulWidget {
  const TV({super.key});

  @override
  State<TV> createState() => _TVState();
}

class _TVState extends State<TV> {
  late final Stream<FeaturedEvent> _featured;
  cg.Color _orientation = cg.Color.white;

  Stream<FeaturedEvent> getFeaturedEvent() async* {
    final client = http.Client();
    final resp = await client.send(
        http.Request('GET', Uri.parse('https://lichess.org/api/tv/feed')));
    yield* resp.stream
        .toStringStream()
        .where((event) => event != '')
        .map((event) => jsonDecode(event))
        .map((event) {
      switch (event['t']) {
        case 'featured':
          setState(() {
            _orientation = event['d']['orientation'] == 'white'
                ? cg.Color.white
                : cg.Color.black;
          });
      }
      final fen = event['d']['fen'] ?? emptyFen;
      final String? lm = event['d']['lm'];
      return FeaturedEvent(
          fen: fen, lm: lm != null ? cg.Move.fromUci(lm) : null);
    });
  }

  @override
  void initState() {
    super.initState();
    _featured = getFeaturedEvent();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lichess TV'),
      ),
      body: Center(
        child: StreamBuilder<FeaturedEvent>(
          stream: _featured,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Could not load tv stream');
            } else if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.data == null) {
              return cg.Board(
                size: screenWidth,
                orientation: cg.Color.white,
                fen: emptyFen,
              );
            } else {
              return cg.Board(
                size: screenWidth,
                orientation: _orientation,
                fen: snapshot.data!.fen,
                lastMove: snapshot.data!.lm,
              );
            }
          },
        ),
      ),
    );
  }
}

class FeaturedEvent {
  final String fen;
  final cg.Move? lm;

  FeaturedEvent({required this.fen, this.lm});
}
