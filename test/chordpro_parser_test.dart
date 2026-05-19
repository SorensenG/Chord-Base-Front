import 'package:chordbase/features/chords/chordpro_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses inline ChordPro chords and directives', () {
    final doc = ChordProDocument.parse(
      '{section: Intro}\n[E]Quando eu digo que deixei de te [B/D#]amar',
    );

    expect(doc.lines.first.directive, 'Intro');
    expect(doc.chords, containsAll(['E', 'B/D#']));
  });

  test('does not treat square-bracket section labels as chords', () {
    final line = ChordProLine.parse('[Intro] Riff');
    final doc = ChordProDocument.parse('[Intro] Riff\n[F#m]Letra');

    expect(line.lyrics, 'Intro Riff');
    expect(line.chordPlacements, isEmpty);
    expect(doc.chords, contains('F#m'));
    expect(doc.chords, isNot(contains('Intro')));
  });

  test('renders inline chord at insertion point above clean lyric', () {
    final line = ChordProLine.parse('In the r[F#m]ound');

    expect(line.lyrics, 'In the round');
    expect(line.chordPlacements.single.chord, 'F#m');
    expect(line.chordPlacements.single.position, 8);
    expect(line.chordLine, '        F#m');
  });

  test('handles chord at the start of a lyric line', () {
    final line = ChordProLine.parse('[F#m]She was more');

    expect(line.lyrics, 'She was more');
    expect(line.chordPlacements.single.position, 0);
    expect(line.chordLine, 'F#m');
  });

  test('handles multiple chords in one line', () {
    final line = ChordProLine.parse(
      '[F#m]She was more like a beauty [Bm]queen',
    );

    expect(line.lyrics, 'She was more like a beauty queen');
    expect(line.chordPlacements.map((item) => item.chord), ['F#m', 'Bm']);
    expect(line.chordPlacements.map((item) => item.position), [0, 27]);
    expect(line.chordLine, 'F#m                        Bm');
  });

  test('handles chord inside a word', () {
    final line = ChordProLine.parse('s[F#m]on');

    expect(line.lyrics, 'son');
    expect(line.chordPlacements.single.position, 1);
    expect(line.chordLine, ' F#m');
  });

  test('handles chord-only line', () {
    final line = ChordProLine.parse('[F#m]');

    expect(line.lyrics, '');
    expect(line.type, ChordLineType.chordOnly);
    expect(line.chordLine, 'F#m');
  });

  test('detects cue lines with chord and label', () {
    final line = ChordProLine.parse('F#m (Frase 1)');

    expect(line.type, ChordLineType.cue);
    expect(line.cueChord, 'F#m');
    expect(line.cueLabel, '(Frase 1)');
    expect(line.cueIndent, 0);
  });

  test('preserves cue indentation from source', () {
    final line = ChordProLine.parse('        Bm (Frase 2)');

    expect(line.type, ChordLineType.cue);
    expect(line.cueChord, 'Bm');
    expect(line.cueLabel, '(Frase 2)');
    expect(line.cueIndent, 8);
  });

  test('detects cue lines without chord', () {
    final line = ChordProLine.parse('(Frase 4)');

    expect(line.type, ChordLineType.cue);
    expect(line.cueChord, isNull);
    expect(line.cueLabel, '(Frase 4)');
  });

  test('detects tablature lines without treating them as chords', () {
    final line = ChordProLine.parse('E|---2---4---|');

    expect(line.lyrics, 'E|---2---4---|');
    expect(line.type, ChordLineType.tablature);
    expect(line.chordPlacements, isEmpty);
  });

  test('transposes slash chords', () {
    expect(ChordTransposer.transpose('B/D#', 1), 'C/E');
    expect(ChordTransposer.transpose('Gº', 2), 'Aº');
  });

  test('transposes cue chords and includes them in chord list', () {
    final doc = ChordProDocument.parse('F#m (Frase 1)').transpose(1);

    expect(doc.lines.single.cueChord, 'Gm');
    expect(doc.chords, contains('Gm'));
    expect(doc.chords, isNot(contains('F#m')));
  });
}
