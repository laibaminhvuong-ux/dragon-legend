// Interaction, dialogue and the action-RPG quest/combat overlay. Commands go to game/story APIs.
import { h, btn } from './dom.js';
import { MOVES } from '../data/moves.js';
import { OUTFITS } from '../data/outfits.js';
import { FORMS } from '../data/forms.js';

const displayCode = code => (code || '').replace(/^Key/, '').replace(/^Digit/, '').replace('Mouse0','LMB').replace('Mouse2','RMB').replace('ControlLeft','Ctrl').replace(/^Pad/, 'Pad ');
export function rpg(app) {
  let root, prompt, questList, next, target, actions, modal, controls, progress, death, journal;
  let offs=[], stamp='', questStamp='', timer=0, isOpen=false;
  const key = action => displayCode(app.input.bindings()[action]?.[0] || action);
  function close() {
    if (!modal) return;
    modal.hidden=true; modal.replaceChildren();isOpen=false;app.dialogueOpen=false;
    app.input.pointerLockWanted=!app.paused;
  }
  function open(speaker, text) {
    isOpen=true;app.dialogueOpen=true;app.input.pointerLockWanted=false;
    document.exitPointerLock?.();
    modal.replaceChildren();modal.hidden=false;
    modal.append(h('h2','',speaker),h('p','',text));
  }
  function dialogue(d) {
    open(d.speaker,d.text);
    if(d.kind==='choice') {
      for(const q of d.choices || []) {
        const card=h('section','rpg-offer');
        card.append(h('h3','',`${q.title} · Lv. ${q.level}`),h('p','',q.text),h('p','rpg-muted',q.objective));
        const r=q.rewards || {};
        card.append(h('p','rpg-reward',`${r.xp || 0} XP · ${r.zeni || 0} zeni`));
        card.append(btn('Accept quest',()=> {
          if(app.story.acceptQuest(q.id)){app.saveNow();close();stamp='';}
          else {close();app.events.emit('notify',{text:'Move closer to the quest giver and try again.'});}
        },'primary'));
        modal.append(card);
      }
    }
    if(d.speaker==='Training Guide')modal.append(btn('Shop',showShop));
    modal.append(btn(d.kind==='choice'?'Not now':'Continue',close));
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
  function showJournal() {
    open('Fighter journal','Learn techniques from story trainers. Choose a technique here, then hold and release its attack button. Transformations require their unlock quests.');
    const snapshot=app.game.combat.snapshot();
    const select=h('select');select.setAttribute('aria-label','Equipped technique');
    for(const id of app.game.combat.availableTechniques()) {
      const opt=h('option','',id==='EnergyWave'?'Energy Wave (starter)':MOVES[id].name);opt.value=id;opt.selected=id===snapshot.technique;select.append(opt);
    }
    select.onchange=()=>{app.game.combat.setTechnique(select.value);app.saveNow();};
    modal.append(h('h3','','Equipped technique'),select);
    for(const id of app.story.journal().moves)modal.append(h('p','rpg-muted',`${MOVES[id]?.name || id}: ${MOVES[id]?.desc || ''}`));
    const forms=app.story.journal().forms.map(id=>FORMS[id]?.name || id);
    modal.append(h('p','',`Unlocked forms: ${forms.join(', ') || 'None yet'}. Press ${key('transform')} to cycle unlocked forms.`));
    const stats=h('div','rpg-stat-buttons');
    for(const stat of ['Health','Ki','Strength','KiPower','Speed']) stats.append(btn(`+ ${stat}`,()=> {
      const err=app.game.spendStatPoint(stat); if(err)app.events.emit('notify',{text:err});else app.saveNow();
      progress.textContent=`${app.game.hud().statPoints} unspent stat points`;
    }));
    modal.append(h('h3','','Spend stat points'),stats);
    const outfit=h('select');outfit.setAttribute('aria-label','Equipped outfit');
    for(const id of app.game.slot.outfits){const opt=h('option','',OUTFITS[id]?.name || id);opt.value=id;opt.selected=id===app.game.slot.appearance.outfit;outfit.append(opt);}
    outfit.onchange=()=>{app.game.equipOutfit(outfit.value);app.saveNow();};
    modal.append(h('h3','','Outfit'),outfit);
    const use=btn(`Use Recovery Capsule (${app.story.journal().items.capsule || 0})`,()=>{
      if(app.story.useItem('capsule')){app.saveNow();showJournal();}
      else app.events.emit('notify',{text:'You need a capsule and missing health or ki. Buy capsules from a Training Guide.'});
    });modal.append(use);
    if(app.story.interaction()?.id.startsWith('guide_'))modal.append(btn('Guide shop',showShop));
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
    controls.textContent=`${hints.flight} Flight · Space / Ctrl Up / Down · ${hints.dash} Dash · Find ! markers for quests`;
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
    progress.textContent=`${hud.statPoints} unspent stat points · ${combat.techniqueName}${combat.beamCharge>0?` · charging ${Math.round(combat.beamCharge*100)}%`:''}${combat.beamCd>0?` · cooldown ${combat.beamCd.toFixed(1)}s`:''}`;
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
      modal=h('section','rpg-dialogue');modal.hidden=true;modal.setAttribute('role','dialog');modal.setAttribute('aria-label','NPC dialogue');
      death=h('div','rpg-death');death.hidden=true;
      root.append(prompt,panel,target,bottom,modal,death);el.append(root);
      offs.push(app.events.on('dialogue',dialogue),app.events.on('pause',({paused})=>{if(paused)close();}));
      const onKey=e=>{if(isOpen&&e.code==='Escape'){e.preventDefault();e.stopImmediatePropagation();close();}};
      document.addEventListener('keydown',onKey,true);offs.push(()=>document.removeEventListener('keydown',onKey,true));
      app.dialogueInput = input => {
        if (!isOpen) return;
        if (input.pressed('pause') || (input.lastDevice === 'gamepad' && input.pressed('dash'))) return close();
        if (input.pressed('interact') || (input.lastDevice === 'gamepad' && input.pressed('jump'))) {
          const focused = document.activeElement;
          const button = modal.contains(focused) && focused.tagName === 'BUTTON' ? focused : modal.querySelector('button');
          button?.click();
        }
      };
      update(true);
    },
    update(dt){if((timer+=dt)>=.1){timer=0;update();}},
    unmount(){app.dialogueInput=null;close();offs.forEach(off=>off());offs=[];root=null;stamp='';questStamp='';},
  };
}
