enum ChordLineType { directive, lyrics, chordOnly, cue, tablature, empty }

class ChordProDocument {
  const ChordProDocument({required this.lines, required this.chords});

  final List<ChordProLine> lines;
  final List<String> chords;

  factory ChordProDocument.parse(String source) {
    final lines = <ChordProLine>[];
    final chords = <String>{};
    for (final rawLine in source.replaceAll('\r\n', '\n').split('\n')) {
      final line = ChordProLine.parse(rawLine);
      lines.add(line);
      for (final placement in line.chordPlacements) {
        chords.add(placement.chord);
      }
      if (line.cueChord != null) {
        chords.add(line.cueChord!);
      }
    }
    return ChordProDocument(lines: lines, chords: chords.toList()..sort());
  }

  ChordProDocument transpose(int semitones) {
    return ChordProDocument(
      lines: [
        for (final line in lines)
          line.copyWith(
            cueChord: line.cueChord == null
                ? null
                : ChordTransposer.transpose(line.cueChord!, semitones),
            chordPlacements: [
              for (final placement in line.chordPlacements)
                placement.copyWith(
                  chord: ChordTransposer.transpose(placement.chord, semitones),
                ),
            ],
          ),
      ],
      chords:
          chords
              .map((chord) => ChordTransposer.transpose(chord, semitones))
              .toSet()
              .toList()
            ..sort(),
    );
  }
}

class ChordProLine {
  const ChordProLine({
    required this.raw,
    required this.type,
    required this.lyrics,
    required this.chordPlacements,
    this.directive,
    this.cueChord,
    this.cueLabel,
    this.cueIndent = 0,
  });

  final String raw;
  final ChordLineType type;
  final String lyrics;
  final String? directive;
  final String? cueChord;
  final String? cueLabel;
  final int cueIndent;
  final List<ChordPlacement> chordPlacements;

  factory ChordProLine.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return ChordProLine(
        raw: raw,
        type: ChordLineType.empty,
        lyrics: '',
        chordPlacements: const [],
      );
    }

    final cueMatch = RegExp(
      r'^\s*(?:([A-G](?:#|b)?\S*)\s+)?(\([^)]*Frase[^)]*\))\s*$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (cueMatch != null) {
      return ChordProLine(
        raw: raw,
        type: ChordLineType.cue,
        lyrics: '',
        chordPlacements: const [],
        cueChord: cueMatch.group(1)?.trim(),
        cueLabel: cueMatch.group(2)!.trim(),
        cueIndent: raw.length - raw.trimLeft().length,
      );
    }

    final directiveMatch = RegExp(
      r'^\{([^:}]+):?\s*([^}]*)\}$',
    ).firstMatch(trimmed);
    if (directiveMatch != null) {
      final key = directiveMatch.group(1)!.trim();
      final value = directiveMatch.group(2)!.trim();
      return ChordProLine(
        raw: raw,
        type: ChordLineType.directive,
        directive: value.isEmpty ? key : value,
        lyrics: '',
        chordPlacements: const [],
      );
    }

    final lyrics = StringBuffer();
    final placements = <ChordPlacement>[];
    final regex = RegExp(r'\[([^\]]+)\]');
    var cursor = 0;
    for (final match in regex.allMatches(raw)) {
      lyrics.write(raw.substring(cursor, match.start));
      final chord = match.group(1)!.trim();
      if (chord.isNotEmpty && _isChordToken(chord)) {
        placements.add(ChordPlacement(chord: chord, position: lyrics.length));
      } else {
        lyrics.write(chord);
      }
      cursor = match.end;
    }
    lyrics.write(raw.substring(cursor));
    final cleanLyrics = lyrics.toString();

    if (placements.isEmpty) {
      return ChordProLine(
        raw: raw,
        type: _isTablature(raw)
            ? ChordLineType.tablature
            : ChordLineType.lyrics,
        lyrics: cleanLyrics,
        chordPlacements: const [],
      );
    }

    return ChordProLine(
      raw: raw,
      type: cleanLyrics.trim().isEmpty
          ? ChordLineType.chordOnly
          : ChordLineType.lyrics,
      lyrics: cleanLyrics,
      chordPlacements: placements,
    );
  }

  static bool _isTablature(String raw) {
    return RegExp(r'^\s*[eEADGB]\|').hasMatch(raw);
  }

  static bool _isChordToken(String value) {
    return RegExp(r'^[A-G](?:#|b)?[A-Za-z0-9º°+\-()/#b]*$').hasMatch(value);
  }

  String get chordLine {
    if (chordPlacements.isEmpty) return '';
    final chars = List<String>.filled(
      _minimumChordLineLength(),
      ' ',
      growable: true,
    );

    for (final placement in chordPlacements) {
      var start = placement.position.clamp(0, chars.length);
      while (_hasCollision(chars, start, placement.chord)) {
        start++;
      }
      while (chars.length < start + placement.chord.length) {
        chars.add(' ');
      }
      for (var i = 0; i < placement.chord.length; i++) {
        chars[start + i] = placement.chord[i];
      }
    }

    return chars.join().trimRight();
  }

  int _minimumChordLineLength() {
    var length = lyrics.length;
    for (final placement in chordPlacements) {
      final end = placement.position + placement.chord.length;
      if (end > length) length = end;
    }
    return length;
  }

  bool _hasCollision(List<String> chars, int start, String chord) {
    if (start > 0 && start < chars.length && chars[start - 1] != ' ') {
      return true;
    }
    for (var i = 0; i < chord.length; i++) {
      final index = start + i;
      if (index >= chars.length) return false;
      if (chars[index] != ' ') return true;
    }
    return false;
  }

  ChordProLine copyWith({
    String? cueChord,
    List<ChordPlacement>? chordPlacements,
  }) {
    return ChordProLine(
      raw: raw,
      type: type,
      directive: directive,
      cueChord: cueChord ?? this.cueChord,
      cueLabel: cueLabel,
      cueIndent: cueIndent,
      lyrics: lyrics,
      chordPlacements: chordPlacements ?? this.chordPlacements,
    );
  }
}

class ChordPlacement {
  const ChordPlacement({required this.chord, required this.position});

  final String chord;
  final int position;

  ChordPlacement copyWith({String? chord, int? position}) => ChordPlacement(
    chord: chord ?? this.chord,
    position: position ?? this.position,
  );
}

class ChordTransposer {
  static const _sharpNotes = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  static const _flatToSharp = {
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
    'Bb': 'A#',
  };

  static String transpose(String chord, int semitones) {
    if (semitones == 0) return chord;
    return chord.replaceAllMapped(RegExp(r'(^|/)([A-G](?:#|b)?)'), (match) {
      final prefix = match.group(1)!;
      final note = _flatToSharp[match.group(2)!] ?? match.group(2)!;
      final index = _sharpNotes.indexOf(note);
      if (index < 0) return match.group(0)!;
      final next = (index + semitones) % _sharpNotes.length;
      return '$prefix${_sharpNotes[next < 0 ? next + _sharpNotes.length : next]}';
    });
  }
}
