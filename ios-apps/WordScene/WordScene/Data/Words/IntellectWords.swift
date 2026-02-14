import Foundation

/// Words related to knowledge, thought, logic, and intellectual concepts
let intellectWords: [VocabularyWord] = [

    VocabularyWord(
        id: "epistemology",
        word: "Epistemology",
        pronunciation: "eh-pis-teh-MOL-oh-jee",
        definition: "The branch of philosophy concerned with the nature and scope of knowledge — how we know what we know",
        etymology: "From Greek episteme (knowledge) + logos (study). The study of knowledge itself.",
        partOfSpeech: "noun",
        scenarios: [
            "The epistemology seminar got derailed when a student asked, 'But how do we know we know things?' The professor stared into the middle distance for a long time. Class was dismissed early.",
            "She brought up epistemology at the dinner party and cleared half the table. The remaining guests were a philosopher and a man who thought she'd said 'epistolary' and was waiting to talk about letters.",
            "His four-year-old entered an epistemology phase, responding to every statement with 'But how do you know?' Bedtime took three hours. Philosophy, he decided, should have an age requirement."
        ]
    ),

    VocabularyWord(
        id: "sophistry",
        word: "Sophistry",
        pronunciation: "SOF-ih-stree",
        definition: "The use of clever but false arguments, especially with the intent to deceive",
        etymology: "From Greek sophistes (wise man, expert), from sophos (wise). The Sophists were ancient Greek teachers of rhetoric — Plato despised them for prioritizing persuasion over truth.",
        partOfSpeech: "noun",
        scenarios: [
            "His argument for why eating an entire cake counted as 'one serving' was pure sophistry — technically coherent, practically absurd, and delivered with the confidence of a man who had already eaten the cake.",
            "The lawyer's sophistry was so elegant that the jury almost forgot the defendant had been caught on three separate cameras. Almost. He was convicted. The closing argument got a golf clap.",
            "She recognized the sophistry in the toddler's logic: 'You said no cookies BEFORE dinner. Dinner is over. Therefore, infinite cookies.' She was appalled and, privately, a little proud."
        ]
    ),

    VocabularyWord(
        id: "hermeneutics",
        word: "Hermeneutics",
        pronunciation: "her-meh-NOO-tiks",
        definition: "The theory and methodology of interpretation, especially of texts and meaning",
        etymology: "From Greek hermeneutikos (of interpretation), associated with Hermes, the messenger god who interpreted the will of the gods for mortals.",
        partOfSpeech: "noun",
        scenarios: [
            "The hermeneutics of his girlfriend's text — 'Fine.' — occupied him for forty-five minutes. He consulted three friends, two Reddit threads, and a horoscope. None provided clarity.",
            "The professor of hermeneutics spent an entire semester on a single poem. By week twelve, students either loved literature or hated it with a specificity they could never have achieved alone.",
            "She applied hermeneutics to the IKEA assembly instructions and concluded they were either written by a genius or a person who had never seen furniture. The bookshelf, once finished, leaned."
        ]
    ),

    VocabularyWord(
        id: "non-sequitur",
        word: "Non sequitur",
        pronunciation: "non SEK-wih-tur",
        definition: "A statement or conclusion that does not logically follow from the previous argument or statement",
        etymology: "Latin for 'it does not follow.' A logical fallacy that has been annoying philosophers since antiquity.",
        partOfSpeech: "noun",
        scenarios: [
            "His non sequitur during the budget meeting — 'Speaking of quarterly projections, has anyone seen my stapler?' — briefly derailed the conversation but permanently endeared him to the intern who had, in fact, seen his stapler.",
            "The debate descended into non sequitur territory when the candidate responded to a question about healthcare by talking about his childhood dog. The moderator's eye twitched visibly.",
            "She was the queen of the non sequitur, once responding to 'How was your weekend?' with 'Dolphins sleep with one eye open.' Her coworkers had learned not to ask follow-up questions."
        ]
    ),

    VocabularyWord(
        id: "autodidact",
        word: "Autodidact",
        pronunciation: "AW-toh-DY-dakt",
        definition: "A self-taught person; someone who has learned a subject without formal instruction",
        etymology: "From Greek autodidaktos: autos (self) + didaktos (taught). The person who didn't need the classroom.",
        partOfSpeech: "noun",
        scenarios: [
            "The autodidact at the party could discuss quantum physics, Renaissance painting, and Korean fermentation techniques. He had no degrees. He had a library card and absolutely no social life.",
            "She described herself as an autodidact, which sounded impressive until you learned that her primary subjects were true crime podcasts and competitive baking shows. She was, to be fair, an expert in both.",
            "The autodidact's bookshelf told the story of a restless mind: astrophysics next to bread-making next to Mandarin for beginners next to a half-finished book about taxidermy. He contained multitudes."
        ]
    ),

    VocabularyWord(
        id: "pedantic",
        word: "Pedantic",
        pronunciation: "peh-DAN-tik",
        definition: "Excessively concerned with minor details or rules, especially in academic matters; showing off learning",
        etymology: "From Italian pedante (teacher), possibly from Greek paideuein (to teach). When teaching becomes insufferable.",
        partOfSpeech: "adjective",
        scenarios: [
            "His pedantic correction — 'Actually, it's fewer, not less' — earned him the silence of the entire dinner table and a look from his wife that could strip paint. He was technically correct, which is the worst kind.",
            "The pedantic reviewer left a three-star rating because the menu said 'panini' when there was only one. 'The singular is panino,' they wrote. The restaurant's food was excellent. The reviewer had no friends.",
            "She knew she was being pedantic when she corrected her five-year-old's drawing of a dinosaur. 'T. rex arms were much smaller,' she said. The child stared at her. The child was five. The child walked away."
        ]
    ),

    VocabularyWord(
        id: "quixotic",
        word: "Quixotic",
        pronunciation: "kwik-SOT-ik",
        definition: "Extremely idealistic; unrealistic and impractical, especially in pursuit of noble goals",
        etymology: "From Don Quixote, Cervantes' 1605 novel about a delusional knight who fights windmills. When idealism becomes its own adventure.",
        partOfSpeech: "adjective",
        scenarios: [
            "His quixotic plan to organize the entire neighborhood's recycling by hand lasted approximately one Saturday morning before he encountered a bin that had been used as a diaper disposal. The dream died instantly.",
            "The quixotic startup promised to 'end email forever.' Three years and twelve million dollars later, they pivoted to — wait for it — a new email app.",
            "Her quixotic crusade to get the office to switch to standing desks had all the passion of a revolution and none of the support. She stood alone. Literally."
        ]
    ),

    VocabularyWord(
        id: "tautology",
        word: "Tautology",
        pronunciation: "taw-TOL-oh-jee",
        definition: "A statement that is true by definition and therefore says nothing meaningful; needless repetition of the same idea in different words",
        etymology: "From Greek tautologia: tauto (the same) + logos (word, reason). Saying the same thing twice, differently, again.",
        partOfSpeech: "noun",
        scenarios: [
            "The CEO's statement — 'We will succeed because we are committed to success' — was a tautology so pure it could have been used as a textbook example. The investors applauded. The logic professor wept.",
            "She pointed out that 'free gift' was a tautology, since gifts are by definition free. Her friend said 'thank you for your unnecessary correction.' She noted that was redundant too. The friendship survived, barely.",
            "The weather forecast promised 'rain during rainy conditions,' which was either a tautology or a cry for help from a meteorologist who had simply given up."
        ]
    ),

    VocabularyWord(
        id: "perspicacious",
        word: "Perspicacious",
        pronunciation: "per-spih-KAY-shus",
        definition: "Having keen mental perception and understanding; shrewd and discerning",
        etymology: "From Latin perspicax (sharp-sighted), from perspicere (to look through). Seeing through things — literally and figuratively.",
        partOfSpeech: "adjective",
        scenarios: [
            "The perspicacious five-year-old looked at the broken cookie jar, then at her father's guilty face, and said, 'Daddy, I think we both know what happened here.' He confessed immediately.",
            "Her perspicacious reading of the room saved the meeting: she could tell the VP was about to announce layoffs by the way he'd brought donuts. No one brings donuts for good news.",
            "The detective's perspicacious observation — that the suspect was wearing two different shoes — cracked the case wide open. It also, admittedly, raised questions about the suspect's morning routine."
        ]
    ),

    VocabularyWord(
        id: "Pyrrhic",
        word: "Pyrrhic",
        pronunciation: "PEER-ik",
        definition: "Describing a victory that inflicts such devastating costs on the winner that it is practically a defeat",
        etymology: "Named after King Pyrrhus of Epirus, who defeated the Romans in 279 BC but lost so many soldiers he reportedly said, 'One more such victory and we are undone.'",
        partOfSpeech: "adjective",
        scenarios: [
            "His Pyrrhic victory in the argument was complete: he had proven, with receipts, that he was right about the restaurant reservation. She had not spoken to him in three days. He dined alone, correctly.",
            "The company's Pyrrhic acquisition of their rival cost so much in debt and restructuring that the CEO's 'We won' email read more like a eulogy. The champagne remained unopened.",
            "She won the HOA battle over fence height — a classic Pyrrhic victory. The fence was now regulation. Her neighbors now communicated exclusively through lawyers."
        ]
    ),

    VocabularyWord(
        id: "empirical",
        word: "Empirical",
        pronunciation: "em-PEER-ih-kul",
        definition: "Based on observation and experience rather than theory or pure logic",
        etymology: "From Greek empeirikos (experienced), from empeiria (experience). Knowledge gained by doing, not just thinking.",
        partOfSpeech: "adjective",
        scenarios: [
            "His empirical approach to cooking — 'let's see what happens if I add this' — had produced exactly two great meals and fourteen small fires. He called it 'research.' His smoke detector called it 'Tuesday.'",
            "The empirical evidence was clear: every time she watered the plant, it thrived. Every time her roommate watered the plant, it wilted. The plant had preferences. Science had spoken.",
            "The toddler's empirical investigation into gravity — dropping food from the high chair — was rigorous, repeatable, and deeply annoying. The results were consistent: everything falls. The dog was thrilled."
        ]
    ),

    VocabularyWord(
        id: "syllogism",
        word: "Syllogism",
        pronunciation: "SIL-oh-jiz-um",
        definition: "A form of logical reasoning consisting of a major premise, a minor premise, and a conclusion drawn from them",
        etymology: "From Greek syllogismos (reckoning together), from syn (together) + logizesthai (to reason). Aristotle's favorite logical form.",
        partOfSpeech: "noun",
        scenarios: [
            "She constructed a flawless syllogism: All meetings could have been emails. This is a meeting. Therefore, this could have been an email. Her manager was not amused. Logic, apparently, has limits.",
            "His bedtime syllogism to his parents: Dogs sleep on beds. I am basically a dog. Therefore, I should sleep in your bed. The logic was sound. He was returned to his own bed anyway.",
            "The philosophy exam asked students to identify the flaw in the syllogism: 'All cats are independent. Whiskers is independent. Therefore, Whiskers is a cat.' Three students drew pictures of cats instead of answering."
        ]
    ),

    VocabularyWord(
        id: "liminal",
        word: "Liminal",
        pronunciation: "LIM-ih-nul",
        definition: "Relating to a transitional or in-between state; occupying a position at or on both sides of a boundary",
        etymology: "From Latin limen (threshold). The space between what was and what will be — doorways, dusk, airports at 3 AM.",
        partOfSpeech: "adjective",
        scenarios: [
            "Airports are the most liminal spaces on earth — you are neither here nor there, neither arriving nor departing, and the Cinnabon is always open because time has no meaning.",
            "She described her twenties as a liminal decade, suspended between who she was and who she'd become. Her mother described it as 'the decade she didn't call enough.'",
            "The liminal space between sending a risky text and getting a response is where all personal growth occurs. Or all panic. Often both."
        ]
    ),

    VocabularyWord(
        id: "heuristic",
        word: "Heuristic",
        pronunciation: "hyoo-RIS-tik",
        definition: "A practical approach to problem-solving that uses shortcuts or rules of thumb rather than exhaustive analysis",
        etymology: "From Greek heuriskein (to find, discover). Related to Archimedes' 'Eureka!' — literally 'I have found it!'",
        partOfSpeech: "noun",
        scenarios: [
            "Her heuristic for choosing restaurants was simple: if the menu had photos, leave. If the menu was in a language she couldn't read, stay. This system had a 73% success rate, which she considered excellent.",
            "His heuristic for assembling furniture: if there are leftover screws, something has gone wrong. If there are no leftover screws, something has also probably gone wrong, just more subtly.",
            "The programmer's heuristic — 'if it works, don't touch it' — had kept the legacy system running for fifteen years. No one understood how. No one dared ask."
        ]
    ),

    VocabularyWord(
        id: "apocryphal",
        word: "Apocryphal",
        pronunciation: "uh-POK-rih-ful",
        definition: "Of doubtful authenticity; widely circulated but probably untrue",
        etymology: "From Greek apokryphos (hidden, obscure), from apokryptein (to hide away). Originally described texts excluded from the biblical canon.",
        partOfSpeech: "adjective",
        scenarios: [
            "The apocryphal story about the CEO starting the company in a garage was repeated at every all-hands meeting. In reality, he started it in a rather nice apartment. The garage tested better with investors.",
            "Every family has an apocryphal origin story. Hers involved a grandmother who supposedly arm-wrestled a bear. No one questioned it. The grandmother had been five feet tall. The legend endured.",
            "The 'fact' that humans swallow eight spiders a year in their sleep is entirely apocryphal — it was invented to show how easily misinformation spreads. It worked. You probably believed it."
        ]
    ),
]
