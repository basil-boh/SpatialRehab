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
        portraitVideoName: "chiobu_portrait",
        photoName: "whoami-owner",
        homeAddress: "Blk 5 Banda Street #08-42, Singapore 050005",
        occupation: "Retired schoolteacher · 退休教师",
        icNumber: "S1234567D",
        emergencyContact: "Mei Ling (daughter · 女儿) · 8123 4567",
        aboutMe: "Loves gardening, morning taiji, and a good bowl of laksa · 爱园艺、晨间太极和叻沙",
        // What Ah Pek calls her in his greeting clip ("Ah Bu, come drink kopi with me").
        familiarName: "Ah Bu",
        familiarChineseName: "招母",
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
            videoLine: "Ah Bu, come drink kopi with me. · 招母，来喝杯咖啡。",
            // Placeholder clip — swap for real footage of Ah Pek when it exists.
            portraitVideoName: "ahpek_portrait",
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
            videoLine: "Ma, I'll bring the grandchildren over this Sunday. · 妈，这个星期天我带孙子回来看您。",
            portraitVideoName: "weiming_portrait",
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
            videoLine: "Ma, remember to take your medicine. I'll call you tonight. · 妈，记得吃药，晚上我打电话给您。",
            portraitVideoName: "meiling_portrait",
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
            videoLine: "Ma, nobody cooks laksa like you. · 妈，没人煮的叻沙比您的好吃。",
            portraitVideoName: "junhao_portrait",
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
            portraitVideoName: "szehao_portrait",
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
    /// Short silent clip that loops forever in the family tree so the portrait is alive.
    /// Kept separate from `videoFileName` (the spoken greeting played on pinch) because
    /// the two have opposite requirements: this one is muted, seamless, and neutral.
    var portraitVideoName: String? = nil
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
    /// What the family actually calls this person, for greetings ("Good morning, Ah Bu").
    /// Separate from `englishName`, which is the full legal name the ID card needs: reading
    /// "Good morning, Lim Chio Bu" to someone in her own home is not a greeting, it is a
    /// roll call. Added 2026-08-10 for the home screen's orientation header; falls back to
    /// `englishName` wherever it is unset.
    var familiarName: String? = nil
    /// The 中文 counterpart of `familiarName`, same reasoning.
    var familiarChineseName: String? = nil
    let childrenIDs: [ID]

    /// The greeting form of this person's name in each language, falling back to the full
    /// name when no familiar form has been recorded.
    var greetingName: String { familiarName ?? englishName }
    var greetingChineseName: String { familiarChineseName ?? chineseName }

    var bilingualRelation: String {
        "\(relationEnglish) · \(relationChinese)"
    }

    /// Bundled greeting video, when one has been recorded.
    var videoURL: URL? {
        guard let videoFileName else { return nil }
        return Bundle.main.url(forResource: videoFileName, withExtension: "mov")
    }

    /// Bundled looping portrait clip, when one exists for this member.
    var portraitVideoURL: URL? {
        guard let portraitVideoName else { return nil }
        return Bundle.main.url(forResource: portraitVideoName, withExtension: "mov")
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
