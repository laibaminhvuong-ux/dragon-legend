import { createAppearancePreview } from "./appearancePreview.js";
import { RACES } from '../data/races.js';
import { FACES, BUILDS, HAIR_COLORS, KI_COLORS, KI_COLOR_NAMES, TINTS } from '../data/appearance.js';
import { ACCESSORIES, accessoryAvailable } from '../data/accessories.js';
import { FORM_PATHS, formAvailable, hasFormPath } from '../game/forms.js';
import { masteryProgress } from '../game/mastery.js';
import { MAX_LEVEL, POINTS_PER_LEVEL } from '../data/stats.js';
import { derive, points } from '../game/progression.js';
// Interaction, dialogue and the action-RPG quest/combat overlay. Commands go to game/story APIs.
import { h, btn } from './dom.js';
import { MOVES } from '../data/moves.js';
import { OUTFITS } from '../data/outfits.js';
import { FORMS } from '../data/forms.js';
import { KAIOKEN } from '../data/kaioken.js';
import { kiColourInput } from './kiColourInput.js';

const displayCode = code => (code || '').replace(/^Key/, '').replace(/^Digit/, '').replace('Mouse0','LMB').replace('Mouse2','RMB').replace('ControlLeft','Ctrl').replace(/^Pad/, 'Pad ');
export function rpg(app) {
  let root, prompt, questList, next, target, actions, modal, controls, progress, death, journal;
  let offs=[], stamp='', questStamp='', timer=0, isOpen=false, preview=null;
  const key = action => displayCode(app.input.bindings()[action]?.[0] || action);
  function close() {
    if (!modal) return;
    preview?.dispose();preview=null;
    modal.hidden=true; modal.replaceChildren();isOpen=false;app.dialogueOpen=false;app.voice?.stop();
    app.input.pointerLockWanted=!app.paused;
  }
  function open(speaker, text) {
    isOpen=true;app.dialogueOpen=true;app.input.pointerLockWanted=false;
    document.exitPointerLock?.();
    preview?.dispose();preview=null;
    modal.replaceChildren();modal.hidden=false;
    modal.append(h('h2','',speaker),h('p','',text));
  }
  function dialogue(d) {
    open(d.speaker,d.text);
    app.voice?.say(d.speaker,d.text);
    if(d.kind==='choice') {
      for(const q of d.choices || []) {
        const card=h('section','rpg-offer');
        card.append(h('h3','',`${q.title} · Lv. ${q.level}`),h('p','',q.text),h('p','rpg-muted',q.objective));
        const r=q.rewards || {};
        const rewards=[r.xp?`${r.xp} XP`:null,r.zeni?`${r.zeni} zeni`:null,r.statPoints?`${r.statPoints} stat points`:null,r.restore?'Health and Ki restored':null,...(r.moves || []).map(id=>MOVES[id]?.name || id),...(r.forms || []).map(id=>FORMS[id]?.name || id)].filter(Boolean);
        card.append(h('p','rpg-reward',rewards.join(' · ') || 'Training progress'));
        card.append(btn('Accept quest',()=> {
          if(app.story.acceptQuest(q.id)){app.saveNow();close();stamp='';}
          else {close();app.events.emit('notify',{text:'Move closer to the quest giver and try again.'});}
        },'primary'));
        modal.append(card);
      }
    }
    if(d.kind==='travel') {
      // the travel guide: where the story goes next first, then any world the story has opened
      const list=h('div','rpg-travel');
      for(const o of d.options || []) {
        const b=btn(o.story?`★ ${o.name} · next in the story`:`${o.name} · ${o.planet}`,()=>{
          if(app.story.travelTo(o.zone)){close();}
          else {close();app.events.emit('notify',{text:'Stand next to the pilot and try again.'});}
        },o.story?'primary':'');
        list.append(b);
      }
      modal.append(list);
    }
    if(d.speaker==='Training Guide')modal.append(btn('Shop',showShop));
    modal.append(btn(d.kind==='choice' || d.kind==='travel'?'Not now':'Continue',close));
    modal.querySelector('button')?.focus();
  }
  function showShop() {
    open('Training Guide shop',`You have ${app.game.hud().zeni} zeni. Earn more from patrols and story quests.`);
    for(const item of app.story.shop()){
      const card=h('section','rpg-offer');card.append(h('h3','',`${item.name} · ${item.price} zeni`),h('p','',item.description));
      const buy=btn(item.owned?'Owned':'Buy',()=>{
        const err=app.story.buy(item.id);
        if(err)app.events.emit('notify',{text:err});else {app.saveNow();showShop();}
      });buy.disabled=!!item.owned;card.append(buy);modal.append(card);
    }
    modal.append(btn('Continue',close));
  }
  const tabNames=['Character','Accessories','Stats','Forms','Techniques'];
  function tell(error){if(error)app.events.emit('notify',{text:error});else app.saveNow();}
  function picker(label,options,value,command){
    const wrap=h('label');wrap.append(h('p','',label));const select=h('select');select.setAttribute('aria-label',label);
    for(const [id,name] of options){const option=h('option','',name);option.value=String(id);option.selected=String(id)===String(value);select.append(option);}
    select.onchange=()=>command(select.value);wrap.append(select);return wrap;
  }
  function showJournal(){showTab('Stats');}
  function showTab(tab){
    const slot=app.game.slot,race=RACES[slot.race];
    open(`Fighter · ${tab}`,`Level ${slot.level} / ${MAX_LEVEL} · ${race.name}`);
    const nav=h('nav','rpg-stat-buttons');nav.setAttribute('aria-label','Character menu tabs');
    for(const name of tabNames)nav.append(btn(name,()=>showTab(name),name===tab?'primary':''));modal.append(nav);
    if(tab==='Character' || tab==='Accessories')preview=createAppearancePreview(modal,app);
    if(tab==='Forms' || tab==='Techniques'){
      const kai=app.game.kaioken.snapshot(),ranks=app.game.kaioken.ranks();
      modal.append(h('h3','','Kaiyoken overlay'),h('p','rpg-muted',`Keep your Saiyan form and equipped attack. Toggle with ${key('kaioken')}, gamepad D-pad left, the touch KAIO button, or here. x2: ${KAIOKEN.tiers[2].duration} seconds; x10: ${KAIOKEN.tiers[10].duration} seconds. Extra Ki and health drain; ${KAIOKEN.cooldown}-second cooldown after stopping. Ends at ${KAIOKEN.minHealth*100}% health.`));
      if(ranks.length){
        modal.append(picker('Kaiyoken intensity',ranks.map(rank=>[rank,`x${rank}`]),slot.loadout.kaiokenRank || 2,v=>{tell(app.game.kaioken.select(Number(v)));showTab(tab);}));
        modal.append(btn(kai.active?'Stop Kaiyoken':'Activate Kaiyoken',()=>{tell(app.game.kaioken.toggle());showTab(tab);}));
      }else modal.append(h('p','rpg-muted','Learn Kaiyoken through King Kae training. Complete the x10 form training to unlock its intensity.'));
    }
    if(tab==='Character'){
      const apply=(key,value)=>tell(app.game.customizeAppearance({[key]:value}));
      const palettes=(values)=>values.map((c,i)=>[i,`#${c.toString(16).padStart(6,'0')}`]);
      for(const [label,key,options,numeric] of [
        ['Build','build',BUILDS.map(x=>[x.id,x.name]),false],
        ['Face','face',FACES.map(x=>[x.id,x.name]),false],
        ['Hair','hair',race.hairStyles.map(id=>[id,id]),false],
        ['Skin color','skin',palettes(race.skins),true],
        ['Hair color','hairColor',palettes(HAIR_COLORS),true],
        ['Outfit tint','outfitTint',palettes(TINTS),true],
      ])modal.append(picker(label,options,slot.appearance[key],v=>apply(key,numeric?Number(v):v)));
      modal.append(picker('Ki colour',[["custom","Custom hex"],...KI_COLORS.map((c,i)=>[i,KI_COLOR_NAMES[i]])],slot.appearance.kiColorHex?'custom':slot.appearance.kiColor,v=>{
        if(v==='custom')return;
        tell(app.game.customizeAppearance({kiColor:Number(v),kiColorHex:null}));showTab('Character');
      }));
      modal.append(kiColourInput(slot.appearance,(value,phase)=>{const error=app.game.customizeAppearance({kiColorHex:value});if(!error && !phase?.preview){app.saveNow();showTab('Character');}return error;}));
      modal.append(picker('Outfit',slot.outfits.map(id=>[id,OUTFITS[id]?.name || id]),slot.appearance.outfit,v=>tell(app.game.equipOutfit(v)?null:'That outfit is unavailable.')));
      modal.append(h('p','rpg-muted','Ki colour changes your charging aura, blasts and beams. Transformation auras keep their form colours. The preview shows your charging aura.'));
    }else if(tab==='Accessories'){
      for(const [id,item] of Object.entries(ACCESSORIES)){
        const available=accessoryAvailable(slot,id),card=h('section','rpg-offer');card.append(h('h3','',item.name));
        const equip=btn(slot.loadout.accessory===id?'Equipped':'Equip',()=>{tell(app.game.equipAccessory(id));showTab(tab);});equip.disabled=!available || slot.loadout.accessory===id;card.append(equip);
        if(!available)card.append(h('p','rpg-muted',`Unlock quest: ${item.after}`));modal.append(card);
      }
    }else if(tab==='Stats'){
      // Stats: points in each (race bonus included), what they give now, and +1 / +10 / +100 / all-in buttons.
      const d=derive(slot),pct=x=>`+${Math.round((x-1)*100)}%`;
      const STAT_ROWS=[['Health','Health',`${d.maxHealth} max health`],['Ki','Ki',`${d.maxKi} max ki`],['Strength','Strength',`${pct(d.strength)} melee damage`],
        ['KiPower','Ki Power',`${pct(d.kiPower)} ki attack damage`],['Speed','Speed',`${d.runSpeed.toFixed(1)} run speed`]];
      modal.append(h('h3','',`Stats · ${slot.statPoints} unspent point${slot.statPoints===1?'':'s'} · Power level ${d.powerLevel.toLocaleString()}`));
      const table=h('div','rpg-stats');
      modal.append(h('p','rpg-muted',`Earn ${POINTS_PER_LEVEL} stat points every level. Health and Ki raise your pools; Strength and Ki Power raise damage; Speed raises run speed.`));
      for(const [stat,label,effect] of STAT_ROWS){
        const row=h('div','rpg-stat-row');
        row.append(h('span','rpg-stat-name',label),h('span','rpg-stat-points',String(points(slot,stat))),h('span','rpg-stat-effect',effect));
        for(const n of [1,10,100]){
          const b=btn(`+${n}`,()=>{tell(app.game.spendStatPoint(stat,n));showTab(tab);});
          b.setAttribute('aria-label',n===1?`+ ${stat}`:`Add ${n} to ${label}`);b.disabled=slot.statPoints<n;row.append(b);
        }
        const all=btn('All',()=>{tell(app.game.spendStatPoint(stat,slot.statPoints));showTab(tab);});
        all.setAttribute('aria-label',`Put all points in ${label}`);all.disabled=slot.statPoints<1;row.append(all);
        table.append(row);
      }
      modal.append(table);
      modal.append(h('h3','','Skills'));
      for(const id of app.story.journal().moves)modal.append(h('p','rpg-muted',`${MOVES[id]?.name || id}: ${MOVES[id]?.desc || ''}`));
      modal.append(btn(`Use Recovery Capsule (${app.story.journal().items.capsule || 0})`,()=>{if(app.story.useItem('capsule')){app.saveNow();showTab(tab);}else tell('A capsule requires missing health or ki.');}));
      if(app.story.interaction()?.id.startsWith('guide_'))modal.append(btn('Guide shop',showShop));
    }else if(tab==='Techniques'){
      modal.append(h('p','','Select a learned technique, then hold/release its skill action. The learnable UI Sign technique has no form stat multiplier and a much smaller dodge benefit.'));
      modal.append(h('p','rpg-muted',MOVES[app.game.combat.snapshot().technique]?.desc || 'Starter Energy Wave.'));
      modal.append(picker('Equipped technique',app.game.combat.availableTechniques().map(id=>[id,id==='EnergyWave'?'Energy Wave (starter)':MOVES[id].name]),app.game.combat.snapshot().technique,id=>{app.game.combat.setTechnique(id);app.saveNow();showTab('Techniques');}));
    }else if(tab==='Forms'){
      if(['Saiyan','HalfSaiyan'].includes(slot.race)){
        modal.append(h('h3','',`Level ${MAX_LEVEL} path · ${FORM_PATHS[slot.loadout.formPath]?.name || (slot.loadout.testAllPaths===true?'All three (test save)':'Not chosen')}`),h('p','','Choose one endgame path for this character. Other paths remain locked.'));
        for(const [path,info]of Object.entries(FORM_PATHS)){
          const choose=btn(info.name,()=>{tell(app.game.chooseFormPath(path));showTab(tab);});choose.disabled=slot.level<MAX_LEVEL || !!slot.loadout.formPath;modal.append(choose);
        }
      }
      modal.append(btn('Return to Base',()=>{tell(app.game.selectForm(''));showTab('Forms');}));
      for(const id of race.forms){
        const form=FORMS[id],mastery=masteryProgress(slot,id),owned=slot.forms.includes(id),card=h('section','rpg-offer');
        card.append(h('h3','',form.name),h('p','rpg-muted',`Lv. ${form.unlockLevel} · ${form.multiplier}× stats · ${form.kiDrain} base ki/s`));
        if(form.mastery)card.append(h('p','',`Requires ${FORMS[form.mastery.from].name} Mastery Lv. ${form.mastery.required/10}: ${Math.floor(slot.formMastery?.[form.mastery.key] || 0)} / ${form.mastery.required} points${form.mastery.after?' · story prerequisite required':''}`));
        if(owned)card.append(h('p','',`Mastery Lv. ${mastery.level} · ${Math.floor(mastery.points)} points${mastery.next?` · Next: ${FORMS[mastery.next].name} at Mastery Lv. ${mastery.required/10}`:''}`));
        if(owned && mastery.required){const bar=h('progress');bar.max=mastery.required;bar.value=Math.min(mastery.points,mastery.required);bar.style.width='100%';bar.setAttribute('aria-label',`${form.name} mastery`);card.append(bar);}
        const choose=btn(app.game.player.form===id?'Active':'Transform',()=>{tell(app.game.selectForm(id));showTab('Forms');});choose.disabled=!owned || !formAvailable(slot,id);card.append(choose);
        if(!owned)card.append(h('small','rpg-muted',form.mastery?'Mastery evolution':'Complete its unlock quest'));
        modal.append(card);
      }
    }
    if(tab==='Forms' && hasFormPath(slot,'instinct')){
      modal.append(h('h3','','Ultra Intuition Energy Avatar'),h('p','','Advanced ability: learn from Meros after Morro mastery. Use it in Perfected or True UI; equip it under Techniques.'));
      const equip=btn('Equip Energy Avatar',()=>{app.game.combat.setTechnique('UltraInstinctAvatar');app.saveNow();showTab('Techniques');});equip.disabled=!slot.moves.includes('UltraInstinctAvatar');modal.append(equip);
    }
    if(tab==='Character' || tab==='Accessories')modal.append(btn('Apply appearance',()=>{app.saveNow();close();}));
    modal.append(btn('Continue',close));
  }
  function update(force=false) {
    if(!root || !app.game || !app.story)return;
    const story=app.story, combat=app.game.combat.snapshot(), interact=story.interaction(), rows=story.tracker(), w=story.waypoint();
    const hud=app.game.hud(), hints={ interact:key('interact'), melee:key('melee'), blast:key('kiBlast'), beam:key('beam'), block:key('block'), charge:key('charge'),lock:key('lockOn'),flight:key('flight'),dash:key('dash') };
    const data={combat,interact:interact && {name:interact.name,action:interact.action},rows,next:story.nextMain(),dist:w?Math.round(Math.hypot(w.x-app.game.player.pos.x,w.z-app.game.player.pos.z)):null,waypoint:w?.text,points:hud.statPoints,hints,paused:app.paused,dialogue:isOpen};
    const hash=JSON.stringify(data);if(!force&&hash===stamp)return;stamp=hash;
    prompt.hidden=!interact || app.paused || isOpen;
    prompt.textContent=interact?`[${hints.interact}] ${interact.action} · ${interact.name}`:'';
    actions.textContent=`${hints.melee} Melee · ${hints.blast} Ki blast · ${hints.beam} ${combat.techniqueName} · ${hints.block} Guard · ${hints.charge} Charge · ${hints.lock} Lock-on`;
    controls.textContent=`${hints.flight} Flight · Space / Ctrl Up / Down · ${hints.dash} Dash · ${key('kaioken')} Kaiyoken · ${key('base')} Base form · Find ! markers for quests`;
    target.hidden=!combat.target;
    target.textContent=combat.target?`${combat.target.boss?'BOSS · ':''}${combat.target.name} · Lv. ${combat.target.level} · ${Math.ceil(combat.target.health)} / ${Math.ceil(combat.target.maxHealth)} HP`:'';
    const rowsKey=JSON.stringify(rows);
    if(rowsKey!==questStamp){
    questStamp=rowsKey;questList.replaceChildren();
    for(const row of rows){
      const card=h('div','rpg-quest');card.append(h('strong','',row.title),h('p','',`${row.objective}${row.progress?' · '+row.progress:''}`));
      if(row.where)card.append(h('small','rpg-muted',row.where));
      card.append(btn('Track',()=>{story.trackQuest(row.id);stamp='';}),btn('Abandon',()=>{story.abandonQuest(row.id);app.saveNow();stamp='';}));
      questList.append(card);
    }
    }
    const n=story.nextMain();
    next.textContent=w?`${w.text} · ${data.dist} m`:n?.locked?`Next story: ${n.title} · requires Lv. ${n.level}. Take a Training Guide patrol to level up.`:n?.giver?`Next story: ${n.title} · ${n.giver} · ${n.zone}`:'Speak to a Training Guide for repeatable combat quests.';
    progress.textContent=`${hud.statPoints} unspent stat points · ${combat.techniqueName}${combat.beamCharge>0?` · charging ${Math.round(combat.beamCharge*100)}%`:''}${combat.beamCd>0?` · cooldown ${combat.beamCd.toFixed(1)}s`:''}${combat.instinctFocus>0?` · UI focus ${combat.instinctFocus.toFixed(1)}s`:''}${combat.avatar.active?` · Avatar ${combat.avatar.remaining.toFixed(1)}s`:combat.avatar.cooldown>0?` · Avatar cooldown ${combat.avatar.cooldown.toFixed(1)}s`:''}`;
    if(combat.kaioken.active)progress.textContent+=` · Kaiyoken x${combat.kaioken.rank}: ${combat.kaioken.remaining.toFixed(1)}s`;
    else if(combat.kaioken.cooldown>0)progress.textContent+=` · Kaiyoken cooldown ${combat.kaioken.cooldown.toFixed(1)}s`;
    death.hidden=!combat.respawn;death.textContent=`Defeated · respawning in ${Math.ceil(combat.respawn)}s`;
  }
  return {
    mount(el){
      root=h('div','rpg-overlay');prompt=btn('',()=>app.story.interact({choose:true}),'rpg-interact');prompt.hidden=true;
      const panel=h('aside','rpg-tracker');panel.append(h('h3','','QUESTS'));
      questList=h('div','rpg-quest-list');next=h('p','rpg-next');journal=btn('Skills & stats',showJournal);
      panel.append(questList,next,journal);
      target=h('div','rpg-target');target.hidden=true;
      const bottom=h('div','rpg-actions');actions=h('div');controls=h('small','rpg-muted');progress=h('div','rpg-progress');bottom.append(progress,actions,controls);
      const menu=h('nav','rpg-stat-buttons');menu.setAttribute('aria-label','Player menu');
      for(const name of tabNames)menu.append(btn(name,()=>showTab(name)));bottom.append(menu);
      modal=h('section','rpg-dialogue');modal.hidden=true;modal.setAttribute('role','dialog');modal.setAttribute('aria-label','NPC dialogue');
      death=h('div','rpg-death');death.hidden=true;
      root.append(prompt,panel,target,bottom,modal,death);el.append(root);
      offs.push(app.events.on('dialogue',dialogue),app.events.on('pause',({paused})=>{if(paused)close();}));
      const onKey=e=>{if(isOpen&&e.code==='Escape'){e.preventDefault();e.stopImmediatePropagation();close();}};
      document.addEventListener('keydown',onKey,true);offs.push(()=>document.removeEventListener('keydown',onKey,true));
      app.dialogueInput = input => {
        if (!isOpen) return;
        if (input.pressed('pause') || input.pressed('menu') || (input.lastDevice === 'gamepad' && input.pressed('dash'))) return close();
        if (input.pressed('interact') || (input.lastDevice === 'gamepad' && input.pressed('jump'))) {
          const focused = document.activeElement;
          const button = modal.contains(focused) && focused.tagName === 'BUTTON' ? focused : modal.querySelector('button');
          button?.click();
        }
      };
      app.openFighterMenu = (tab='Stats') => showTab(tab);
      update(true);
    },
    update(dt){preview?.update(dt);if((timer+=dt)>=.1){timer=0;update();}},
    unmount(){app.dialogueInput=null;app.openFighterMenu=null;close();offs.forEach(off=>off());offs=[];root=null;stamp='';questStamp='';},
  };
}
