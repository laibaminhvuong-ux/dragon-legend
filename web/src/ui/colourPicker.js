import { h } from './dom.js';

const clamp=v=>Math.max(0,Math.min(1,v));
export function hsvHex(hue,saturation,value){
  const h=((hue%360)+360)%360/60,s=clamp(saturation),v=clamp(value),c=v*s,x=c*(1-Math.abs(h%2-1)),m=v-c;
  const rgb=h<1?[c,x,0]:h<2?[x,c,0]:h<3?[0,c,x]:h<4?[0,x,c]:h<5?[x,0,c]:[c,0,x];
  return '#'+rgb.map(n=>Math.round((n+m)*255).toString(16).padStart(2,'0')).join('');
}
export function hexHsv(hex){
  const [r,g,b]=[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255),max=Math.max(r,g,b),min=Math.min(r,g,b),delta=max-min;
  const hue=!delta?0:max===r?60*(((g-b)/delta+6)%6):max===g?60*((b-r)/delta+2):60*((r-g)/delta+4);
  return {h:hue,s:max?delta/max:0,v:max};
}

export function colourPicker(initial,onChange){
  let state=hexHsv(initial),pointer=null;
  const root=h('div','ki-colour-picker'),map=h('div','ki-colour-map'),cursor=h('i','ki-colour-cursor');
  map.tabIndex=0;map.setAttribute('role','group');map.setAttribute('aria-label','Ki colour map');
  map.append(cursor);
  const label=h('label','ki-hue-label','Hue'),hue=h('input','ki-hue');
  hue.type='range';hue.min='0';hue.max='359';hue.step='1';hue.setAttribute('aria-label','Ki hue');label.append(hue);
  const hint=h('p','rpg-muted','Click and drag to choose a colour. Use the rainbow slider to change hue. Arrow keys adjust the map.');
  root.append(map,label,hint);
  function paint(){
    map.style.background=`linear-gradient(to top,#000,transparent),linear-gradient(to right,#fff,transparent),hsl(${state.h} 100% 50%)`;
    cursor.style.left=`${state.s*100}%`;cursor.style.top=`${(1-state.v)*100}%`;
    hue.value=String(Math.round(state.h)%360);map.setAttribute('aria-description',hsvHex(state.h,state.s,state.v));
  }
  const notify=preview=>{paint();onChange(hsvHex(state.h,state.s,state.v),{preview});};
  function pick(e){const box=map.getBoundingClientRect();if(box.width<=0 || box.height<=0)return;state.s=clamp((e.clientX-box.left)/box.width);state.v=1-clamp((e.clientY-box.top)/box.height);notify(true);}
  function finish(e){
    if(pointer===null || e.pointerId!==pointer)return;
    const id=pointer;pointer=null;
    if(map.hasPointerCapture?.(id))map.releasePointerCapture(id);
    notify(false);
  }
  map.addEventListener('pointerdown',e=>{
    if(pointer!==null || e.button!==0 || e.isPrimary===false)return;
    e.preventDefault();e.stopPropagation();pointer=e.pointerId;map.setPointerCapture(e.pointerId);pick(e);
  });
  map.addEventListener('pointermove',e=>{if(pointer!==null && e.pointerId===pointer){e.preventDefault();pick(e);}});
  map.addEventListener('pointerup',finish);map.addEventListener('pointercancel',finish);map.addEventListener('lostpointercapture',finish);
  map.addEventListener('keydown',e=>{
    if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key))return;
    e.preventDefault();e.stopPropagation();const step=e.shiftKey ? .1 : .01;
    if(e.key==='ArrowLeft')state.s=clamp(state.s-step);if(e.key==='ArrowRight')state.s=clamp(state.s+step);
    if(e.key==='ArrowUp')state.v=clamp(state.v+step);if(e.key==='ArrowDown')state.v=clamp(state.v-step);notify(false);
  });
  hue.addEventListener('input',()=>{state.h=Number(hue.value);notify(true);});
  hue.addEventListener('change',()=>notify(false));
  paint();
  return {element:root,setHex(value){const next=hexHsv(value);if(next.s===0)next.h=state.h;state=next;paint();}};
}
