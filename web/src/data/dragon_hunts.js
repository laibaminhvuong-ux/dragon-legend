import { renameDeep } from './names.js';

// Gameplay-scale summons and retrieval projections; geometry is authored in wish_dragon.js.
export const DRAGON_LOOKS={
  earth:{body:0x299453,belly:0xe8cb87,horns:0xe6c59b,eyes:0xed3333,kind:'serpent'},
  namek:{body:0x37864b,belly:0xe6d9aa,horns:0xf4ecd8,eyes:0xe63535,kind:'muscular'},
  super:{body:0xeab731,belly:0xffe6a0,horns:0xffe6a0,eyes:0xc51d27,kind:'winged'},
  cereal:{body:0xa69062,belly:0xf1ddba,horns:0xe4c592,eyes:0xdb333c,kind:'finned'},
};
export const ORB_LOOKS={
  dragon_ball:{scale:1,color:0xff8a20},namek_ball:{scale:2.2,color:0xff8a20},
  super_ball:{scale:4,color:0xffce49,projection:true},cereal_ball:{scale:.55,color:0xffb45e},
};
export const DRAGON_HUNTS=[
  {id:'s_namek_dragon',dragon:'namek',who:'porunga',name:'Porunga',item:'namek_ball',giver:'dende',level:160,after:['m13_frieza'],zone:'namek',x:20,z:25,scale:5,
    title:'Seven Orbs of Namek',saga:'Namek',wishes:3,statPoints:20,zeni:15000,
    spots:[{x:22,z:-20},{x:175,z:100},{x:-185,z:65},{x:50,z:-200},{x:-120,z:-165},{x:235,z:-140},{x:-35,z:240}],
    offer:'Seven Namekian Dragon Balls, seven islands. Find the full set and Dende will help you summon Porunga for three wishes.',
    wishLines:['Ask Porunga to restore your strength','Ask Porunga for training potential','Ask Porunga for prosperity']},
  {id:'s_super_dragon',dragon:'super',who:'super_shenron',name:'Super Shenron',item:'super_ball',giver:'vados',level:650,after:['m29_u6'],zone:'nameless_planet',x:0,z:92,scale:8,
    title:'Super Dragon Orbs: The Golden Dragon',saga:'Universe Tournament',wishes:1,statPoints:50,zeni:100000,
    spots:[{zone:'beerus_planet',x:-35,z:-25},{zone:'beerus_planet',x:45,z:-15},{zone:'beerus_planet',x:-25,z:40},
      {zone:'nameless_planet',x:-80,z:-35},{zone:'nameless_planet',x:80,z:-35},{zone:'nameless_planet',x:-70,z:65},{zone:'nameless_planet',x:70,z:65}],
    offer:'The Super Dragon Balls are planet-sized. Survey seven cosmic retrieval beacons across the divine and tournament worlds; we will assemble the real orbs in space and call the golden Super Shenron. This hunt opens after the Universe 6 tournament.',
    wishLines:['Ask the golden Super Shenron to restore your strength and expand your potential']},
  {id:'s_cereal_dragon',dragon:'cereal',who:'toronbo',name:'Toronbo',item:'cereal_ball',giver:'monaito_cereal',level:1400,after:['m38_granolah'],zone:'planet_cereal',x:-28,z:18,scale:4,
    title:'Cereal: The Two Dragon Orbs',saga:'Granolah the Survivor Saga',wishes:1,statPoints:35,zeni:50000,
    spots:[{x:-45,z:-30},{x:75,z:65}],
    offer:'These are the two small Cerealian Dragon Balls used in the wishes that empowered Granolah and Gas. Recover both and I will help you call Toronbo. Ask for your own potential, rather than trading away your life.',
    wishLines:['Ask Toronbo to unlock training potential without sacrificing your lifespan']},
];
export function installDragonHunts(npcs,quests,characters){
  characters.shenron.dragon='earth';
  const earth=quests.find(q=>q.id==='s_dragon_radar');earth.dragonHunt='earth';earth.steps[0].summonFlag='shenron';
  // Old saves keep their completed Earth quest and flag. A fulfilled summon no longer stays forever.
  npcs.find(n=>n.id==='shenron').before=earth.id;
  npcs.find(n=>n.id==='shenron').afterStep=[earth.id,1];
  for(const hunt of DRAGON_HUNTS){
    const npcId='dragon_'+hunt.dragon,flag='summon_'+hunt.dragon;
    characters[hunt.who]={...characters.shenron,name:hunt.name,dragon:hunt.dragon,scale:hunt.scale};
    npcs.push({id:npcId,who:hunt.who,zone:hunt.zone,x:hunt.x,z:hunt.z,flagged:flag,before:hunt.id,afterStep:[hunt.id,1]});
    quests.push({id:hunt.id,title:hunt.title,saga:hunt.saga,giver:hunt.giver,level:hunt.level,after:hunt.after,dragonHunt:hunt.dragon,
      offer:hunt.offer,done:`Your ${hunt.wishes===3?'three wishes are':'wish is'} granted. Your strength is restored and your training potential grows.`,
      steps:[{type:'collect',item:hunt.item,zone:hunt.item==='super_ball'?null:hunt.zone,spots:hunt.spots,summonFlag:flag,text:hunt.item==='super_ball'?'Survey all 7 Super Dragon Orb retrieval beacons':`Gather all ${hunt.spots.length} ${hunt.name} Dragon Orbs`},
        ...hunt.wishLines.map((text,i)=>({type:'talk',npc:npcId,text,reply:`Wish ${i+1} of ${hunt.wishes}: it shall be granted.`}))],
      rewards:{statPoints:hunt.statPoints,zeni:hunt.zeni,restore:true}});
  }
}
renameDeep(DRAGON_HUNTS);
