//
//  NotesImportParserTests.swift
//  LaSedTests
//
//  Versión app:  0.3.0
//  Doc:          v0.4 (+ ajustes de este chat, Fase 2b)
//  Fase:         2b — Importador de notas (Apple Notes → TXT)
//  Modificado:   09/09/2026
//
//  Contenido SINTETICO (no son letras reales de ninguna canción), pensado
//  para replicar los patrones estructurales que sí se validaron contra tus
//  217 notas reales: título sucio, acordes anclados, línea "resumen" que no
//  se ancla, notación solfeo, y notas basura/con contenido perdido.

import Testing
@testable import LaSed

struct NotesImportParserTests {

    @Test func tituloSeLimpiaDeBanderaChecksYCodigoDeBloque() {
        let texto = "B-7 🇦🇷 CANCION DE PRUEBA ✅✅\nG                    D\nEsto es una linea de prueba\n"
        let r = NotesImportParser.parse(rawText: texto, fileName: "test.txt")
        #expect(r.tituloLimpio == "CANCION DE PRUEBA")
        #expect(r.banderaPaisDetectada == "🇦🇷")
    }

    @Test func acordeSeAnclaALaLineaDeLetraSiguiente_notacionInglesa() {
        // Incluye un acorde con calidad (Bm) en algun lado del archivo, como
        // pasaria en cualquier cancion real, para que la evidencia fuerte
        // dispare la notacion inglesa (un archivo con solo mayores pelados
        // nunca la dispara, por diseño anti-falsos-positivos).
        let texto = "Titulo\nG           D\nHola mundo bonito\nBm          Em\nOtra linea de relleno\n"
        let r = NotesImportParser.parse(rawText: texto, fileName: "test.txt")
        #expect(r.contentAST.notacionDetectada == .inglesa)

        let lineas = r.contentAST.sections.flatMap { $0.lines }
        let conAcordes = lineas.first { $0.type == .letraConAcordes }
        #expect(conAcordes != nil)
        let acordesEnLinea = conAcordes?.segments.compactMap { $0.chord?.root }
        #expect(acordesEnLinea == ["G", "D"])
    }

    @Test func lineaResumenCompactaNoSeAnclaALaLetra() {
        // Patron real frecuente: "D - Bm - G - A" como progresion de cabecera,
        // NUNCA debe interpretarse como anclada a la linea de letra siguiente.
        let texto = "Titulo\nD - Bm - G - A\nEsta linea es letra normal sin relacion\n"
        let r = NotesImportParser.parse(rawText: texto, fileName: "test.txt")

        let lineas = r.contentAST.sections.flatMap { $0.lines }
        #expect(lineas.contains { $0.type == .instrumental })
        #expect(!lineas.contains { $0.type == .letraConAcordes })
        // La nota debe quedar marcada para revision: 0 lineas realmente ancladas
        #expect(r.issues.contains { $0.type == .sinAcordesAnclados })
    }

    @Test func detectaNotacionSolfeoSinConfundirPalabrasComunes() {
        // "Solm" (Sol menor) es evidencia fuerte. La linea "la mi sol si..."
        // va en su PROPIA seccion (separada por linea en blanco) para que no
        // quede pegada como letra de la linea de acordes anterior — asi se
        // aisla si esas palabras sueltas se confunden con acordes o no.
        let texto = "Titulo\nSolm          Rem\nEsta es la letra real de esa linea\n\nla mi sol si son palabras normales aqui\n"
        let r = NotesImportParser.parse(rawText: texto, fileName: "test.txt")
        #expect(r.contentAST.notacionDetectada == .solfeo)

        let lineas = r.contentAST.sections.flatMap { $0.lines }
        let letraPlana = lineas.first { $0.type == .letraPlana }
        // La linea "la mi sol si..." debe quedar como letra plana, no como acordes
        #expect(letraPlana != nil)
    }

    @Test func notaVaciaQuedaMarcadaParaRevision() {
        let texto = "🇦🇷 \n"
        let r = NotesImportParser.parse(rawText: texto, fileName: "vacia.txt")
        #expect(r.requiereRevision == true)
        #expect(r.issues.contains { $0.type == .notaVaciaOBasura })
    }

    @Test func caracterDeReemplazoQuedaMarcadoParaRevision() {
        let texto = "Titulo\nAlgo de contenido con un objeto perdido: \u{FFFC}\nOtra linea mas de relleno\n"
        let r = NotesImportParser.parse(rawText: texto, fileName: "conimagen.txt")
        #expect(r.requiereRevision == true)
        #expect(r.issues.contains { $0.type == .contenidoPerdido })
    }

    @Test func notaSinAcordesSeImportaComoLetraSolaNoComoError() {
        let texto = "Titulo\nEsta cancion no tiene ningun acorde anotado\nSolo tiene letra normal y corriente\n"
        let r = NotesImportParser.parse(rawText: texto, fileName: "soloLetra.txt")
        #expect(r.contentAST.notacionDetectada == .ninguna)
        #expect(r.requiereRevision == true) // marcada para revisar, pero no descartada
        let lineas = r.contentAST.sections.flatMap { $0.lines }
        #expect(lineas.allSatisfy { $0.type != .letraConAcordes })
    }
}
