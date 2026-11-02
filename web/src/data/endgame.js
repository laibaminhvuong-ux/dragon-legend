// Additional manga-era story and shared Saiyan unlocks. All balance values are authored here.
import { FORMS, MASTERY_EVOLUTIONS } from './forms.js';
import { xpForLevels } from '../game/progression.js';
const family=['Saiyan','HalfSaiyan'];
const talk=(npc,text)=>({type:'talk',npc,text});
const train=(zone,seconds,text,mode='charge')=>({type:'train',zone,seconds,text,mode});
const travel=(zone,text)=>({type:'travel',zone,text});
const defeat=(enemy,zone,x,z,text)=>({type:'defeat',enemy,zone,x,z,r:12,count:1,text});
export function installEndgame(npcs,quests,chars,links){
  for(const q of quests){
    q.level=q.id==='m01_arrival'?1:(q.level || 1)*10;
    const id=q.id.replace(/^Form_/,'');
    if(q.id.startsWith('Form_') && FORMS[id]){
      q.level=FORMS[id].unlockLevel;
      if(FORMS[id].legacy)q.legacy=true;
      else if(FORMS[id].races)q.races=[...FORMS[id].races];
    }
  }
  quests.find(q=>q.id==='Form_SSJ2').after.push('Form_SSJFullPower');
  quests.find(q=>q.id==='Form_SSJ3').after.push('Form_SSJ2');
  quests.find(q=>q.id==='Form_SSJGod').after.push('Form_SSJ3');
  const kai=quests.find(q=>q.id==='Form_Kaioken');kai.offer='Kaioken is a technique for humans and Saiyans alike. Train your body to withstand the strain.';
  const beast=quests.find(q=>q.id==='Form_Beast');Object.assign(beast,{giver:'gohan_endgame',level:2000,races:family,path:'beast',after:['m32_tournament','Form_SSJBlue']});
  beast.steps=[train('beerus_planet',60,'Release your potential under Gohan’s guidance')];
  quests.find(q=>q.id==='Form_SSJRage').automatic=true;
  const clone=(key,base,name,overrides={})=>chars[key]={...chars[base],name,...overrides};
  clone('merus','whis','Merus');clone('moro','dabura','Moro');clone('saganbo','nappa','Saganbo');
  clone('granolah','trunks','Granolah');clone('monaito','kami','Monaito');clone('gas','hit','Gas');
  clone('black_frieza','frieza','Black Frieza');
  const addNpc=(id,who,zone,x,z,extra={})=>npcs.push({id,who,zone,x,z,...extra});
  addNpc('merus_namek','merus','new_namek',-8,-15);
  addNpc('moro_namek','moro','new_namek',40,25,{boss:true,before:'m35_moro_escape'});
  addNpc('merus_earth','merus','earth_plains',-18,8,{after:'m35_moro_escape'});
  addNpc('saganbo_earth','saganbo','earth_plains',60,20,{boss:true,after:'m35_moro_escape',before:'m36_patrol_defence'});
  addNpc('moro_earth','moro','earth_plains',70,50,{boss:true,after:'m36_patrol_defence',before:'m37_moro_final'});
  addNpc('gohan_endgame','gohan','beerus_planet',-10,-12);
  addNpc('vegeta_cereal','vegeta','planet_cereal',-10,-18);
  addNpc('monaito_cereal','monaito','planet_cereal',-5,-12);
  addNpc('granolah_cereal','granolah','planet_cereal',40,20,{boss:true,before:'m38_granolah'});
  addNpc('gas_cereal','gas','planet_cereal',55,35,{boss:true,after:'m39_bardock',before:'m40_gas'});
  addNpc('frieza_cereal','black_frieza','planet_cereal',40,55,{boss:true,after:'m40_gas',before:'m41_black_frieza'});
  addNpc('jiren_training','jiren','world_of_void',0,25,{boss:true,after:'m32_tournament'});
  links.new_namek=['namek','west_city','beerus_planet'];
  links.planet_cereal=['beerus_planet','west_city'];
  for(const id of ['namek','west_city','beerus_planet'])links[id].push('new_namek');
  for(const id of ['west_city','beerus_planet'])links[id].push('planet_cereal');
  const main=(id,title,giver,level,after,steps,rewards,saga)=>({id,title,giver,level,after:[after],steps,rewards,saga,main:true,
    offer:`${title}. Follow the objective and help the others stop this threat.`,done:`${title} complete. Prepare for the next stage.`});
  const moro='Galactic Patrol Prisoner Saga',cereal='Granolah the Survivor Saga';
  const chapters=[
    main('m35_moro_escape','Moro: The Escaped Prisoner','merus_namek',850,'m33_broly',[travel('new_namek','Travel with the Galactic Patrol to New Namek'),defeat('moro_namek','new_namek',40,25,'Drive Moro away from New Namek')],{unlock:['earth_plains'],zeni:80000},moro),
    main('m36_patrol_defence','Defend Earth with the Galactic Patrol','merus_earth',950,'m35_moro_escape',[defeat('saganbo_earth','earth_plains',60,20,'Defeat the empowered Saganbo'),train('earth_plains',35,'Refine your calm under Merus','still')],{zeni:100000},moro),
    main('m37_moro_final','Moro: Perfected Resolve','merus_earth',1100,'m36_patrol_defence',[defeat('moro_earth','earth_plains',70,50,'Stop Moro after his copied angel power'),train('earth_plains',30,'Focus your energy to finish the battle')],{unlock:['planet_cereal'],zeni:150000},moro),
    main('m38_granolah','Granolah: The Survivor','vegeta_cereal',1250,'m37_moro_final',[travel('planet_cereal','Reach Planet Cereal'),defeat('granolah_cereal','planet_cereal',40,20,'Face Granolah and his precision attacks'),talk('monaito_cereal','Hear Monaito’s account of the past')],{zeni:175000},cereal),
    main('m39_bardock','Bardock’s Resolve','monaito_cereal',1400,'m38_granolah',[talk('monaito_cereal','Learn how Bardock protected the survivors'),train('planet_cereal',30,'Accept your own fighting spirit','still')],{zeni:180000},cereal),
    main('m40_gas','Gas: The Strongest Wish','vegeta_cereal',1600,'m39_bardock',[defeat('gas_cereal','planet_cereal',55,35,'Overcome Gas with your allies')],{zeni:225000},cereal),
    main('m41_black_frieza','The Arrival of Black Frieza','monaito_cereal',1800,'m40_gas',[defeat('frieza_cereal','planet_cereal',40,55,'Survive Black Frieza’s overwhelming power'),talk('monaito_cereal','Recover and prepare for what comes next')],{unlock:['red_ribbon'],zeni:300000},cereal),
  ];
  const broly=quests.find(q=>q.id==='m33_broly');broly.rewards.unlock=['new_namek'];
  const hero=quests.find(q=>q.id==='m34_super_hero');hero.after=['m41_black_frieza'];hero.level=1900;
  quests.splice(quests.indexOf(hero),0,...chapters);
  const unlock=(id,giver,after,zone,offer,path=null)=>({id:`Form_${id}`,title:FORMS[id].name,giver,level:FORMS[id].unlockLevel,races:family,saga:'Transformations',after,
    offer,done:`Unlocked ${FORMS[id].name}.`,steps:[train(zone,45,`Train to unlock ${FORMS[id].name}`)],rewards:{forms:[id]},...(path?{path}: {})});
  quests.push(unlock('Oozaru','king_kai',['m04_kaioken'],'king_kai','Learn to control the Great Ape power in your Saiyan heritage.'));
  quests.push(unlock('FalseSSJ','goku_kingkai',['m04_kaioken'],'king_kai','Push toward the Super Saiyan threshold.'));
  quests.push(unlock('LegendarySSJ','broly_after',['m33_broly','Form_SSJFullPower'],'broly_glacier','Train with Broly to contain the Legendary Super Saiyan’s overflowing power.'));
  for(const edge of MASTERY_EVOLUTIONS){
    let q=quests.find(q=>q.id===`Form_${edge.to}`);
    if(!q){q=unlock(edge.to,'king_kai',[], 'king_kai','This form evolves automatically through mastery.');quests.push(q);}
    Object.assign(q,{automatic:true,level:FORMS[edge.to].unlockLevel,races:family,after:[`Form_${edge.from}`,...(edge.after?[edge.after]:[])]});
  }
  quests.push(unlock('UIOmen','whis',['m32_tournament','Form_SSJBlue'],'world_of_void','Revisit the Tournament of Power breakthrough: separate the transformation from the weaker focus technique.','instinct'));
  quests.push(unlock('UIPerfected','whis',['Form_UIOmen'],'world_of_void','Quiet your mind and complete the silver-haired transformation.','instinct'));
  quests.push({id:'t_ui_moro_mastery',title:'Merus: Ultra Instinct Mastery',giver:'merus_earth',level:2000,races:family,path:'instinct',saga:moro,after:['Form_UIPerfected','m37_moro_final'],
    offer:'Merus teaches you to sustain perfected Ultra Instinct after the Moro battle.',done:'Your control is stable. Mastery reduces the form’s ki drain.',steps:[train('earth_plains',60,'Perfect your control under Merus','still')],rewards:{items:{instinctMastery:1}}});
  quests.push(unlock('UITrue','monaito_cereal',['t_ui_moro_mastery','m40_gas'],'planet_cereal','Find your own emotional, black-haired Ultra Instinct while facing the legacy of the Gas battle.','instinct'));
  quests.push(unlock('UltraEgo','beerus',['m38_granolah','Form_SSJBlue'],'beerus_planet','Train in Destruction with Beerus and follow Vegeta’s Ultra Ego path.','ego'));
}
export function rebalanceQuestRewards(quests){
  for(const q of quests){
    q.rewards ||= {};
    if(q.legacy || q.automatic)continue;
    if(typeof q.rewards.xp==='string')q.rewards.xp='levels:5';
    else q.rewards.xp=xpForLevels(q.level || 1,q.main?10:q.repeat?5:q.id.startsWith('Form_')?6:4);
  }
}
