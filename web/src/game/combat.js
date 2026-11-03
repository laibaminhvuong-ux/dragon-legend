import { INSTINCT_AVATAR as A, canManifestAvatar } from "../data/avatar.js";
import { instinctBenefits } from "./forms.js";
import { MASTERY } from "./mastery.js";
import { freePosition } from "./placement.js";
// Pure combat authority: enemies, attack validation, hit tests, rewards and respawning.
import { COMBAT as C } from '../data/combat.js';
import { RPG, ZONE_LEVELS, camp } from '../data/rpg.js';
import { MOVES } from '../data/moves.js';
import { FORMS } from '../data/forms.js';
import { kiColor } from '../data/appearance.js';
import { defaultLook } from './look.js';
import { trySpendKi } from './ki.js';
import { stepMovement } from './movement.js';
import { resolveCollisions } from './collision.js';
import { xpToNext } from './progression.js';

const distance = (a,b) => Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z);
const copy = p => ({ x:p.x, y:p.y, z:p.z });
export function createCombat(game, events) {
  const p = game.player, zone = game.zone, enemies = [], projectiles = [];
  const emit = (key, value) => events?.emit(key, value);
  const notify = text => emit('notify', { text });
  let story = null, clock = 0, serial = 0, syncAt = 0, meleeCd = 0, blastCd = 0, beamCd = 0;
  let combo = 0, lastSwing = -10, beamHeld = false, beamTime = 0, respawnAt = 0, lastDamage = -100;
  const avatar={remaining:0,readyAt:0,nextStrike:0,damage:0,pulse:0};
  let technique = game.slot.loadout?.technique || 'EnergyWave';
  const starter = C.starterMove;
  const supportedUtilities = ['Regeneration','SolarFlare','Afterimage','UltraInstinctSign','EnergyField','CandyBeam','InstantTransmission','Kaioken'];
  const moveDef = id => id === 'EnergyWave' ? starter : MOVES[id];
  function spawn(def, index=0) {
    const health = (C.enemyHealth + (def.level-1)*C.healthPerLevel) * (def.boss ? C.bossHealth : 1);
    const pos = freePosition(zone, { x:def.x, z:def.z });
    const e = { ...def, id:`enemy:${def.key}:${index}`, kind:'enemy', pos, home:copy(pos), vel:{x:0,y:0,z:0},
      health, maxHealth:health, ki:100, maxKi:100, yaw:Math.PI, onGround:true, runSpeed:C.enemySpeed,
      strength:1, stun:0, flying:false, dashing:false, charging:false, blocking:false, cooldown:0, windup:0,
      attackSerial:0, attackKind:'jab', deadUntil:0, hurtUntil:0 };
    enemies.push(e); game.entities.push(e); return e;
  }
  const baseLevel = ZONE_LEVELS[zone.id] || 1, base = camp(zone);
  for (let i=0; i<3; i++) {
    const x = base.x + (zone.def.terrain.path ? 0 : (i-1)*4), z = base.z + i*4;
    spawn({ key:`patrol_${zone.id}`, name:'Hostile Trainee', level:baseLevel, look:{ ...defaultLook('Human'), outfitTint:3 }, x,z, boss:false }, i);
  }
  function sync() {
    const defs = new Map((story?.encounters() || []).map(d=>[d.key,d]));
    for (let i=enemies.length-1;i>=0;i--) {
      const e=enemies[i];
      if (e.key.startsWith('patrol_') || defs.has(e.key)) continue;
      enemies.splice(i,1); game.entities.splice(game.entities.indexOf(e),1);
      if(p.lockTarget===e.id) p.lockTarget=null;
    }
    for (const d of defs.values()) if (!enemies.some(e=>e.key===d.key)) spawn({ ...d, look:d.look || defaultLook('Saiyan') });
  }
  function hit(target, damage, source, finisher=false) {
    if (target.health<=0 || (target===p && p.evadeUntil>clock)) return;
    if(target===p){
      const instinct=instinctBenefits(p,clock);
      if(clock>=(p.dodgeReady || 0) && p.ki>=instinct.cost && Math.random()<instinct.chance){
        trySpendKi(p,instinct.cost);p.dodgeReady=clock+instinct.cooldown;
        emit('notify',{text:instinct.kind==='form'?'Ultra Instinct dodge!':'Instinct focus: dodged.'});return;
      }
    }
    if(source===p)game.addFormMastery(MASTERY.perHit);
    let amount = damage;
    if (target.blocking && target.ki>=C.guardCost && !finisher) {
      target.ki-=C.guardCost; amount*=C.guardDamage;
    } else if (target.blocking && finisher) {
      target.blocking=false; target.stun=C.stunLimit;
      emit('notify',{text:'Guard broken!'});
    }
    if (target===p && p.barrierUntil>clock) amount*=C.shieldReduction;
    amount=Math.max(1,Math.round(amount)); target.health=Math.max(0,target.health-amount);
    target.stun=Math.min(C.stunLimit,(target.stun || 0)+C.hitStun);
    target.hurtUntil=clock+.2;
    const dx=target.pos.x-source.pos.x,dz=target.pos.z-source.pos.z,d=Math.hypot(dx,dz)||1;
    target.vel.x+=dx/d*C.knockback;target.vel.z+=dz/d*C.knockback;
    emit('damage',{id:target.id,amount,pos:{...target.pos,y:target.pos.y+1.6},blocked:amount<damage*.5});
    if(target===p){lastDamage=clock;if(p.form==='UltraEgo')p.egoBoost=Math.min(C.egoMaxBonus,(p.egoBoost || 0)+FORMS.UltraEgo.damageGrowth);}
    if(target.health>0) return;
    if(target===p) {
      p.flying=false;p.dashing=false;p.charging=false;p.lockTarget=null;p.form='';
      respawnAt=clock+C.respawnSeconds; beamHeld=false; projectiles.length=0;
      notify('You were defeated. Respawning at the safe area. Your quests and rewards are kept.');
    } else {
      target.deadUntil=clock+(target.boss?C.bossRespawn:C.enemyRespawn);
      if(p.lockTarget===target.id)p.lockTarget=null;
      const xp=Math.max(10,Math.round(xpToNext(target.level)*RPG.killXp));
      const zeni=target.level*RPG.zeniPerLevel;
      game.addFormMastery(MASTERY.perKill);game.addXP(xp);game.addZeni(zeni);
      story?.enemyDefeated(target.key,zone.id);
      emit('enemyDefeated',{id:target.id,enemy:target.key,zone:zone.id,xp,zeni});
      notify(`${target.name} defeated · +${xp} XP · +${zeni} zeni`);
    }
  }
  function targetInFront(range) {
    const locked=enemies.find(e=>e.id===p.lockTarget && e.health>0);
    if(locked && distance(p.pos,locked.pos)<=range) return locked;
    return enemies.filter(e=> {
      const dx=e.pos.x-p.pos.x,dz=e.pos.z-p.pos.z,d=Math.hypot(dx,dz);
      return e.health>0 && distance(p.pos,e.pos)<=range && (d<.01 || (dx*Math.sin(p.yaw)+dz*Math.cos(p.yaw))/d>C.meleeArc);
    }).sort((a,b)=>distance(a.pos,p.pos)-distance(b.pos,p.pos))[0];
  }
  function aim() {
    const e=enemies.find(e=>e.id===p.lockTarget && e.health>0);
    const origin={x:p.pos.x,y:p.pos.y+1.15*(FORMS[p.form]?.size || 1),z:p.pos.z};
    const delta=e ? {x:e.pos.x-origin.x,y:e.pos.y+1-origin.y,z:e.pos.z-origin.z} : {x:Math.sin(p.yaw),y:0,z:Math.cos(p.yaw)};
    const d=Math.hypot(delta.x,delta.y,delta.z)||1;
    return {origin,dir:{x:delta.x/d,y:delta.y/d,z:delta.z/d}};
  }
  function fire(id, charge=0) {
    if(id==='Kaioken'){const error=game.kaioken.toggle();if(error)notify(error);return !error;}
    const def=moveDef(id);
    if(def?.kind==='avatar'){
      if(!canManifestAvatar(game.slot,p)){notify('The Avatar requires learned training and active Perfected or True Ultra Instinct.');return false;}
      if(avatar.remaining>0 || clock<avatar.readyAt){notify(`Avatar cooldown: ${Math.ceil(Math.max(0,avatar.readyAt-clock))}s.`);return false;}
    }
    if(!def || !trySpendKi(p,def.kiCost*(p.kiCostScale || 1))) { notify('Not enough ki. Hold Charge to recover.'); return false; }
    const {origin,dir}=aim();
    const damage=C.meleeDamage*p.kiPower*def.power*(1+charge)*game.kaioken.multiplier()*(p.form==='UltraEgo'?1+(p.egoBoost || 0):1);
    if(def.kind==='avatar'){
      avatar.remaining=A.duration;avatar.readyAt=clock+A.cooldown;avatar.nextStrike=clock;avatar.damage=damage;
      notify('Ultra Instinct Energy Avatar manifested!');
    } else if(def.kind==='utility') {
      if(id==='Regeneration')p.health=Math.min(p.maxHealth,p.health+p.maxHealth*C.utilityHeal);
      else if(id==='SolarFlare'){for(const e of enemies)if(e.health>0&&distance(p.pos,e.pos)<C.utilityRange)e.stun=C.utilityDuration;}
      else if(id==='EnergyField')p.barrierUntil=clock+C.utilityDuration;
      else if(id==='CandyBeam') {const e=targetInFront(C.utilityRange);if(e)hit(e,e.health<e.maxHealth*C.candyThreshold?e.health:C.candyDamage,p);}
      else if(id==='InstantTransmission') {const e=targetInFront(C.lockRange);if(e){p.pos.x=e.pos.x-Math.sin(e.yaw)*C.teleportOffset;p.pos.z=e.pos.z-Math.cos(e.yaw)*C.teleportOffset;p.pos.y=e.pos.y;}}
      else if(id==='UltraInstinctSign'){p.uiTechniqueUntil=clock+C.uiTechniqueDuration;notify('Ultra Instinct Sign focus: small dodge chance, no form stat boost.');}
      else p.evadeUntil=clock+C.utilityDuration;
    } else if(def.kind==='melee') { const e=targetInFront(C.meleeRange+1);if(e)hit(e,damage,p,true); }
    else if(def.kind==='beam' || def.kind==='ultimate') {
      const end={x:origin.x+dir.x*C.beamRange,y:origin.y+dir.y*C.beamRange,z:origin.z+dir.z*C.beamRange};
      for(const e of enemies)if(e.health>0 && segmentDistance({x:e.pos.x,y:e.pos.y+1,z:e.pos.z},origin,end)<C.beamRadius)hit(e,damage,p,true);
      emit('beam',{from:origin,to:end,color:kiColor(game.slot.appearance)});
    } else projectiles.push({id:++serial,pos:origin,dir,life:C.projectileLife,damage,owner:p,color:kiColor(game.slot.appearance)});
    p.attackSerial=(p.attackSerial||0)+1;p.attackKind='cross';
    emit('attack',{id:p.id,kind:def.kind,pos:copy(p.pos)}); return true;
  }
  const avatarInfo=()=>({active:avatar.remaining>0 && canManifestAvatar(game.slot,p),remaining:canManifestAvatar(game.slot,p)?avatar.remaining:0,cooldown:Math.max(0,avatar.readyAt-clock),pulse:avatar.pulse});
  const combat = {
    enemies, projectiles,
    // Presentation reads the same ray used by fire(); no independent visual aim calculation.
    aimState() {
      const ray=aim(),locked=enemies.find(e=>e.id===p.lockTarget && e.health>0);
      return {...ray,locked:!!locked,point:locked?{x:locked.pos.x,y:locked.pos.y+1,z:locked.pos.z}:
        {x:ray.origin.x+ray.dir.x*C.beamRange,y:ray.origin.y+ray.dir.y*C.beamRange,z:ray.origin.z+ray.dir.z*C.beamRange}};
    },
    avatarState(){return {...avatarInfo(),pos:copy(p.pos),yaw:p.yaw};},
    setStory(value){story=value;sync();},
    availableTechniques(){return [...new Set(['EnergyWave',...game.slot.moves.filter(id=>MOVES[id] && (MOVES[id].power>0 || supportedUtilities.includes(id))),...(game.kaioken.ranks().length?['Kaioken']:[])])];},
    setTechnique(id){if(!combat.availableTechniques().includes(id))return false;technique=id;(game.slot.loadout ||= {}).technique=id;return true;},
    snapshot(){
      const e=enemies.find(e=>e.id===p.lockTarget && e.health>0);
      return {kaioken:game.kaioken.snapshot(),avatar:avatarInfo(),instinctFocus:Math.max(0,(p.uiTechniqueUntil || 0)-clock),technique,techniqueName:moveDef(technique)?.name,beamCharge:Math.min(1,beamTime/C.beamCharge),meleeCd,blastCd,beamCd,
        target:e?{id:e.id,name:e.name,level:e.level,health:e.health,maxHealth:e.maxHealth,boss:e.boss}:null,
        respawn:respawnAt?Math.max(0,respawnAt-clock):0};
    },
    update(dt,it){
      clock+=dt;meleeCd=Math.max(0,meleeCd-dt);blastCd=Math.max(0,blastCd-dt);beamCd=Math.max(0,beamCd-dt);
      if(clock>=syncAt){syncAt=clock+C.syncInterval;sync();}
      if(p.health<=0){
        avatar.remaining=0;
        if(respawnAt && clock>=respawnAt){
          respawnAt=0;game.refreshDerived(true);Object.assign(p.pos,{x:zone.spawn.x,y:zone.heightAt(zone.spawn.x,zone.spawn.z),z:zone.spawn.z});
          Object.assign(p.vel,{x:0,y:0,z:0});p.stun=0;p.onGround=true;p.invulnerableUntil=clock+C.spawnProtection;
          for(const e of enemies){Object.assign(e.pos,e.home);e.health=e.maxHealth;e.windup=0;e.cooldown=0;}
          notify('Recovered. Return to your quest when you are ready.');
        }
        return;
      }
      if(p.lockTarget && !enemies.some(e=>e.id===p.lockTarget && e.health>0 && distance(e.pos,p.pos)<=C.lockRange))p.lockTarget=null;
      if(it.lockOn) {
        if(p.lockTarget)p.lockTarget=null;
        else p.lockTarget=enemies.filter(e=>e.health>0&&distance(e.pos,p.pos)<C.lockRange).sort((a,b)=>distance(a.pos,p.pos)-distance(b.pos,p.pos))[0]?.id || null;
      }
      const locked=enemies.find(e=>e.id===p.lockTarget&&e.health>0);
      if(locked)p.yaw=Math.atan2(locked.pos.x-p.pos.x,locked.pos.z-p.pos.z);
      if(p.stun<=0 && !p.charging && !p.blocking) {
        if(it.melee && meleeCd===0){
          combo=clock-lastSwing<C.comboWindow?(combo%4)+1:1;lastSwing=clock;meleeCd=C.meleeCooldown;
          const target=targetInFront(C.meleeRange*(FORMS[p.form]?.size || 1));p.attackSerial=(p.attackSerial||0)+1;p.attackKind=['jab','cross','hook','leg kick'][combo-1];
          emit('attack',{id:p.id,kind:'melee',combo,pos:copy(p.pos)});
          if(target)hit(target,C.meleeDamage*p.strength*game.kaioken.multiplier()*(p.form==='UltraEgo'?1+(p.egoBoost || 0):1)*(combo===4?C.comboFinish:1),p,combo===4);
        }
        if(it.kiBlast && blastCd===0 && fire('KiBlast'))blastCd=C.blastCooldown;
        if(it.beam && beamCd===0){beamHeld=true;beamTime=Math.min(C.beamCharge,beamTime+dt);}
        if(!it.beam && beamHeld){if(fire(technique,beamTime/C.beamCharge))beamCd=moveDef(technique)?.kind==='utility'?C.utilityCooldown:C.beamCooldown;beamHeld=false;beamTime=0;}
      } else {beamHeld=false;beamTime=0;}
      if(game.player.form){
        const f=FORMS[p.form],drain=f.kiDrain*(p.kiCostScale || 1)*(game.slot.moves.includes('GodKi') ? .7 : 1)*(game.slot.story?.items?.instinctMastery && f.path==='instinct'?.8:1)*dt;
        if(!trySpendKi(p,drain)){p.form='';game.refreshDerived();notify('Transformation ended: ki exhausted.');}
      }
      if(avatar.remaining>0){
        if(!canManifestAvatar(game.slot,p))avatar.remaining=0;
        else {
          avatar.remaining=Math.max(0,avatar.remaining-dt);
          if(avatar.remaining>0 && clock>=avatar.nextStrike){
            avatar.nextStrike+=A.strikeInterval;avatar.pulse++;
            const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw);
            for(const enemy of enemies){
              const dx=enemy.pos.x-p.pos.x,dz=enemy.pos.z-p.pos.z,along=dx*fx+dz*fz;
              if(enemy.health>0 && along>=0 && along<=A.range && Math.abs(dx*fz-dz*fx)<=A.halfWidth && Math.abs(enemy.pos.y-p.pos.y)<=A.verticalReach)hit(enemy,avatar.damage,p,true);
            }
            emit('avatarStrike',{pos:copy(p.pos),yaw:p.yaw,pulse:avatar.pulse});
          }
        }
      }
      if(p.form!=='UltraEgo')p.egoBoost=0;
      if(clock-lastDamage>C.regenDelay && !game.kaioken.snapshot().active)p.health=Math.min(p.maxHealth,p.health+p.maxHealth*C.playerRegen*dt);
      for(let i=projectiles.length-1;i>=0;i--){
        const b=projectiles[i],old=copy(b.pos);b.life-=dt;
        b.pos.x+=b.dir.x*C.projectileSpeed*dt;b.pos.y+=b.dir.y*C.projectileSpeed*dt;b.pos.z+=b.dir.z*C.projectileSpeed*dt;
        const target=enemies.find(e=>e.health>0&&segmentDistance({x:e.pos.x,y:e.pos.y+1,z:e.pos.z},old,b.pos)<C.projectileRadius);
        if(target){hit(target,b.damage,b.owner);b.life=0;}
        if(b.life<=0 || b.pos.y<zone.heightAt(b.pos.x,b.pos.z))projectiles.splice(i,1);
      }
      for(const e of enemies){
        if(e.health<=0){if(clock>=e.deadUntil && distance(p.pos,e.home)>C.respawnSafeRange){e.health=e.maxHealth;Object.assign(e.pos,e.home);e.stun=0;e.windup=0;}continue;}
        const dist=distance(e.pos,p.pos),homeDist=distance(e.pos,e.home);
        e.cooldown=Math.max(0,e.cooldown-dt);e.stun=Math.max(0,e.stun-dt);
        if(dist>C.aggroRange && !e.aggro && homeDist<.5){e.health=Math.min(e.maxHealth,e.health+e.maxHealth*dt*C.enemyRegen);continue;}
        const returning=dist>C.leashRange || homeDist>C.leashRange || p.pos.y-e.pos.y>5;
        const goal=returning?e.home:p.pos,dx=goal.x-e.pos.x,dz=goal.z-e.pos.z,d=Math.hypot(dx,dz)||1;
        e.aggro=!returning;
        if(returning){e.windup=0;e.health=Math.min(e.maxHealth,e.health+e.maxHealth*dt*C.enemyRegen);}
        if(e.windup>0){
          e.windup-=dt;
          if(e.windup<=0 && e.stun<=0 && dist<C.enemyRange+.5 && !(p.invulnerableUntil>clock)){
            e.attackSerial++;e.attackKind='cross';hit(p,(C.enemyDamage+(e.level-1)*C.enemyDamagePerLevel)*(e.boss?C.bossDamage:1),e);
          }
        } else if(!returning && dist<C.enemyRange && e.cooldown===0 && e.stun===0){e.windup=C.enemyWindup;e.cooldown=C.enemyCooldown;}
        const prev=copy(e.pos),moving=(returning?d>.5:dist>C.enemyRange*.85) && !e.windup;
        stepMovement(e,{moveX:moving?dx/d:0,moveZ:moving?dz/d:0},dt,zone);resolveCollisions(e,zone,prev);
      }
    },
  };
  if (!combat.availableTechniques().includes(technique)) technique = "EnergyWave";
  (game.slot.loadout ||= {}).technique=technique;
  return combat;
}
function segmentDistance(p,a,b){
  const dx=b.x-a.x,dy=b.y-a.y,dz=b.z-a.z,dd=dx*dx+dy*dy+dz*dz;
  const t=dd?Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy+(p.z-a.z)*dz)/dd)):0;
  return Math.hypot(p.x-a.x-dx*t,p.y-a.y-dy*t,p.z-a.z-dz*t);
}
