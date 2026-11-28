import Testing
@testable import fartlekaudiocoach

struct HeartRateZoneTests {
    @MainActor
    @Test func compactZoneNamesAreReadable() {
        #expect(HeartRateZone.moderate.shortTitle == "Moderate")
        #expect(HeartRateZone.weightControl.shortTitle == "Weight control")
        #expect(HeartRateZone.aerobic.shortTitle == "Aerobic")
        #expect(HeartRateZone.anaerobic.shortTitle == "Anaerobic")
        #expect(HeartRateZone.vo2Max.shortTitle == "VO₂ max")
    }

    @Test func zoneBoundariesMatchHeartMonitor() {
        #expect(HeartRateZone.zone(forPercent: 0) == .moderate)
        #expect(HeartRateZone.zone(forPercent: 59) == .moderate)
        #expect(HeartRateZone.zone(forPercent: 60) == .weightControl)
        #expect(HeartRateZone.zone(forPercent: 69) == .weightControl)
        #expect(HeartRateZone.zone(forPercent: 70) == .aerobic)
        #expect(HeartRateZone.zone(forPercent: 79) == .aerobic)
        #expect(HeartRateZone.zone(forPercent: 80) == .anaerobic)
        #expect(HeartRateZone.zone(forPercent: 89) == .anaerobic)
        #expect(HeartRateZone.zone(forPercent: 90) == .vo2Max)
        #expect(HeartRateZone.zone(forPercent: 110) == .vo2Max)
    }

    @Test func bpmRangesMatchLivePercentConversion() {
        #expect(HeartRateZone.moderate.bpmSummary(maxHeartRate: 185) == "Below 111 BPM")
        #expect(HeartRateZone.weightControl.bpmSummary(maxHeartRate: 185) == "111–129 BPM")
        #expect(HeartRateZone.aerobic.bpmSummary(maxHeartRate: 185) == "130–147 BPM")
        #expect(HeartRateZone.anaerobic.bpmSummary(maxHeartRate: 185) == "148–166 BPM")
        #expect(HeartRateZone.vo2Max.bpmSummary(maxHeartRate: 185) == "167 BPM and above")
        for (bpm, zone) in [(110, HeartRateZone.moderate), (111, .weightControl),
                            (129, .weightControl), (130, .aerobic), (147, .aerobic),
                            (148, .anaerobic), (166, .anaerobic), (167, .vo2Max)] {
            let percent = HeartRateConverter.percent(from: bpm, maxHeartRate: 185)
            #expect(HeartRateZone.zone(forPercent: percent) == zone)
        }
    }

    @Test func invalidMaximumDoesNotProduceBpmRanges() {
        for zone in HeartRateZone.allCases {
            #expect(zone.bpmSummary(maxHeartRate: 0) == "Set your maximum heart rate in Settings.")
        }
    }
}
