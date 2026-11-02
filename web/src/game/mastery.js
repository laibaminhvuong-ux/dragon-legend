import { FORMS, MASTERY_EVOLUTIONS, MASTERY_TUNING } from '../data/forms.js';
import { formAvailable } from './forms.js';
export const MASTERY = MASTERY_TUNING;
export function masteryKey(id) {
  return ['SSJ','SSJGrade2','SSJGrade3','SSJFullPower'].includes(id)?'SSJ':id;
}
export function gainFormMastery(slot,id,amount) {
  if(!slot.forms.includes(id) || !formAvailable(slot,id) || !(amount>0) || !Number.isFinite(amount))return [];
  const key=masteryKey(id);slot.formMastery ||= {};
  slot.formMastery[key]=(slot.formMastery[key] || 0)+amount;
  const evolved=[];
  for(const edge of MASTERY_EVOLUTIONS) {
    if(edge.key!==key || !slot.forms.includes(edge.from) || slot.forms.includes(edge.to))continue;
    if(slot.formMastery[key]<edge.required || !formAvailable(slot,edge.to))continue;
    if(edge.after && !['done','repeatable'].includes(slot.quests[edge.after]?.status))continue;
    slot.forms.push(edge.to);evolved.push(edge.to);
    slot.quests[FORMS[edge.to].unlockQuest]={status:'done',step:1,completions:1,mastery:true};
  }
  return evolved;
}
export function masteryProgress(slot,id) {
  const key=masteryKey(id),points=slot.formMastery?.[key] || 0;
  const next=MASTERY_EVOLUTIONS.find(e=>e.key===key&&!slot.forms.includes(e.to));
  return {points,level:Math.floor(points/MASTERY.pointsPerLevel),next:next?.to || null,required:next?.required || null};
}
