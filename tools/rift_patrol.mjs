// Original post-game campaign; authored before Godot presentation additions.
export function applyRiftPatrol(input){
 const t={...input,characters:structuredClone(input.characters),zones:structuredClone(input.zones),zone_order:[...input.zone_order],schema:{...input.schema,version:9}};
 const villains=[['vael','Vael the Unwound','hit','speedster'],['shardling','Shardling','kid_buu','speedster'],['morrigath','Warden Morrigath','android_16','brawler'],['nyxara','Empress Nyxara','android_18','crane'],['hollow_gokan','Hollow Gokan','goku','turtle'],['hollow_vegara','Hollow Vegara','vegeta','brawler'],['hollow_piccor','Hollow Piccor','piccolo','crane'],['zero_origin','Zero-Origin','jiren','brawler'],['archivist_tem','Archivist Tem','whis','crane']];
 for(const [id,name,base,style]of villains)t.characters[id]={...structuredClone(input.characters[base]),name,style,rift:true,look:{...structuredClone(input.characters[base].look),faceSeed:id}};
 // Bootstrap maps use existing builders; Claude's additions pass replaces the Nexus presentation.
 for(const [id,name,planet]of [['time_nexus','Time Nexus','Time Nexus'],['echo_prison','Echo Prison','Echo Prison']]){
  t.zones[id]={...structuredClone(input.zones.cell_games),name,planet,saga:'Rift Patrol',kind:'rift',terrain:{size:400,hills:{amp:0,scale:100},flatSpawn:190,spawn:{x:0,z:-60}},landmarks:[{type:'cellarena',x:0,z:20,name,flatten:65}],travelPoint:{x:30,z:-60}};
  t.zone_order.push(id);
 }
 const missions=[];const cards={};
 const effectList=[{ki_regen:.02},{damage:.02},{health:.02},{ally_health:.03}];
 const add=(id,arc,name,zone,enemies,allies,protect=false)=>{
  const index=missions.length;const card=id+'_hero', rare=id+'_prismatic';
  const hero=allies[0];
  cards[card]={id:card,name:t.characters[hero].name+' · '+name,character:hero,rarity:'rare',effect:effectList[index%4]};
  cards[rare]={id:rare,name:name+' · Prismatic',character:enemies.at(-1),rarity:'legendary',effect:{cosmetic:'rift_prismatic'}};
  const waves=[{spawns:Array.from({length:4},(_,i)=>({character:'shardling',x:-18+i*12,z:-15,level:2000,healthScale:.45,damageScale:.55}))},
   {spawns:enemies.map((character,i)=>({character,x:(i-(enemies.length-1)/2)*16,z:10,level:2000,healthScale:character==='zero_origin'?3:1.5,damageScale:.85,boss:true,phases:[{at:1,name:'Breach',damage:1,speed:1},{at:.66,name:'Fracture',damage:1.2,speed:1.1},{at:.33,name:'Collapse',damage:1.4,speed:1.2}]}))}];
  missions.push({id,arc,name,zone,level:2000,after:index?[missions[index-1].id]:[],corrupted:true,arena:name,spawn:{x:0,z:-50},waves,
   allies:allies.map((character,i)=>({character,id:'rift_ally_'+i,x:-8+i*16,z:-42,health:32000,damage:1800,cooldown:1.1,protect:protect&&i===0})),
   objectives:[{type:'defeat',text:'Defeat the corrupted patrol',count:4},{type:'defeat',text:'Defeat '+enemies.map(c=>t.characters[c].name).join(' and '),count:enemies.length},...(protect?[{type:'protect',text:'Keep '+t.characters[hero].name+' standing',ally:'rift_ally_0'}]:[])],
   stars:{time:240,no_ally_down:true},rewards:{xp:500000,zeni:15000,first_zeni:35000,card,three_star_card:rare}});
 };
 add('rp01_dark_crystal',1,'A Crystal at the Landing','earth_plains',['raditz'],['goku','piccolo']);
 add('rp02_shattered_landing',1,'The Shattered Landing','gizard_wasteland',['nappa','vegeta'],['goku']);
 add('rp03_nameck_storm',1,'Storm over Nameck','namek',['zarbon','dodoria'],['gohan','krillin'],true);
 add('rp04_shard_emperor',1,'The Shard Emperor','namek',['frieza'],['goku','vegeta']);
 add('rp05_vael',1,'Vael’s Stolen Hour','yardrat',['vael'],['goku']);
 add('rp06_echo_breakout',2,'Breakout from Echo Prison','echo_prison',['hollow_piccor'],['trunks','piccolo'],true);
 add('rp07_cyborg_riot',2,'Cyborg Riot','echo_prison',['android_17','android_18'],['android_16']);
 add('rp08_prison_tournament',2,'The Prison-Yard Tournament','echo_prison',['hollow_gokan','hollow_vegara'],['gohan','vegeta']);
 add('rp09_morrigath',2,'Morrigath’s Last Chain','echo_prison',['morrigath'],['goku','trunks'],true);
 add('rp10_hollow_games',3,'The Hollow Games','cell_games',['hollow_gokan','hollow_piccor'],['gohan']);
 add('rp11_crown_rampage',3,'The Crown’s Rampage','papaya_island',['hollow_vegara','fat_buu'],['goku','vegeta'],true);
 add('rp12_arena_of_night',3,'Arena of Night','world_of_void',['hollow_gokan','hollow_vegara','hollow_piccor'],['goku','jiren']);
 add('rp13_nyxara',3,'The Obsidian Crown','kai_world',['nyxara'],['vegeta','piccolo']);
 add('rp14_remnants',4,'Remnants of the Unwound','time_nexus',['vael','morrigath','nyxara'],['goku','vegeta'],true);
 add('rp15_zero_origin',4,'The End of Time','time_nexus',['zero_origin'],['goku','piccolo']);
 t.rift_missions={unlock_quest:input.quests.filter(q=>q.main&&!q.origins).at(-1).id,hub:'time_nexus',arcs:[{id:1,name:'The Fractured Timeline'},{id:2,name:'Prison of Echoes'},{id:3,name:'The Dark Crown War'},{id:4,name:'The End of Time'}],missions};
 t.hero_cards=cards;
 return t;
}
