import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-21 (Haylee, decisions/2026-11-21-one-scene-music-beats.md): four more music families (snowy north, robot lab,
/// circus & carnival, race day) with their keyword routing, and the calm → calm2 → calm… loop order.
struct MusicFamiliesCalmLoopTests {
    @Test func theFourNewFamilies() {
        #expect(MusicFamily.allCases.count == 14)
        #expect(MusicFamily.snowyNorth.rawValue == "snowy-north" && MusicFamily.snowyNorth.label == "Snowy north")
        #expect(MusicFamily.robotLab.rawValue == "robot-lab" && MusicFamily.robotLab.label == "Robot lab")
        #expect(MusicFamily.circusCarnival.rawValue == "circus-carnival" && MusicFamily.circusCarnival.label == "Circus & carnival")
        #expect(MusicFamily.raceDay.rawValue == "race-day" && MusicFamily.raceDay.label == "Race day")
        #expect(MusicFamily.parse("Circus & carnival") == .circusCarnival && MusicFamily.parse("robot_lab") == .robotLab
                && MusicFamily.parse("Snowy North") == .snowyNorth && MusicFamily.parse("race-day") == .raceDay)
        // The guide's list and the schema's enum come from allCases.
        for f in [MusicFamily.snowyNorth, .robotLab, .circusCarnival, .raceDay] {
            #expect(OneScene.rules.contains(f.rawValue), "\(f)")
            #expect(MusicMix.file(f, .calm) == "Music/\(f.rawValue)/calm.m4a" && MusicMix.calm2(f) == "Music/\(f.rawValue)/calm2.m4a")
        }
        #expect(!MusicFamily.spaceAdventure.fits.contains("robot"))
    }

    @Test func keywordRouting() {
        // Snowy north
        #expect(MusicFamily.guess("Penguin Igloo Party") == .snowyNorth && MusicFamily.guess("North Pole Workshop") == .snowyNorth)
        #expect(MusicFamily.guess("Arctic Explorers") == .snowyNorth && MusicFamily.guess("Winter Snow Day") == .snowyNorth)
        #expect(MusicFamily.guess("Ice Palace") == .snowyNorth)
        #expect(MusicFamily.guess("Ice Cream Shop") == .cozyShop)   // "ice cream" is a shop
        // Robot lab: before space, and "robot" is no longer space's
        #expect(MusicFamily.guess("Robot Repair Shop") == .robotLab && MusicFamily.guess("Space Station with Robots") == .robotLab)
        #expect(MusicFamily.guess("Mad Scientist Laboratory") == .robotLab && MusicFamily.guess("Time Machine Trip") == .robotLab)
        #expect(MusicFamily.guess("Science Fair") == .robotLab)
        #expect(MusicFamily.guess("Moon Base") == .spaceAdventure && MusicFamily.guess("Rocket to the Stars") == .spaceAdventure)
        // Circus & carnival: before magic, so a magic show is the circus
        #expect(MusicFamily.guess("Big Top Circus") == .circusCarnival && MusicFamily.guess("The Magic Show") == .circusCarnival)
        #expect(MusicFamily.guess("Clown Carnival") == .circusCarnival && MusicFamily.guess("County Fair") == .circusCarnival)
        #expect(MusicFamily.guess("Fairy Garden") == .magical && MusicFamily.guess("Magic Castle") == .magical)
        // Race day
        #expect(MusicFamily.guess("Race Car Rally") == .raceDay && MusicFamily.guess("Backyard Olympics") == .raceDay)
        #expect(MusicFamily.guess("Soccer Match") == .raceDay && MusicFamily.guess("Track Meet") == .raceDay)
        // The others still route as before
        #expect(MusicFamily.guess("Pirate Ship Treasure Hunt") == .pirateAdventure && MusicFamily.guess("Mermaid Lagoon") == .underTheSea)
        #expect(MusicFamily.guess("Fire Truck Rescue") == .rescueTeam && MusicFamily.guess("Sunny Bakery") == .cozyShop)
    }

    @Test func calmLoopOrder() {
        #expect(CalmLoop(count: 2).order(5) == [0, 1, 0, 1, 0])
        #expect(CalmLoop(count: 1).order(3) == [0, 0, 0])
        var l = CalmLoop(count: 2)
        #expect(l.index == 0 && l.next == 1)
        l.advance()
        #expect(l.index == 1 && l.next == 0)
        l.reset()
        #expect(l.index == 0)
        #expect(CalmLoop(count: 0).count == 1 && CalmLoop(count: 5).count == 2)
        // The next loop starts exactly where the one sounding ends (device clock arithmetic, no gap, no overlap).
        #expect(CalmLoop.endTime(startedAt: 100, duration: 32, position: 0) == 132)
        #expect(CalmLoop.endTime(startedAt: 100, duration: 32, position: 12) == 120)
        #expect(CalmLoop.endTime(startedAt: 100, duration: 32, position: 40) == 100)
    }
}
