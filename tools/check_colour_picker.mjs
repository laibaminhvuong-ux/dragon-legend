import assert from 'node:assert/strict';
import {colourPicker,hsvHex,hexHsv} from '../web/src/ui/colourPicker.js';
let count=0;const test=(name,fn)=>{fn();count++;console.log('ok',name);};
test('HSV conversion covers the rainbow, greyscale, black and round trips',()=>{
 for(const [h,want] of [[0,'#ff0000'],[60,'#ffff00'],[120,'#00ff00'],[180,'#00ffff'],[240,'#0000ff'],[300,'#ff00ff'],[360,'#ff0000']])assert.equal(hsvHex(h,1,1),want);
 assert.equal(hsvHex(17,0,1),'#ffffff');assert.equal(hsvHex(40,1,0),'#000000');
 for(const hex of ['#000000','#ffffff','#12ab34','#ff6600','#63cfff','#aabbcc']){const {h,s,v}=hexHsv(hex);assert.equal(hsvHex(h,s,v),hex);}
});
function fixture(){
 const previous=globalThis.document,nodes=[],changes=[];
 globalThis.document={createElement(tag){const el={tag,style:{},attrs:{},events:{},children:[],capture:null,setAttribute(k,v){this.attrs[k]=v;},append(...children){this.children.push(...children);},addEventListener(k,fn){this.events[k]=fn;},getBoundingClientRect(){return {left:10,top:20,width:200,height:100};},setPointerCapture(id){this.capture=id;},hasPointerCapture(id){return this.capture===id;},releasePointerCapture(id){this.capture=null;this.events.lostpointercapture?.({pointerId:id});}};nodes.push(el);return el;}};
 const picker=colourPicker('#ff0000',(hex,phase)=>changes.push({hex,...phase}));
 return {picker,map:nodes.find(n=>n.attrs['aria-label']==='Ki colour map'),hue:nodes.find(n=>n.attrs['aria-label']==='Ki hue'),changes,done(){globalThis.document=previous;}};
}
const pointer=(id=1,x=110,y=70)=>({pointerId:id,clientX:x,clientY:y,button:0,isPrimary:true,preventDefault(){},stopPropagation(){}});
test('pointer capture continuously selects while held, clamps edges, and ignores hover/other pointers',()=>{
 const f=fixture();try{
  f.map.events.pointermove(pointer());assert.equal(f.changes.length,0);
  f.map.events.pointerdown(pointer());assert.equal(f.map.capture,1);assert.deepEqual(f.changes.at(-1),{hex:'#804040',preview:true});
  f.map.events.pointermove(pointer(2,210,20));assert.equal(f.changes.length,1);
  f.map.events.pointermove(pointer(1,900,-20));assert.deepEqual(f.changes.at(-1),{hex:'#ff0000',preview:true});
  f.map.events.pointerup(pointer());assert.equal(f.map.capture,null);assert.deepEqual(f.changes.at(-1),{hex:'#ff0000',preview:false});
  const n=f.changes.length;f.map.events.pointermove(pointer());assert.equal(f.changes.length,n);
  f.map.events.pointerdown({...pointer(),button:2});assert.equal(f.changes.length,n);
 }finally{f.done();}
});
test('cancel and lost capture finalize once and clear drag state',()=>{
 for(const event of ['pointercancel','lostpointercapture']){const f=fixture();try{f.map.events.pointerdown(pointer());f.map.events[event](pointer());assert.equal(f.changes.filter(c=>!c.preview).length,1);const n=f.changes.length;f.map.events.pointermove(pointer());assert.equal(f.changes.length,n);}finally{f.done();}}
});
test('hue slider and keyboard update colour; hex synchronization does not emit recursively',()=>{
 const f=fixture();try{
  f.hue.value='120';f.hue.events.input();assert.deepEqual(f.changes.at(-1),{hex:'#00ff00',preview:true});f.hue.events.change();assert.equal(f.changes.at(-1).preview,false);
  const n=f.changes.length;f.picker.setHex('#12ab34');assert.equal(f.changes.length,n);
  f.map.events.keydown({key:'ArrowDown',preventDefault(){},stopPropagation(){}});assert.equal(f.changes.length,n+1);assert.notEqual(f.changes.at(-1).hex,'#12ab34');
  f.picker.setHex('#000000');f.hue.value='240';f.hue.events.input();assert.equal(f.changes.at(-1).hex,'#000000');
  f.map.events.keydown({key:'ArrowUp',shiftKey:true,preventDefault(){},stopPropagation(){}});assert.notEqual(f.changes.at(-1).hex,'#000000');
 }finally{f.done();}
});
console.log(`Colour picker checks passed: ${count}`);
