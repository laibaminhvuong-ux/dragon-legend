// Cosmetic accessories use existing attachment points; unlocks are earned through story progress.
export const ACCESSORIES = {
  None:{name:'None',after:null},
  Scouter:{name:'Scouter',after:'m02_raditz',attach:'head'},
  Halo:{name:'Other World Halo',after:'m03_snake_way',attach:'head'},
  Cape:{name:'Training Cape',after:'t_piccolo_survival',attach:'back'},
  Wristbands:{name:'Training Wristbands',after:'t_roshi_kamehameha',attach:'handR'},
};
export function accessoryAvailable(slot,id){
  const item=ACCESSORIES[id];return !!item && (!item.after || ['done','repeatable'].includes(slot.quests[item.after]?.status));
}
