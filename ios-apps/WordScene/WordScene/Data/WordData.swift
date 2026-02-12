import Foundation

/// All 30 vocabulary words with dramatic, funny scenarios
/// inspired by Moira Rose and courtroom drama.
let allWords: [VocabularyWord] = [

    // MARK: - Legal Vocabulary

    VocabularyWord(
        id: "adjudicate",
        word: "Adjudicate",
        definition: "To make a formal judgment or decision about a problem or dispute",
        partOfSpeech: "verb",
        scenario: "The HOA called an emergency meeting to adjudicate the Great Flamingo Dispute of 2024. Karen had placed forty-seven plastic flamingos on her lawn, and the neighborhood would never be the same."
    ),
    VocabularyWord(
        id: "deposition",
        word: "Deposition",
        definition: "A formal sworn statement taken outside of court, used as evidence",
        partOfSpeech: "noun",
        scenario: "During the deposition, the witness broke down and confessed that she had, in fact, eaten the last donut in the break room. The stenographer gasped. The attorney loosened his tie."
    ),
    VocabularyWord(
        id: "subpoena",
        word: "Subpoena",
        definition: "A legal document ordering someone to attend court or produce evidence",
        partOfSpeech: "noun",
        scenario: "Moira received a subpoena to testify about the missing town funds, which she described as 'a ghastly piece of bureaucratic correspondence that clashes with my entire afternoon aesthetic.'"
    ),
    VocabularyWord(
        id: "litigate",
        word: "Litigate",
        definition: "To take a dispute to court; to engage in legal proceedings",
        partOfSpeech: "verb",
        scenario: "Rather than simply returning the borrowed casserole dish, the neighbors chose to litigate. Four lawyers, two expert witnesses, and one very confused judge later, the dish remained unclaimed."
    ),
    VocabularyWord(
        id: "precedent",
        word: "Precedent",
        definition: "An earlier event or legal decision used as a guide for future situations",
        partOfSpeech: "noun",
        scenario: "The judge cited precedent from the landmark case of Stevens v. Stevens, in which a man successfully sued his twin brother for stealing his personality. The courtroom erupted."
    ),
    VocabularyWord(
        id: "acquittal",
        word: "Acquittal",
        definition: "A judgment that a person is not guilty of the crime they were charged with",
        partOfSpeech: "noun",
        scenario: "Upon hearing her acquittal, Moira rose from the defendant's chair, adjusted her wig, and declared, 'Justice, like couture, is timeless.' The bailiff slow-clapped."
    ),
    VocabularyWord(
        id: "plaintiff",
        word: "Plaintiff",
        definition: "The person who brings a case against another in a court of law",
        partOfSpeech: "noun",
        scenario: "The plaintiff took the stand clutching a three-ring binder of grievances, color-coded by emotional damage. 'Exhibit A,' she announced, holding up a screenshot of an unreturned text message.'"
    ),
    VocabularyWord(
        id: "stipulate",
        word: "Stipulate",
        definition: "To demand or specify as part of an agreement or condition",
        partOfSpeech: "verb",
        scenario: "The contract did stipulate that all office birthday parties must include at least one vegan option. When HR forgot, Gerald from Accounting filed a formal complaint and a very dramatic resignation letter."
    ),
    VocabularyWord(
        id: "affidavit",
        word: "Affidavit",
        definition: "A written statement confirmed by oath, used as evidence in court",
        partOfSpeech: "noun",
        scenario: "She submitted a twelve-page affidavit swearing under oath that her roommate had used her expensive shampoo. Attached were receipts, hair strand analysis, and a diagram of the shower shelf."
    ),
    VocabularyWord(
        id: "indictment",
        word: "Indictment",
        definition: "A formal charge or accusation of a serious crime",
        partOfSpeech: "noun",
        scenario: "The indictment was read aloud in a hushed courtroom: one count of grand larceny for stealing the community garden's prize-winning zucchini. The defendant showed no remorse and frankly looked delicious."
    ),
    VocabularyWord(
        id: "perjury",
        word: "Perjury",
        definition: "The offense of willfully telling a lie after taking an oath",
        partOfSpeech: "noun",
        scenario: "'That is perjury!' the prosecutor thundered, pointing at the witness. 'You SAID you don't watch reality TV, yet your screen time report shows fourteen hours of Love Island this week alone.'"
    ),
    VocabularyWord(
        id: "exculpatory",
        word: "Exculpatory",
        definition: "Tending to clear someone from blame or guilt",
        partOfSpeech: "adjective",
        scenario: "The defense presented exculpatory evidence: a timestamped selfie proving the defendant was at an ABBA tribute concert during the alleged crime. The jury nodded. The alibi was, frankly, iconic."
    ),
    VocabularyWord(
        id: "jurisprudence",
        word: "Jurisprudence",
        definition: "The theory or philosophy of law; the study of legal systems",
        partOfSpeech: "noun",
        scenario: "Professor Hartley opened the jurisprudence lecture by asking, 'Is it illegal to microwave fish in a shared office kitchen?' Three students cried. One called their therapist. The debate lasted two hours."
    ),
    VocabularyWord(
        id: "arbitration",
        word: "Arbitration",
        definition: "The settling of a dispute by an impartial third party rather than in court",
        partOfSpeech: "noun",
        scenario: "The family Thanksgiving devolved so badly they hired a professional for arbitration. After reviewing evidence from both sides, the mediator ruled that Aunt Linda had, in fact, started it."
    ),
    VocabularyWord(
        id: "habeas-corpus",
        word: "Habeas corpus",
        definition: "A court order requiring a person to be brought before a judge, protecting against unlawful detention",
        partOfSpeech: "noun",
        scenario: "When the toddler was placed in timeout for the third consecutive hour, her older brother filed an emergency habeas corpus motion with their mother. 'She has rights!' he declared, holding a crayon-written petition."
    ),

    // MARK: - Sophisticated Everyday Words

    VocabularyWord(
        id: "beleaguered",
        word: "Beleaguered",
        definition: "In a very difficult situation; beset by problems or harassment",
        partOfSpeech: "adjective",
        scenario: "The beleaguered barista had survived the morning rush, a broken espresso machine, and a customer who ordered a 'medium-large.' She stared into the void. The void ordered a flat white."
    ),
    VocabularyWord(
        id: "perfunctory",
        word: "Perfunctory",
        definition: "Carried out with minimal effort or thought; done as a routine duty",
        partOfSpeech: "adjective",
        scenario: "He gave a perfunctory wave to his neighbor while mentally calculating whether he could make it inside before being trapped in another forty-minute conversation about lawn fertilizer."
    ),
    VocabularyWord(
        id: "obsequious",
        word: "Obsequious",
        definition: "Excessively eager to serve or please; fawning",
        partOfSpeech: "adjective",
        scenario: "The obsequious waiter complimented everything they ordered. 'The chicken? Exquisite choice. Water? Bold. Sparkling? You absolute visionary.' By dessert, they were genuinely uncomfortable."
    ),
    VocabularyWord(
        id: "ebullient",
        word: "Ebullient",
        definition: "Overflowing with enthusiasm, excitement, or cheerfulness",
        partOfSpeech: "adjective",
        scenario: "Moira was positively ebullient upon discovering the town had named a bench after her. 'A bench!' she cried, clasping her hands. 'It's practically a monument. Next stop, a commemorative gazebo.'"
    ),
    VocabularyWord(
        id: "mercurial",
        word: "Mercurial",
        definition: "Subject to sudden and unpredictable changes of mood or behavior",
        partOfSpeech: "adjective",
        scenario: "The director's mercurial temperament kept the cast on edge. One moment he was weeping over the beauty of Act Two; the next, he was hurling a beret at the lighting technician."
    ),
    VocabularyWord(
        id: "ineffable",
        word: "Ineffable",
        definition: "Too great or extreme to be expressed or described in words",
        partOfSpeech: "adjective",
        scenario: "She experienced an ineffable joy upon finding a twenty-dollar bill in her winter coat pocket. It was spiritual. It was transcendent. She immediately spent it on cheese."
    ),
    VocabularyWord(
        id: "sycophant",
        word: "Sycophant",
        definition: "A person who flatters someone important in order to gain an advantage",
        partOfSpeech: "noun",
        scenario: "Every sycophant in the office gathered around the new CEO like moths to a very expensive flame. 'Love the tie,' said one. 'Is that a new haircut?' asked another. He was bald."
    ),
    VocabularyWord(
        id: "lugubrious",
        word: "Lugubrious",
        definition: "Looking or sounding sad and dismal; mournful",
        partOfSpeech: "adjective",
        scenario: "The lugubrious hound sat by the empty food bowl as if composing a canine requiem. His owner had been gone for eleven minutes. He had already accepted his fate as an orphan."
    ),
    VocabularyWord(
        id: "recalcitrant",
        word: "Recalcitrant",
        definition: "Stubbornly uncooperative; resistant to authority or control",
        partOfSpeech: "adjective",
        scenario: "The recalcitrant printer refused to cooperate for the third time that morning. IT was called. Prayers were offered. Someone suggested an exorcism. The printer jammed again out of spite."
    ),
    VocabularyWord(
        id: "magnanimous",
        word: "Magnanimous",
        definition: "Very generous or forgiving, especially toward a rival or someone less powerful",
        partOfSpeech: "adjective",
        scenario: "In a magnanimous gesture, Moira offered to share her award-winning rosé with the woman who had insulted her wig. 'I forgive you,' she said, pouring exactly half a sip."
    ),
    VocabularyWord(
        id: "supercilious",
        word: "Supercilious",
        definition: "Behaving as though one thinks they are superior to others; condescending",
        partOfSpeech: "adjective",
        scenario: "The supercilious sommelier raised one eyebrow when they ordered the house red. 'The house red,' he repeated, as though they had requested a juice box. He poured it like a funeral rite."
    ),
    VocabularyWord(
        id: "vociferous",
        word: "Vociferous",
        definition: "Expressing opinions or feelings loudly and forcefully; clamorous",
        partOfSpeech: "adjective",
        scenario: "The vociferous objections from the audience drowned out the school board's announcement. Apparently, canceling Taco Tuesday was the line no one was willing to let them cross."
    ),
    VocabularyWord(
        id: "ennui",
        word: "Ennui",
        definition: "A feeling of listlessness and dissatisfaction arising from boredom or lack of excitement",
        partOfSpeech: "noun",
        scenario: "Overcome with ennui, Moira draped herself across the chaise lounge and declared, 'There is nothing left for me in this town. Not a single thing.' David reminded her that lunch was in five minutes. She perked up."
    ),
    VocabularyWord(
        id: "obfuscate",
        word: "Obfuscate",
        definition: "To make something unclear, confusing, or difficult to understand",
        partOfSpeech: "verb",
        scenario: "The CEO's attempt to obfuscate the quarterly losses involved a PowerPoint with seventeen pie charts, a metaphor about eagles, and a motivational quote from a fortune cookie. No one was fooled."
    ),
    VocabularyWord(
        id: "perspicacious",
        word: "Perspicacious",
        definition: "Having keen mental perception and understanding; shrewd",
        partOfSpeech: "adjective",
        scenario: "The perspicacious five-year-old looked at the broken cookie jar, then at her father's guilty face, and said, 'Daddy, I think we both know what happened here.' He confessed immediately."
    ),
]
