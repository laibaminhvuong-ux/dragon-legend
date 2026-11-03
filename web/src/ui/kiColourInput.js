import { h, btn, hex } from './dom.js';
import { kiColor, normalizeKiHex } from '../data/appearance.js';
import { colourPicker } from './colourPicker.js';

/** Commit on Apply or Enter, so typing never rebuilds a preview halfway through a value. */
export function kiColourInput(appearance, apply) {
  const root=h('div','ki-hex-field'),label=h('label','', 'Custom Ki hex colour');
  const input=h('input');input.type='text';input.value=hex(kiColor(appearance));
  input.placeholder='#63CFFF';input.maxLength=7;input.spellcheck=false;
  input.setAttribute('aria-label','Ki hex colour');
  const error=h('p','rpg-muted');error.setAttribute('aria-live','polite');
  const swatch=h('span');swatch.style.cssText='display:inline-block;width:24px;height:24px;border:1px solid #888;border-radius:4px;vertical-align:middle;margin:0 8px';swatch.style.background=input.value;
  const picker=colourPicker(input.value,(value,phase)=>{
    input.value=value;input.setAttribute('aria-invalid','false');swatch.style.background=value;error.textContent=apply(value,phase) || '';
  });
  function commit(){
    const value=normalizeKiHex(input.value);
    if(!value){input.setAttribute('aria-invalid','true');error.textContent='Use 3 or 6 hex digits, for example #63CFFF.';return;}
    const message=apply(value);
    if(message){error.textContent=message;return;}
    input.value=value;input.setAttribute('aria-invalid','false');error.textContent='';swatch.style.background=value;
    picker.setHex(value);
  }
  input.addEventListener('input',()=>{const value=normalizeKiHex(input.value);if(value)swatch.style.background=value;error.textContent='';input.setAttribute('aria-invalid','false');});
  input.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();e.stopPropagation();commit();}});
  label.append(input);root.append(picker.element,label,swatch,btn('Apply hex colour',commit),error);return root;
}
