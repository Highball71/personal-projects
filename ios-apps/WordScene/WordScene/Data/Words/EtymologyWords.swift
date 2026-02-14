import Foundation

/// Common English words with surprising etymologies for the "Deeper Than You Knew" mode
let etymologyWords: [EtymologyWord] = [

    EtymologyWord(
        id: "etym-sophomoric",
        word: "Sophomoric",
        casualIntro: "You probably use this to describe someone who thinks they're way smarter than they actually are — that friend who read one Wikipedia article and now won't shut up.",
        originLanguage: "Greek",
        breakdown: "sophos (wise) + moros (fool)",
        literalMeaning: "wise fool",
        originStory: "The Greeks nailed it with this one. They combined 'sophos' (wise) and 'moros' (fool) to create the perfect paradox: a wise fool. Someone who's learned just enough to be dangerous but not enough to know how little they know. It's why college sophomores are called that — they've survived one year and now think they've figured everything out. Spoiler: they have not."
    ),

    EtymologyWord(
        id: "etym-penultimate",
        word: "Penultimate",
        casualIntro: "You've probably heard someone use this thinking it means 'the absolute ultimate, but even better.' It's one of the most commonly misused words in English.",
        originLanguage: "Latin",
        breakdown: "paene (almost) + ultimus (last)",
        literalMeaning: "almost the last",
        originStory: "Here's the thing — 'penultimate' doesn't mean 'super ultimate.' It means second to last. That's it. Latin 'paene' means 'almost' and 'ultimus' means 'last.' So the penultimate episode of a show is the one before the finale. The penultimate slice of pizza is the one before the sad last piece nobody wants to take. It's humbler than people think."
    ),

    EtymologyWord(
        id: "etym-sarcasm",
        word: "Sarcasm",
        casualIntro: "You've definitely used this one — probably today, even. It's the go-to defense mechanism of the perpetually unimpressed.",
        originLanguage: "Greek",
        breakdown: "sarkazein (to tear flesh)",
        literalMeaning: "to strip someone raw",
        originStory: "The Greeks didn't mess around. 'Sarkazein' literally meant to tear or strip flesh, like an animal ripping meat from bone. It evolved to mean biting your lip in rage, then speaking with a bitterness that cuts to the bone. So every time you say 'Oh, great plan' to your coworker's terrible idea, you're etymologically tearing their flesh off. The Greeks would be proud."
    ),

    EtymologyWord(
        id: "etym-disaster",
        word: "Disaster",
        casualIntro: "You throw this word around every time something goes sideways — a bad meeting, a burned dinner, a Monday.",
        originLanguage: "Italian / Latin",
        breakdown: "dis (bad) + astro (star)",
        literalMeaning: "bad star",
        originStory: "Before people blamed algorithms and Mercury retrograde, they blamed actual stars. 'Disastro' in Italian comes from 'dis' (bad) and 'astro' (star). A disaster was literally the result of unfavorable stars — your horoscope gone horribly wrong. So the next time your flight gets cancelled, you can accurately say you're having a disaster. The stars just weren't in your favor."
    ),

    EtymologyWord(
        id: "etym-nice",
        word: "Nice",
        casualIntro: "Possibly the most boring compliment in the English language. 'How was the movie?' 'Nice.' 'How's your new coworker?' 'Nice.' It means almost nothing now.",
        originLanguage: "Latin",
        breakdown: "nescius (ignorant, not knowing)",
        literalMeaning: "stupid, foolish",
        originStory: "Calling someone 'nice' in the 13th century was a straight-up insult. It came from Latin 'nescius,' meaning ignorant or foolish. Over the centuries it shapeshifted through 'timid' to 'fussy' to 'delicate' to 'precise' and finally landed on its current meaning of 'pleasant.' It took about 700 years for 'nice' to go from 'you're an idiot' to 'you're fine, I guess.' What a journey."
    ),

    EtymologyWord(
        id: "etym-silly",
        word: "Silly",
        casualIntro: "You call your friends this when they're being goofy — it's playful, harmless, maybe a little condescending. But it started out as something sacred.",
        originLanguage: "Old English",
        breakdown: "sælig (blessed, happy, holy)",
        literalMeaning: "blessed, fortunate",
        originStory: "In Old English, 'sælig' meant blessed, happy, or even holy. Calling someone silly was like calling them touched by God. Over the centuries it drifted from 'blessed' to 'innocent' to 'harmless' to 'simple-minded' to the modern 'foolish.' It's one of the most dramatic meaning reversals in English — from divine grace to 'stop making that face at the dinner table.'"
    ),

    EtymologyWord(
        id: "etym-clue",
        word: "Clue",
        casualIntro: "You use this constantly — 'I have no clue,' 'give me a clue.' It's just a word for a hint or piece of evidence, right? It's actually from Greek mythology.",
        originLanguage: "Greek mythology",
        breakdown: "clew (a ball of thread)",
        literalMeaning: "a ball of thread",
        originStory: "In the myth of the Minotaur, Theseus had to navigate the impossible labyrinth beneath Crete. Ariadne gave him a 'clew' — a ball of thread — to unwind as he went in, so he could follow it back out after slaying the beast. A 'clew' was literally the thing that guided you through a maze. Over time, the spelling changed and the meaning broadened: any thread of evidence that leads you through a puzzle. Every detective following clues is basically Theseus with a ball of yarn."
    ),

    EtymologyWord(
        id: "etym-sinister",
        word: "Sinister",
        casualIntro: "You use this to describe anything dark, threatening, or vaguely evil — a sinister plot, a sinister smile. But the original meaning was shockingly literal.",
        originLanguage: "Latin",
        breakdown: "sinister (left, left-handed)",
        literalMeaning: "left-handed, on the left side",
        originStory: "In Latin, 'sinister' simply meant 'left' or 'left-handed.' But in Roman culture (and many others), the left side was associated with bad omens and evil. Left-handed people were considered untrustworthy or unlucky. The word migrated from 'left' to 'unlucky' to 'evil' over the centuries. Meanwhile, 'dexter' (right-handed) gave us 'dexterous,' meaning skillful. Lefties really got a raw deal from etymology."
    ),

    EtymologyWord(
        id: "etym-trivial",
        word: "Trivial",
        casualIntro: "You use this to dismiss things that don't matter — trivial details, trivial complaints, trivia night at the pub.",
        originLanguage: "Latin",
        breakdown: "trivium (place where three roads meet)",
        literalMeaning: "of the crossroads, commonplace",
        originStory: "In ancient Rome, a 'trivium' was where three roads met — a crossroads. These were public gathering spots where ordinary people chatted, gossiped, and traded small talk. The stuff discussed at the trivium was considered common, everyday, unimportant — 'trivialis.' So 'trivial' literally means 'the kind of thing people talk about at a street corner.' Trivia night is unknowingly staying true to its Roman roots: random stuff people yap about where roads cross."
    ),

    EtymologyWord(
        id: "etym-assassin",
        word: "Assassin",
        casualIntro: "You know this word from history, movies, and video games. A killer for hire, a shadowy figure. The real origin is wilder than any movie.",
        originLanguage: "Arabic",
        breakdown: "hashishin (hashish users)",
        literalMeaning: "those who use hashish",
        originStory: "During the Crusades, a secretive sect called the Nizari Ismailis carried out targeted killings against political enemies. Their rivals called them 'Hashishin' — claiming they were drugged with hashish before their missions to eliminate fear. Whether they actually used hashish is debated by historians, but the name stuck. It traveled from Arabic through French and Italian into English as 'assassin.' So every spy thriller and stealth game owes its vocabulary to medieval propaganda about a group's alleged drug habits."
    ),
]
