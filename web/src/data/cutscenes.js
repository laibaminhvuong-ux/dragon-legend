import { renameDeep } from "./names.js";
// Boss cutscenes: a short scene before each story boss fight (played when you first come close)
// and one after you win. Keyed by the enemy's NPC id (the `enemy` of a quest's defeat step).
// Each line is [speaker, text]: speaker is an NPC id from data/story.js, or "you" (the player).
// The camera frames whoever speaks. Lines are the game's own wording, following the story's events.
// Any story boss without an entry gets a generic scene (see game/cutscene.js).

export const BOSS_SCENES = {
  // ------------------------------------------------------------ Saiyan Saga
  raditz: {
    before: [["raditz", "So Kakarot found friends. Weaklings, every one of you."], ["piccolo_plains", "He has Goku's boy. Strike together, and don't hold back."], ["you", "Give the kid back, Raditz."], ["raditz", "Then come and take him!"]],
    after: [["raditz", "Impossible... Nappa and Vegeta will come. They are far stronger than I am..."], ["piccolo_plains", "Two more Saiyans, in one year. We have a lot of training to do."]],
  },
  nappa: {
    before: [["nappa", "Heh. Vegeta, can I squash these bugs before Kakarot shows up?"], ["tien_gizard", "He's made of iron. Keep him busy and I'll find an opening."], ["you", "You've hurt enough people today."]],
    after: [["nappa", "Vegeta... help me..."], ["tien_gizard", "He's down. But Vegeta hasn't even moved yet."]],
  },
  vegeta_gizard: {
    before: [["vegeta_gizard", "I am the prince of all Saiyans. You are nothing to me."], ["krillin_gizard", "Watch the sky: if he makes a moon, he turns into a Great Ape!"], ["you", "Then I'll beat you before the moon rises."]],
    after: [["vegeta_gizard", "Defeated by low-class trash... This isn't over. I'll be back, stronger!"], ["krillin_gizard", "Let him go... Goku says he's earned another chance. I hope he's right."]],
  },
  // ------------------------------------------------------------ Namek & Frieza Saga
  dodoria: {
    before: [["dodoria", "Another village, another Dragon Ball. Burn it down!"], ["moori", "Please, stranger. Protect the children!"], ["you", "Not one more house burns."]],
    after: [["dodoria", "Lord Frieza will hear about this..."], ["moori", "Thank you. Namek will not forget you."]],
  },
  zarbon: {
    before: [["zarbon", "Such a pity. I do hate fighting in my ugly form."], ["bulma_namek", "Get the Dragon Ball away from him!"], ["you", "Then don't make me see it."]],
    after: [["zarbon", "Even my true form... wasn't enough..."], ["bulma_namek", "We've got the radar and the ball. Let's move before Frieza notices!"]],
  },
  guldo: {
    before: [["guldo", "Ginyu Force, pose! Ah... I'm first. Don't blink, or you'll miss me freeze time!"], ["vegeta_namek", "Strike when he runs out of breath. He can only stop time while he holds it."]],
    after: [["vegeta_namek", "One down. The rest of the Ginyu Force won't be such a joke."]],
  },
  recoome: {
    before: [["recoome", "Recoome! Eraser! Gun! Hold still, little fighter."], ["vegeta_namek", "He's all muscle and no brains. Hit him where it hurts."]],
    after: [["recoome", "Ow... no fair..."], ["vegeta_namek", "Hmph. Next."]],
  },
  burter: {
    before: [["burter", "I'm the fastest in the universe. You won't even see me coming."], ["you", "Let's find out."]],
    after: [["burter", "How... how were you faster than me?"]],
  },
  jeice: {
    before: [["jeice", "The Ginyu Force doesn't lose, mate. Crusher Ball!"], ["vegeta_namek", "The captain is behind him. Finish this quickly."]],
    after: [["jeice", "I'll... get the captain..."]],
  },
  ginyu_force: {
    before: [["ginyu_force", "Captain Ginyu! Your body has a fine power level. I think I'll take it."], ["vegeta_namek", "Don't let him swap bodies with you! Stay out of the light of his technique!"], ["you", "My body stays mine."]],
    after: [["ginyu_force", "My... beautiful body change..."], ["vegeta_namek", "The Ginyu Force is finished. Now only Frieza remains."]],
  },
  frieza: {
    before: [["frieza", "You've ruined my plans for immortality. For that, I'll take my time with you."], ["nail", "He has transformed again... Fight with everything Namek gave you."], ["you", "This planet isn't yours, Frieza."], ["frieza", "Every planet is mine. Shall I show you why?"]],
    after: [["frieza", "No... a Super Saiyan... the legend was true..."], ["nail", "Namek is breaking apart. Go, now, while you still can!"]],
  },
  mecha_frieza: {
    before: [["mecha_frieza", "Rebuilt with machine parts, and Earth will be the first to pay."], ["trunks_cc", "I'll handle this. Watch closely... and help if you can keep up."]],
    after: [["trunks_cc", "Frieza won't hurt anyone again. But his father is still here."]],
  },
  king_cold: {
    before: [["king_cold", "Young man, would you like to join my army? You'd make a fine soldier."], ["you", "I don't work for tyrants."]],
    after: [["trunks_cc", "Gather everyone. I have something to tell you about the future."]],
  },
  // ------------------------------------------------------------ Android & Cell Saga
  android_19: {
    before: [["android_19", "Energy absorption ready. Your ki will make a fine meal."], ["piccolo_gero", "Don't fire ki blasts! He drinks energy through his palms. Use your fists."]],
    after: [["piccolo_gero", "One down. The old one is Dr. Gero himself. Don't let him escape."]],
  },
  gero: {
    before: [["gero", "I have watched every fight you've had. I know exactly how to win."], ["you", "Then you missed the last one."]],
    after: [["gero", "No matter... my real creations are still waiting..."], ["piccolo_gero", "He's heading for his lab! He's going to wake the others!"]],
  },
  android_17: {
    before: [["android_17", "Gero's dead. We're free. Now, how about some fun?"], ["piccolo_gero", "These two are nothing like 19 and 20. Careful."]],
    after: [["android_17", "Not bad. You're more interesting than Gero said."]],
  },
  android_18: {
    before: [["android_18", "Don't touch my clothes, and maybe I'll go easy on you."], ["you", "Let's get this over with."]],
    after: [["android_18", "Fine. You win this one. Don't get used to it."]],
  },
  imperfect_cell: {
    before: [["imperfect_cell", "I have the cells of every great fighter... and I am still hungry."], ["trunks_cc", "If he absorbs Androids 17 and 18, he becomes perfect. Stop him here!"]],
    after: [["imperfect_cell", "You haven't won... I only need to find the androids..."], ["trunks_cc", "He escaped. He's going for 17!"]],
  },
  perfect_cell: {
    before: [["perfect_cell", "Welcome to the Cell Games. I am perfect, and I will prove it before the whole world."], ["gohan_games", "My dad told me to fight... I'll stand with you."], ["you", "The world isn't your audience, Cell."]],
    after: [["perfect_cell", "This is... impossible... I am perfect..."], ["gohan_games", "It's over. Dad... we did it."]],
  },
  // ------------------------------------------------------------ Majin Buu Saga
  spopovich: {
    before: [["spopovich", "Babidi's mark gives me strength. You will not leave this ring."], ["supreme_kai", "Babidi controls him. Follow him afterwards, and we will find the wizard."]],
    after: [["supreme_kai", "Quickly. Their ship is hidden nearby, and Babidi is gathering energy for Majin Buu."]],
  },
  pui_pui: {
    before: [["pui_pui", "Welcome to the first floor of Babidi's ship. You won't reach the second."], ["you", "We'll see."]],
    after: [["babidi", "Useless! Yakon, you go!"]],
  },
  yakon: {
    before: [["yakon", "So much light inside you... I will eat it all."], ["supreme_kai", "He feeds on light. Give him more than he can swallow!"]],
    after: [["babidi", "Dabura! Show them the power of the Demon King!"]],
  },
  dabura: {
    before: [["dabura", "I am king of the Demon Realm. My spit turns fighters to stone."], ["supreme_kai", "Don't let it touch you!"], ["you", "Then I won't get close... until I do."]],
    after: [["dabura", "Majin Buu will finish what I started..."], ["babidi", "Ooh, and now I have a better servant in mind... the Saiyan prince!"]],
  },
  majin_vegeta: {
    before: [["majin_vegeta", "I let Babidi into my heart to become the old Vegeta again. Merciless."], ["you", "This isn't you anymore, Vegeta."], ["majin_vegeta", "It's exactly who I am!"]],
    after: [["majin_vegeta", "Bulma... Trunks... take care of them..."], ["supreme_kai", "He sacrificed himself... but Majin Buu has awoken."]],
  },
  fat_buu: {
    before: [["fat_buu", "Buu wants to play! Then Buu turns you into candy!"], ["babidi", "Destroy them, Buu! Destroy everything!"]],
    after: [["fat_buu", "Buu... tired. Buu not want to be bad."], ["supreme_kai", "Something is changing inside him... this isn't over."]],
  },
  super_buu: {
    before: [["super_buu", "I absorbed the strongest. Who is left to stop me?"], ["you", "Me."]],
    after: [["super_buu", "No... my body... something inside is coming loose..."]],
  },
  kid_buu: {
    before: [["kid_buu", "Hehehehe!"], ["goku_kai", "This is Buu's purest form. Pure chaos. Hold him while I gather the Spirit Bomb!"], ["you", "Everyone on Earth, raise your hands!"]],
    after: [["goku_kai", "Majin Buu is gone. Next time, I hope he comes back as a good guy. I'd like to fight him again."]],
  },
  // ------------------------------------------------------------ Dragon Ball Super
  beerus_party: {
    before: [["beerus_party", "You dare spill my pudding? The Earth will pay for that."], ["whis_party", "Oh dear. Lord Beerus, perhaps a game instead of destruction?"], ["you", "If you want a fight, fight me."]],
    after: [["beerus_party", "Hmm. You're amusing. I'll spare this planet... for its food."], ["whis_party", "Lord Beerus is satisfied. How rare."]],
  },
  sorbet: {
    before: [["sorbet", "Frieza's army has returned, and our lord is with us."], ["krillin_gizard", "There's a thousand of them! Stay close!"]],
    after: [["krillin_gizard", "That's the commander down. Now for Frieza..."]],
  },
  tagoma: {
    before: [["tagoma", "Lord Frieza wishes the Earth's fighters dead. I'll gladly oblige."]],
    after: [["golden_frieza", "Pathetic. I suppose I'll have to do it myself."]],
  },
  golden_frieza: {
    before: [["golden_frieza", "Four months of training. Behold: Golden Frieza."], ["krillin_gizard", "He's even stronger than before!"], ["you", "Gold or not, we beat you once."]],
    after: [["golden_frieza", "Curse you... curse all of you!"], ["krillin_gizard", "He's gone. Whis rewound time just in case... too close."]],
  },
  botamo: {
    before: [["champa", "Botamo! Show them Universe 6 is superior!"], ["you", "He's... very round."]],
    after: [["champa", "Botamo! Get up! Ugh."]],
  },
  frost: {
    before: [["frost", "I am a defender of peace in Universe 6. A pleasure."], ["you", "Something about you reminds me of Frieza."]],
    after: [["frost", "A hidden needle wasn't enough... you saw through me."]],
  },
  magetta: {
    before: [["magetta", "..."], ["champa", "Magetta! Melt them! Magma!"]],
    after: [["champa", "Magetta! Don't cry! Ugh, so sensitive."]],
  },
  cabba: {
    before: [["cabba", "Master Vegeta said a Saiyan grows stronger when pushed to the edge. Please, push me!"]],
    after: [["cabba", "Thank you. I learned more from this fight than from years of training."]],
  },
  hit: {
    before: [["hit", "My Time-Skip works for one tenth of a second. That is all I need."], ["champa", "Hit is Universe 6's legendary assassin! You're done!"], ["you", "Then I'll be faster than a tenth of a second."]],
    after: [["hit", "Impressive. You adapted to my technique. Until we meet again."]],
  },
  goku_black: {
    before: [["goku_black", "Rosé. Beautiful, isn't it? A god's power in a mortal's body."], ["trunks_cc", "He's the one who destroyed my future!"], ["you", "We end this here, Black."]],
    after: [["goku_black", "Zamasu... it's time we became one."], ["trunks_cc", "They're merging! Get ready!"]],
  },
  zamasu: {
    before: [["zamasu", "I am justice. I am the world. Bow to me, mortals."], ["trunks_future", "This world is all I have left. I'm not giving it up!"]],
    after: [["zamasu", "A mortal... defeating a god...? No. I am everywhere..."], ["trunks_future", "Zeno has erased this timeline's Zamasu. We have to go back."]],
  },
  toppo: {
    before: [["toppo", "Justice is my strength. And for Universe 11, I will become a God of Destruction."], ["you", "Then show me that justice."]],
    after: [["toppo", "To lose like this... Jiren will finish this."]],
  },
  kefla: {
    before: [["kefla", "Caulifla and Kale, fused with Potara. Twice the Saiyan, twice the power!"], ["you", "I'm not going to hold back."]],
    after: [["kefla", "Out of the ring... that's not fair! Next time!"]],
  },
  jiren: {
    before: [["jiren", "Strength is everything. Trust is a weakness."], ["goku_top", "Fight with everything you've got! We'll be right behind you!"], ["you", "Then I'll show you what trust can do."]],
    after: [["jiren", "...Perhaps I was wrong about trust."], ["goku_top", "Universe 7 survived! Everyone's coming back!"]],
  },
  broly: {
    before: [["broly", "Raaaagh!"], ["cheelai", "He's not evil! Paragus forced him to fight... please, just stop him!"], ["you", "Easy, Broly. I don't want to hurt you."]],
    after: [["broly", "...Thank you."], ["cheelai", "We'll take him somewhere quiet. Somewhere he can just live."]],
  },
  moro_namek: {
    before: [["moro_namek", "Such a lovely planet. I think I'll eat it."], ["merus_namek", "Galactic Patrol! Moro, you are under arrest!"], ["you", "Not here, Moro."]],
    after: [["moro_namek", "My magic... you'll pay for this... I'll be back."], ["merus_namek", "He'll be locked away. For now."]],
  },
  saganbo_earth: {
    before: [["saganbo_earth", "Moro's army doesn't need permission to take this planet."], ["merus_earth", "Defend the city, Patrol!"]],
    after: [["merus_earth", "Good work. But Moro is still out there, and he's gathering power."]],
  },
  moro_earth: {
    before: [["moro_earth", "I've absorbed Seven-Three's abilities and a whole planet's life. Give up."], ["merus_earth", "Remember what I taught you: don't think. Just move."], ["you", "Your magic won't work on me."]],
    after: [["moro_earth", "Impossible... how could I lose?"], ["merus_earth", "Then my job here is done. Goodbye... and keep training."]],
  },
  granolah_cereal: {
    before: [["granolah_cereal", "I gave up my life to become the strongest in the universe. Saiyans will pay for what they did."], ["vegeta_cereal", "He carries a grudge. Understand it, but don't let it crush you."], ["you", "Then let's settle it."]],
    after: [["granolah_cereal", "The truth... wasn't what I thought."], ["vegeta_cereal", "Hmph. Your revenge has the wrong target."]],
  },
  gas_cereal: {
    before: [["gas_cereal", "My wish made me the strongest in the universe. Shall I show you?"], ["vegeta_cereal", "He's burning his own life to fight. Don't let up!"]],
    after: [["gas_cereal", "Strongest... in the universe... was a lie..."], ["vegeta_cereal", "It's over. But I sense... something else coming."]],
  },
  frieza_cereal: {
    before: [["frieza_cereal", "Ten years of training in a time chamber. Meet my newest form."], ["monaito_cereal", "That's... Frieza?"], ["you", "Black this time. Still Frieza."]],
    after: [["frieza_cereal", "Hmph. A little surprise. Next time I'll come fully prepared."]],
  },
  gamma1: {
    before: [["gamma1", "Red Ribbon Army. Gamma 1. I fight as a superhero."], ["piccolo_rr", "They've been lied to. Don't destroy them, just stop them!"]],
    after: [["gamma1", "We were... deceived?"]],
  },
  gamma2: {
    before: [["gamma2", "Gamma 2, the most heroic of them all. Time for my pose!"], ["you", "You're on the wrong side."]],
    after: [["gamma2", "Then let's do one last heroic thing..."], ["piccolo_rr", "Magenta has released Cell Max! Everyone, get ready!"]],
  },
  cell_max: {
    before: [["cell_max", "Grraaaagh!"], ["piccolo_rr", "It's a mindless giant. Its weak spot is on its head!"], ["you", "Big doesn't mean strong."]],
    after: [["piccolo_rr", "It's over. Pan's safe. We... actually did it."]],
  },
};

/** A fallback scene for story bosses without an entry: the boss taunts, you answer; afterwards the boss falls. */
export function genericScene(bossName, kind) {
  return kind === "before"
    ? [["boss", `So, you're the one they sent? I am ${bossName}. Prepare yourself.`], ["you", "Let's go."]]
    : [["boss", "How... how could I lose to you..."]];
}

// player-facing names are the game's own (data/names.js)
renameDeep(BOSS_SCENES);
