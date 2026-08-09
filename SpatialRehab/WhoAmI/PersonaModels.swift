import Foundation

/// Fixed demo persona for the “Who am I?” name-card feature (hackathon).
enum DemoPersona {
    static let selfID = FamilyMember.ID("self-chio-bu")
    static let ahPekID = FamilyMember.ID("ah-pek")
    static let weiMingID = FamilyMember.ID("wei-ming")
    static let meiLingID = FamilyMember.ID("mei-ling")
    static let junHaoID = FamilyMember.ID("jun-hao")
    static let szeHaoID = FamilyMember.ID("sze-hao")

    static let owner = FamilyMember(
        id: selfID,
        englishName: "Lim Chio Bu",
        chineseName: "林招母",
        emoji: "👵",
        relationEnglish: "You",
        relationChinese: "您自己",
        birthday: calendarDate(year: 1948, month: 3, day: 12),
        hasGreetingVideo: false,
        videoLine: nil,
        photoName: "whoami-owner",
        homeAddress: "Blk 5 Banda Street #08-42, Singapore 050005",
        occupation: "Retired schoolteacher · 退休教师",
        icNumber: "S1234567D",
        emergencyContact: "Mei Ling (daughter · 女儿) · 8123 4567",
        aboutMe: "Loves gardening, morning taiji, and a good bowl of laksa · 爱园艺、晨间太极和叻沙",
        childrenIDs: []
    )

    static let members: [FamilyMember] = [
        FamilyMember(
            id: ahPekID,
            englishName: "Lim Ah Pek",
            chineseName: "林亚伯",
            emoji: "👴",
            relationEnglish: "Your husband",
            relationChinese: "您的丈夫",
            birthday: calendarDate(year: 1945, month: 8, day: 3),
            hasGreetingVideo: false,
            videoLine: nil,
            childrenIDs: []
        ),
        FamilyMember(
            id: weiMingID,
            englishName: "Lim Wei Ming",
            chineseName: "林伟明",
            emoji: "👨",
            relationEnglish: "Your son",
            relationChinese: "您的儿子",
            birthday: calendarDate(year: 1972, month: 5, day: 20),
            hasGreetingVideo: false,
            videoLine: nil,
            childrenIDs: []
        ),
        FamilyMember(
            id: meiLingID,
            englishName: "Lim Mei Ling",
            chineseName: "林美玲",
            emoji: "👩",
            relationEnglish: "Your daughter",
            relationChinese: "您的女儿",
            birthday: calendarDate(year: 1975, month: 11, day: 8),
            hasGreetingVideo: false,
            videoLine: nil,
            childrenIDs: [szeHaoID]
        ),
        FamilyMember(
            id: junHaoID,
            englishName: "Lim Jun Hao",
            chineseName: "林俊豪",
            emoji: "👨",
            relationEnglish: "Your son",
            relationChinese: "您的儿子",
            birthday: calendarDate(year: 1978, month: 2, day: 14),
            hasGreetingVideo: false,
            videoLine: nil,
            childrenIDs: []
        ),
        FamilyMember(
            id: szeHaoID,
            englishName: "Sze Hao",
            chineseName: "思豪",
            emoji: "🧑‍💻",
            relationEnglish: "Your grandson",
            relationChinese: "您的孙子",
            birthday: calendarDate(year: 1998, month: 6, day: 1),
            hasGreetingVideo: true,
            videoLine: "Hi, I'm Sze Hao. Love u Grandma.",
            videoFileName: "szehao_greeting",
            childrenIDs: []
        ),
    ]

    static func member(id: FamilyMember.ID) -> FamilyMember? {
        if id == selfID { return owner }
        return members.first { $0.id == id }
    }

    /// Top couple for the tree face.
    static var parents: (husband: FamilyMember, selfMember: FamilyMember) {
        (members.first { $0.id == ahPekID }!, owner)
    }

    /// Three children under the couple.
    static var children: [FamilyMember] {
        [weiMingID, meiLingID, junHaoID].compactMap(member(id:))
    }

    private static func calendarDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar(identifier: .gregorian).date(from: components) ?? .now
    }
}

struct FamilyMember: Identifiable, Hashable, Sendable {
    struct ID: Hashable, Sendable, Codable {
        let rawValue: String
        init(_ rawValue: String) { self.rawValue = rawValue }
    }

    let id: ID
    let englishName: String
    let chineseName: String
    let emoji: String
    let relationEnglish: String
    let relationChinese: String
    let birthday: Date?
    let hasGreetingVideo: Bool
    let videoLine: String?
    var videoFileName: String? = nil
    /// Asset-catalog portrait; falls back to `emoji` wherever no photo exists yet.
    var photoName: String? = nil
    /// Shown on the card face so a disoriented person can read where home is.
    var homeAddress: String? = nil
    /// Life's work, for reminiscence — shown on the card face when known.
    var occupation: String? = nil
    /// NRIC, shown as a chip on the card face. Demo data uses an obviously
    /// fictional number — never ship a real one in the repo.
    var icNumber: String? = nil
    /// Who to call when help is needed — the most useful field on real dementia
    /// ID cards; shown as its own row in the card's data zone.
    var emergencyContact: String? = nil
    /// One reminiscence line (person-centred care) — shown under the data zone.
    var aboutMe: String? = nil
    let childrenIDs: [ID]

    var bilingualRelation: String {
        "\(relationEnglish) · \(relationChinese)"
    }

    /// Bundled greeting video, when one has been recorded.
    var videoURL: URL? {
        guard let videoFileName else { return nil }
        return Bundle.main.url(forResource: videoFileName, withExtension: "mov")
    }

    /// Whole years since `birthday`, for the "78 years young" chip on the card face.
    var age: Int? {
        guard let birthday else { return nil }
        return Calendar.current.dateComponents([.year], from: birthday, to: .now).year
    }

    var formattedBirthday: String? {
        guard let birthday else { return nil }
        return birthday.formatted(
            Date.FormatStyle()
                .year()
                .month(.wide)
                .day()
                .locale(Locale(identifier: "en_SG"))
        )
    }
}
