import * as THREE from 'three';
import { h } from './dom.js';

// Project the same firing ray that combat uses, including elevated lock-on targets.
export function createAimReticle(parent, app) {
  const dot=h('div','aim-reticle');
  dot.setAttribute('aria-hidden','true');dot.hidden=true;parent.append(dot);
  const point=new THREE.Vector3();
  return {
    update() {
      const game=app.game;
      dot.hidden=true;
      if(!game || game.player.health<=0 || app.paused || app.dialogueOpen || app.cutscene?.active)return;
      const aim=game.combat.aimState();
      point.set(aim.point.x,aim.point.y,aim.point.z).project(app.gfx.camera);
      if(![point.x,point.y,point.z].every(Number.isFinite) || Math.abs(point.x)>1 || Math.abs(point.y)>1 || Math.abs(point.z)>1)return;
      dot.hidden=false;
      dot.style.left=`${(point.x+1)*50}%`;dot.style.top=`${(1-point.y)*50}%`;
      dot.classList.toggle('locked',aim.locked);
    },
    dispose(){dot.remove();},
  };
}
