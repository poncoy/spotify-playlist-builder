//
//  EditableSongContent.swift
//  LaSed
//
//  Versión: 0.4.0
//  Actualizado: 10/09/2026
//
import Foundation

struct EditableChord: Identifiable, Equatable {
    let id: UUID
    var root: String
    var accidental: String?
    var quality: CalidadAcorde
    var extensionNumero: String?
    var bassRoot: String?
    var raw: String
    var notacionOrigen: NotacionAcorde

    init(id: UUID = UUID(), from chord: Chord) {
        self.id = id
        self.root = chord.root
        self.accidental = chord.accidental
        self.quality = chord.quality
        self.extensionNumero = chord.extensionNumero
        self.bassRoot = chord.bassRoot
        self.raw = chord.raw
        self.notacionOrigen = chord.notacionOrigen
    }

    func toChord() -> Chord {
        Chord(
            root: root,
            accidental: accidental,
            quality: quality,
            extensionNumero: extensionNumero,
            bassRoot: bassRoot,
            raw: raw,
            notacionOrigen: notacionOrigen
        )
    }
}

struct EditableSegment: Identifiable, Equatable {
    let id: UUID
    var chord: EditableChord?
    var text: String

    init(id: UUID = UUID(), from segment: LineSegment) {
        self.id = id
        self.chord = segment.chord.map { EditableChord(from: $0) }
        self.text = segment.text
    }

    func toLineSegment() -> LineSegment {
        LineSegment(chord: chord?.toChord(), text: text)
    }
}

struct EditableLine: Identifiable, Equatable {
    let id: UUID
    var type: TipoLinea
    var segments: [EditableSegment]

    init(id: UUID = UUID(), from line: ParsedLine) {
        self.id = id
        self.type = line.type
        self.segments = line.segments.map { EditableSegment(from: $0) }
    }

    func toParsedLine() -> ParsedLine {
        ParsedLine(type: type, segments: segments.map { $0.toLineSegment() })
    }
}

struct EditableSection: Identifiable, Equatable {
    let id: UUID
    var lines: [EditableLine]

    init(id: UUID = UUID(), from section: ParsedSection) {
        self.id = id
        self.lines = section.lines.map { EditableLine(from: $0) }
    }

    func toParsedSection() -> ParsedSection {
        ParsedSection(lines: lines.map { $0.toParsedLine() })
    }
}

struct EditableSongContent: Identifiable, Equatable {
    let id: UUID
    var sections: [EditableSection]
    var notacionDetectada: NotacionAcorde

    init(id: UUID = UUID(), from content: ParsedSongContent) {
        self.id = id
        self.sections = content.sections.map { EditableSection(from: $0) }
        self.notacionDetectada = content.notacionDetectada
    }

    func toParsedSongContent() -> ParsedSongContent {
        ParsedSongContent(
            sections: sections.map { $0.toParsedSection() },
            notacionDetectada: notacionDetectada
        )
    }
}
