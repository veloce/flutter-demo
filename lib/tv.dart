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
  final Stream<Map<String, dynamic>> _featured = (() {
    Stream<Map<String, dynamic>> getFeaturedEvent() async* {
      final client = http.Client();
      final resp = await client.send(
          http.Request('GET', Uri.parse('https://lichess.org/api/tv/feed')));
      yield* resp.stream
          .toStringStream()
          .where((event) => event != '')
          .map((event) => jsonDecode(event));
    }

    return getFeaturedEvent();
  })();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lichess TV'),
      ),
      body: Center(
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _featured,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Could not load tv stream');
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              return cg.Board(
                size: screenWidth,
                orientation: cg.Color.white,
                fen: emptyFen,
              );
            } else {
              final fen = snapshot.data?['d']['fen'] ?? emptyFen;
              final String? lm = snapshot.data?['d']['lm'];
              return cg.Board(
                size: screenWidth,
                orientation: cg.Color.white,
                fen: fen,
                lastMove: lm != null ? cg.Move.fromUci(lm) : null,
              );
            }
          },
        ),
      ),
    );
  }
}
