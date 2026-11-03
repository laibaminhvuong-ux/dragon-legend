import { KAIOKEN as K } from '../data/kaioken.js';
import { formAvailable } from './forms.js';
import { trySpendKi } from './ki.js';

export function kaiokenRanks(slot){
  const ranks=slot.moves.includes('Kaioken') || slot.forms.includes('Kaioken') || slot.forms.includes('Kaioken10')?[2]:[];
  if(slot.forms.includes('Kaioken10') && formAvailable(slot,'Kaioken10'))ranks.push(10);
  return ranks;
}
export function createKaioken(game){
  const p=game.player;let active=0,remaining=0,cooldown=0;
  const compatible=()=>!['Kaioken','Kaioken10'].includes(p.form) && (!p.form || ['Saiyan','HalfSaiyan'].includes(game.slot.race));
  function stop(){if(active)cooldown=K.cooldown;active=0;remaining=0;p.kaioken=0;}
  const api={
    ranks:()=>kaiokenRanks(game.slot),
    select(rank){if(!api.ranks().includes(rank))return 'Complete the Kaiyoken training for that intensity.';if(active)return 'Switch Kaiyoken off before changing intensity.';game.slot.loadout.kaiokenRank=rank;return null;},
    toggle(){
      if(active){stop();return null;}
      if(p.health<=0 || p.stun>0)return 'You cannot activate Kaiyoken right now.';
      if(!compatible())return 'Use base form or a Saiyan transformation; Kaiyoken cannot stack with itself.';
      const rank=game.slot.loadout.kaiokenRank || 2,tier=K.tiers[rank];
      if(!api.ranks().includes(rank))return 'Learn Kaiyoken from King Kae first.';
      if(cooldown>0)return `Kaiyoken cooldown: ${Math.ceil(cooldown)}s.`;
      if(p.health<=p.maxHealth*K.minHealth || p.ki<tier.kiDrain*(p.kiCostScale || 1))return 'Recover health and charge more Ki before using Kaiyoken.';
      active=rank;remaining=tier.duration;p.kaioken=rank;return null;
    },
    multiplier(){return active && compatible() && p.health>0?K.tiers[active].multiplier:1;},
    snapshot(){return {active:!!active,rank:active || game.slot.loadout.kaiokenRank || 2,remaining,cooldown,multiplier:api.multiplier()};},
    update(dt){
      cooldown=Math.max(0,cooldown-dt);
      if(!active)return;
      const tier=K.tiers[active];remaining=Math.max(0,remaining-dt);
      if(!compatible() || p.health<=p.maxHealth*K.minHealth || remaining<=0 || !api.ranks().includes(active) || !trySpendKi(p,tier.kiDrain*(p.kiCostScale || 1)*dt)){stop();return;}
      p.health=Math.max(p.maxHealth*K.minHealth,p.health-p.maxHealth*tier.healthDrain*dt);
      if(p.health<=p.maxHealth*K.minHealth)stop();
    },
    stop,
  };
  return api;
}
