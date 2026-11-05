// Godot-only childhood campaign. Applied BEFORE the presentation/map additions so Claude can dress these rows.
export const ORIGINS_IDS = ['k01_emperor_pilav','k02_world_tournament_21','k03_red_ribbon','k04_fortuneteller_baaba','k05_world_tournament_22','k06_king_piccor','k07_piccor_jr'];
const roster = [
 ['goku_kid','Young Gokan','gohan_kid','turtle'],['krillin_kid','Young Krilan','krillin','turtle'],
 ['bulma_young','Young Bulna','bulma','speedster'],['oolong','Ulong','krillin','speedster'],['puar','Puir','chiaotzu','speedster'],
 ['yamcha_young','Young Yamcho','yamcha','speedster'],['ox_king','Ox-Lord','nappa','brawler'],['pilaf','Emperor Pilav','krillin','crane'],
 ['shu','Shoo','yamcha','speedster'],['jackie_chun','Jackie Chung','roshi','turtle'],['giran','Gyran','nappa','brawler'],['nam','Namu','tien','crane'],
 ['silver','Colonel Silvar','yamcha','brawler'],['white','General Whyte','mr_satan','brawler'],['murasaki','Murasake','yamcha','speedster'],
 ['android_8','Cyborg 8','android_16','brawler'],['blue','General Bleu','trunks','crane'],['tao','Mercenary Tau','tien','crane'],
 ['red','Commander Rudd','krillin','brawler'],['baba','Fortuneteller Baaba','roshi','crane'],['grandpa_gohan','Grandpa Gohin','roshi','turtle'],
 ['tien_young','Young Tenzo','tien','crane'],['chiaotzu','Chaozo','krillin','crane'],['tambourine','Tamburin','piccolo','speedster'],
 ['cymbal','Cymbel','piccolo','brawler'],['drum','Drumm','piccolo','brawler'],['king_piccolo','King Piccor','piccolo','brawler'],
 ['korin','Korrin','roshi','speedster'],['yajirobe','Yajirobi','mr_satan','brawler'],['piccolo_jr','Piccor Jr.','piccolo','crane'],
 ['pilav_robot','Pilav Battle Walker','android_16','brawler'],['baaba_fangs','Fangor','yamcha','speedster'],
 ['baaba_invisible','Veilor','yamcha','speedster'],['baaba_mummy','Mummor','nappa','brawler'],['baaba_devil','Devilon','dabura','crane'],
 ['tao_cyborg','Cyborg Tau','tien','crane'],
];
export function applyOrigins(input) {
 const tables = {...input, characters:structuredClone(input.characters), npcs:structuredClone(input.npcs), quests:structuredClone(input.quests),
  narrative:structuredClone(input.narrative), cutscenes:structuredClone(input.cutscenes), rpg:structuredClone(input.rpg), schema:{...input.schema,version:8}};
 for (const [id,name,base,style] of roster) {
  const row=structuredClone(input.characters[base]??input.characters.krillin);
  tables.characters[id]={...row,name,style,origins:true,look:{...row.look,faceSeed:id}};
 }
 const chars=tables.characters;
 for(const id of ['goku_kid','krillin_kid','chiaotzu','pilaf']) chars[id].scale=0.65;
 chars.bulma_young.look.female=true; chars.baba.look.female=true;
 chars.ox_king.scale=1.9; chars.android_8.scale=1.5; chars.king_piccolo.scale=1.4;
 const npcs=tables.npcs, cuts=tables.cutscenes;
 function npc(id,zone,x,z,who=id){const row={id,who,zone,x,z,rot:0,origins:true};npcs.push(row);return row;}
 // Clear approaches, outside building footprints. Each actor has a stable, separate interaction position.
 npc('goku_kid','mt_paozu',-4,-65);npc('bulma_young','mt_paozu',4,-65);
 npc('oolong','mt_paozu',-38,-30);npc('yamcha_young','pilav_castle',-52,-45);npc('puar','pilav_castle',-42,-45);
 npc('ox_king','fire_mountain',-28,-20);npc('origins_roshi','kame_island',-20,0,'roshi');npc('krillin_kid','kame_island',20,0);
 npc('pilaf','pilav_castle',-24,-10);npc('origins_mai','pilav_castle',-10,-10,'mai');npc('shu','pilav_castle',6,-10);
 npc('android_8','muscle_tower',-32,-20);npc('korin','korrin_tower',-12,-30);npc('yajirobe','korrin_tower',12,-30);
 npc('baba','baaba_palace',-35,-30);npc('origins_kamu','kamu_lookout',-20,-12,'kami');npc('origins_popo','kamu_lookout',20,-12,'mr_popo');
 const talk=(id,reply,text)=>({type:'talk',npc:id,text:text??`Speak with ${chars[npcs.find(n=>n.id===id)?.who??id]?.name??id}`,reply});
 const travel=(zone,text)=>({type:'travel',zone,text});
 const reach=(zone,x,z,text)=>({type:'reach',zone,x,z,r:7,text});
 const train=(zone,mode,seconds,text)=>({type:'train',zone,x:0,z:-35,r:55,mode,seconds,text});
 const collect=(zone,item,spots,text)=>({type:'collect',zone,item,spots:spots.map(([x,z])=>({x,z})),text});
 const fight=(enemy,zone,x,z,enemyLevel,text)=>({type:'defeat',enemy,zone,x,z,r:9,count:1,enemyLevel,text});
 const qs=[];
 function chapter(i,title,giver,level,offer,done,steps,xp,zeni,extra={}){
  const q={id:ORIGINS_IDS[i-1],main:true,origins:true,line:'Origins',saga:'Origins',chapter:i,title,giver,level,after:i>1?[ORIGINS_IDS[i-2]]:[],offer,done,steps,
   rewards:{xp,zeni,restore:true,...extra}};qs.push(q);return q;
 }
 chapter(1,'Origins I: Emperor Pilav','goku_kid',1,
  "A girl with a radar is looking for seven Dragon Orbs. Come meet her! Grandpa always said to help people.",
  "Puir cut my tail and the giant ape disappeared. I don't remember it! The others are safe. Let's ask Master Roshu to train us.",[
   talk('bulma_young',"My radar found your grandfather's four-star orb. Keep it with you; help me find the other six!"),
   collect('mt_paozu','origins_ball',[[-26,-48],[28,-24]],'Follow the radar: recover two loose Dragon Orbs'),
   talk('oolong',"All right, you saw through my disguise! Take my orb. I'll come along, but no more monsters!"),
   travel('pilav_castle','Follow the desert road to Pilav country'),
   talk('yamcha_young',"I thought you were easy travellers to rob. You can fight! Puir and I will guide you through the desert."),
   talk('puar',"Our orb is yours if we travel together. The radar points toward Fire Mountain."),
   travel('fire_mountain','Find the burning castle at Fire Mountain'),
   talk('ox_king',"My castle is trapped in flame. Master Roshu is my old teacher. Please find him at Kame House!"),
   travel('kame_island','Ask Master Roshu for help'),
   talk('origins_roshi',"No fan? Then a focused wave will do. Stand back when I visit the mountain!"),
   travel('fire_mountain','Return to the Ox-Lord with Roshu’s promise'),
   reach('fire_mountain',0,-25,'Stand clear and witness Roshu’s wave extinguish the castle fire'),
   talk('ox_king',"That wave put out the fire—and the castle! Here is the orb from my treasury. Pilav took the last one."),
   travel('pilav_castle','Infiltrate Pilav’s Castle'),
   talk('origins_mai',"The emperor has your radar trail. Shoo, seal the courtyard!"),
   talk('shu',"Nobody escapes Pilav's battle walker. Not even a kid with a stick!"),
   fight('pilav_robot','pilav_castle',24,-30,2,'Defeat Pilav’s battle walker'),
   talk('pilaf',"My machine! I still have the last orb. Into the glass prison with you!"),
   collect('pilav_castle','origins_ball',[[30,-5]],'Recover the last orb before Pilav can wish'),
   reach('pilav_castle',38,-42,'Escape the glass prison under the full moon'),
   talk('puar',"Gokan looked at the moon and became a Great Ape! I cut his tail while Yamcho distracted him. He's small again. Everyone is safe."),
   talk('bulma_young',"The orbs have scattered after Ulong spoiled Pilav's wish. This adventure is over, but your training is just beginning.")
  ],100,120,{unlock:['kame_island'],items:{origins_radar:1}});
 chapter(2,'Origins II: The 21st World Tournament','origins_roshi',2,
  'Krilan has come to learn too. Deliver milk, move your feet, and make honest effort before entering the tournament.',
  'A fine final! Jackie Chung showed that there is always someone stronger. Keep training, and travel with a clear heart.',[
   talk('krillin_kid',"A training partner! Let's finish these deliveries before breakfast."),
   collect('kame_island','origins_milk',[[-30,-20],[30,-25],[24,28]],'Deliver three milk bottles around the island'),
   train('kame_island','move',12,'Run the Turtle School delivery circuit (12 s)'),
   reach('kame_island',-25,25,'Find the heavy training rock'),
   train('kame_island','charge',8,'Gather strength to shift the training rock (8 s)'),
   talk('origins_roshi',"The rock moved! We train body and spirit together. Now test your effort in the ring."),
   travel('tournament_island','Enter the 21st World Tournament'),
   reach('tournament_island',0,-35,'Complete the tournament preliminaries at the registration line'),
   fight('giran','tournament_island',-24,0,3,'Win the quarterfinal against Gyran'),
   fight('nam','tournament_island',0,0,3,'Win the semifinal against Namu'),
   fight('jackie_chun','tournament_island',24,0,4,'Face Jackie Chung in the final'),
   travel('kame_island','Return to Kame House after the final'),
   talk('krillin_kid',"Jackie Chung was amazing. We don't have to win every time to grow stronger. Let's keep going!")
  ],600,180);
 chapter(3,'Origins III: The Red Ribbon Army','bulma_young',4,
  'The Red Ribbon Army is taking Dragon Orbs from villages. Follow the radar, protect the people, and stop their commanders.',
  'The army has fallen. Cyborg 8 chose kindness, and Korrin taught patience. Baaba may know where the final orb is hidden.',[
   travel('red_ribbon','Investigate the Red Ribbon patrols'),
   fight('silver','red_ribbon',-38,-30,4,'Defeat Colonel Silvar and free the patrol road'),
   travel('muscle_tower','Rescue the snow village at Muscle Tower'),
   fight('murasaki','muscle_tower',26,-25,4,'See through Murasake’s ninja tricks'),
   talk('android_8',"I won't hurt innocent people. I'll help you rescue the village instead."),
   fight('white','muscle_tower',0,-5,5,'Defeat General Whyte'),
   talk('android_8',"The villagers are free. Being strong should mean protecting them. I'll stay here to help rebuild."),
   travel('red_ribbon','Track General Bleu’s next operation'),
   fight('blue','red_ribbon',0,-25,5,'Defeat General Bleu'),
   travel('korrin_tower','Find the sanctuary beneath Korrin Tower'),
   talk('yajirobe',"Tau passed through here. Don't rush him. The tower's guardian can teach you how to read an opponent."),
   reach('korrin_tower',0,-15,'Reach the foot of Korrin Tower'),
   train('korrin_tower','fly',10,'Climb through the tower approach by flying upward (10 s)'),
   talk('korin',"You chased strength so hard you forgot to watch. Follow the hand, read the breath, and move at the right moment."),
   train('korrin_tower','still',8,'Watch Korrin quietly and learn patience (8 s)'),
   fight('tao','korrin_tower',32,-20,6,'Defeat Mercenary Tau after Korrin’s training'),
   travel('red_ribbon','Storm Red Ribbon headquarters'),
   fight('red','red_ribbon',32,-15,6,'Defeat Commander Rudd and end the Red Ribbon operation'),
   travel('mt_paozu','Bring the recovered radar records to Bulna'),
   talk('goku_kid',"We stopped them! Baaba can find the missing orb, even when the radar can't. Let's visit her palace.")
  ],900,300,{unlock:['baaba_palace']});
 chapter(4,'Origins IV: Fortuneteller Baaba','baba',6,
  'No fortune without a fee! Win against my five fighters, and I shall show you the missing orb.',
  'Your grandfather is proud. Take that memory with you; strength is nothing without the people you protect.',[
   fight('baaba_fangs','baaba_palace',-24,-5,6,'Defeat Fangor, the first of Baaba’s five fighters'),
   fight('baaba_invisible','baaba_palace',0,-10,6,'Read the dust trail and defeat the invisible Veilor'),
   fight('baaba_mummy','baaba_palace',24,-5,6,'Break through Mummor’s heavy guard'),
   fight('baaba_devil','baaba_palace',24,22,7,'Resist Devilon’s tricks and win the fourth bout'),
   fight('grandpa_gohan','baaba_palace',-24,22,7,'Face Baaba’s mysterious masked fifth fighter'),
   talk('grandpa_gohan',"Gokan, it's me. You have good friends now. Never stop learning, and remember that tail can be a weakness."),
   talk('baba',"A reunion is worth more than my fee. I can see the missing orb beyond the old village road."),
   travel('mt_paozu','Follow Baaba’s vision to the mountain village'),
   collect('mt_paozu','origins_keepsake',[[32,15]],'Recover the four-star keepsake from Baaba’s vision'),
   talk('goku_kid',"Grandpa said he was proud of us. I'll keep this orb safe. The next tournament is waiting!")
  ],650,400,{unlock:['tournament_island']});
 chapter(5,'Origins V: The 22nd World Tournament','krillin_kid',7,
  'The Crane School has arrived. Tenzo and Chaozo have tricks we have never seen, and an old enemy is back with a metal body.',
  'The Crane students have chosen their own path. Victory is sweeter when a rival can become a friend.',[
   travel('tournament_island','Register for the 22nd World Tournament'),
   fight('chiaotzu','tournament_island',-24,0,7,'Overcome Chaozo’s Crane School techniques'),
   fight('tao_cyborg','tournament_island',24,0,8,'Stop Cyborg Tau’s revenge in the exhibition bout'),
   fight('tien_young','tournament_island',0,15,8,'Face Tenzo in the tournament final'),
   talk('tien_young',"I won't be an assassin. You fought fairly, even when we didn't. From now on, I choose my own way."),
   travel('kame_island','Tell Roshu what the Crane students decided'),
   talk('origins_roshi',"That choice is worth more than a trophy. Rest now; your next test may not have rules or a referee.")
  ],850,500);
 chapter(6,'Origins VI: King Piccor','origins_roshi',8,
  'Tournament fighters are being hunted. Find the attacker, warn our friends, and stop King Piccor before his army spreads.',
  'King Piccor has fallen, but his final act left an heir. Kamu asks you to train at the Lookout before that day comes.',[
   travel('tournament_island','Return to the tournament grounds and find the attacker'),
   fight('tambourine','tournament_island',30,-25,8,'Stop Tamburin’s attacks on the tournament fighters'),
   travel('korrin_tower','Seek Korrin’s advice against King Piccor'),
   talk('yajirobe',"I met one of his creatures on the road. I'll guard the tower while you speak to Korrin."),
   fight('cymbal','korrin_tower',-32,-10,8,'Defeat Cymbel before he reaches the sanctuary'),
   talk('korin',"The Ultra Divine Water tests your resolve. It is no shortcut. Take only what your heart can endure."),
   collect('korrin_tower','origins_divine_water',[[20,15]],'Find Korrin’s Ultra Divine Water'),
   train('korrin_tower','charge',12,'Steady your Ki after the water’s trial (12 s)'),
   talk('yajirobe',"You're still standing! Take the road to the castle. I'll keep everyone safe behind you."),
   travel('piccor_castle','Confront King Piccor at his castle'),
   fight('drum','piccor_castle',-28,-20,9,'Break through Drumm’s guard'),
   fight('king_piccolo','piccor_castle',24,-15,10,'Defeat King Piccor'),
   travel('korrin_tower','Return to Korrin with news of the victory'),
   talk('korin',"His heir will return. Fly above the tower when you're ready; Kamu and Mr. Pobo will prepare you.")
  ],1050,650,{unlock:['kamu_lookout']});
 chapter(7,'Origins VII: The 23rd World Tournament','origins_kamu',9,
  'Piccor’s heir is training too. Mr. Pobo will teach stillness, movement and control before you return to the tournament.',
  'You have carried the lessons of childhood into a new age. Meet the grown Gokan in the Earth Plains to begin the next story.',[
   talk('origins_popo',"A quiet heart moves without wasted effort. Begin with stillness, then let every step have a purpose."),
   train('kamu_lookout','still',10,'Practise stillness at Kamu’s Lookout (10 s)'),
   train('kamu_lookout','move',12,'Follow Mr. Pobo’s movement drill (12 s)'),
   train('kamu_lookout','charge',10,'Control your breathing and Ki at the Lookout (10 s)'),
   talk('origins_kamu',"You are ready to face him. Win without hatred; the life you save may change the future."),
   travel('tournament_island','Return for the 23rd World Tournament'),
   reach('tournament_island',0,-35,'Pass the final tournament registration'),
   fight('piccolo_jr','tournament_island',0,5,10,'Face Piccor Jr. in the 23rd Tournament final'),
   talk('piccolo_jr',"You won, and you still offered mercy. I won't forget this. Next time, I'll be stronger."),
   travel('earth_plains','Begin the adult journey in the Earth Plains'),
   talk('goku_plains',"Those old adventures taught me why we fight. A new journey is beginning. Come talk to me when you're ready.")
  ],1250,800,{unlock:['earth_plains']});
 // Stage each boss only at its own fight; a defeated boss can remain for a following conversation.
 for(const q of qs) for(const [index,step] of q.steps.entries()) if(step.type==='defeat'){
  const existing=npcs.find(n=>n.id===step.enemy);
  const n=existing??npc(step.enemy,step.zone,step.x,step.z);
  n.boss=true;n.before=q.id;n.afterStep=[q.id,index];
  const name=chars[n.who].name;
  cuts[step.enemy]={before:[['you',step.text+'.'],[step.enemy,`${name} steps forward. Show me what your journey has taught you!`]],
   after:[[step.enemy,'The bout is over. Your resolve was stronger.'],['you','I will carry this lesson into the next battle.']]};
 }
 // Authored opponent beats, resolved through the same saved before/after director as the adult campaign.
 const beats={
  pilav_robot:["Castle defence engaged. The emperor's wish comes first!","The walker is broken. The courtyard gate is open!"],
  giran:["My binding gum will hold you outside the ring!","You broke free? I surrender this match."],
  nam:["My village needs water. I cannot afford to fall here.","You fought with honour. There must be another way to help my village."],
  jackie_chun:["A student's greatest danger is believing there is nothing left to learn.","The final is settled. Let this be the beginning of your training, never the end."],
  silver:["Those orbs belong to Red Ribbon. Hand over the radar!","A whole patrol beaten by travellers? Headquarters won't believe this."],
  murasaki:["Which shadow is real? Catch me before my next trick!","You read every feint. Even my brothers couldn't fool you."],
  white:["This tower belongs to me. Cyborg 8, destroy the intruders!","He refused my order? Then the whole tower has turned against me!"],
  blue:["Don't move. One glance and your muscles belong to me.","You broke my concentration. The radar is beyond my reach."],
  tao:["One finger was enough for my other targets. Will you be different?","The tower changed your timing. You saw the strike before I moved."],
  red:["The army, the towers, the weapons—all for my wish!","Without the troops and the radar, my operation is finished."],
  baaba_fangs:["First bout! Try to catch me before the bell.","Too quick for these wings. The next fighter is waiting."],
  baaba_invisible:["Fight what you cannot see!","The dust gave my footsteps away. Clever."],
  baaba_mummy:["One grip and this bout is over.","You slipped my guard and broke through. I yield."],
  baaba_devil:["Every cruel thought becomes a weakness. Show me your heart!","No malice to turn against you? Then my trick has failed."],
  grandpa_gohan:["A familiar stance. Let us see whether you remember your lessons.","Very good. Come closer, child; I have waited a long time to see you."],
  chiaotzu:["You cannot win if you cannot move.","You found the rhythm between my techniques."],
  tao_cyborg:["A rebuilt body, a hidden blade, and a debt to settle!","Metal cannot repair a fighter's judgment. I rushed the same mistake."],
  tien_young:["The Crane School raised me to win at any cost. Make me prove it.","You trusted the rules when I did not. I choose to be a martial artist."],
  tambourine:["Every name on this tournament list is a target.","The list is lost—but the king already has his next command."],
  cymbal:["The king wants the orbs. No one passes this tower!","The sanctuary is beyond my reach."],
  drum:["You will not take one more step toward the king.","My guard is broken. The castle has no shield left."],
  king_piccolo:["The world will remember fear. Your little rebellion ends here!","My reign ends—but an heir will carry my will."],
  piccolo_jr:["My father's defeat brought me here. Today I settle that legacy.","You could have ended my life. Why spare an enemy? I will find my own answer."],
 };
 for(const [id,[before,after]] of Object.entries(beats)){
  cuts[id].before=[[id,before],['you','I am ready. Let us begin.']];
  cuts[id].after=[[id,after]];
 }
 // The ape is Gokan's story event, never a forced player transformation or race requirement.
 cuts.pilav_robot.after.push(['pilaf','The glass prison will hold you until moonrise.'],['you','We need to recover the last orb and get everyone outside.']);
 tables.quests=[...qs,...tables.quests];
 tables.quests.find(q=>q.id==='m01_arrival').after=[ORIGINS_IDS.at(-1)];
 Object.assign(tables.narrative.item_names,{origins_ball:'childhood Dragon Orb',origins_milk:'milk delivery',origins_keepsake:'four-star keepsake',origins_divine_water:'Ultra Divine Water'});
 tables.origins={first_quest:ORIGINS_IDS[0],last_quest:ORIGINS_IDS.at(-1),start_zone:'mt_paozu',required_flag:'originsRequired',chapters:ORIGINS_IDS,character_ids:roster.map(r=>r[0])};
 Object.assign(tables.rpg.ZONE_LEVELS,{mt_paozu:1,fire_mountain:1,pilav_castle:1,muscle_tower:4,baaba_palace:6,korrin_tower:4,kamu_lookout:9,piccor_castle:8,tournament_island:2});
 return tables;
}
