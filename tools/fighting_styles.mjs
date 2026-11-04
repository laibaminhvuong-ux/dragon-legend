// Godot-only style definitions; visible clip ids are the contract with Claude's flow engine.
const specs = [
 ['turtle','Turtle School',[.32,.32,.32,.32],1.10,2.8,1,.28,.14,.05,'solid_guard',
  [['jab','jab',.20],['cross','cross',.30],['front_kick','knee',.35],['straight_punch','cross',.40]],['step_in','jab',.55],['double_palm_push','palm_strike',.65]],
 ['brawler','Brawler',[.46,.48,.50,.48],1.35,2.65,1.35,.60,.22,.075,'wide_low_guard',
  [['wide_hook','hook',.30],['hammer_fist','palm_strike',.35],['shoulder_charge','palm_strike',.70],['uppercut','uppercut',.45]],['charge','palm_strike',1.0],['overhead_slam','palm_strike',.80]],
 ['speedster','Speedster',[.22,.22,.24,.24],.72,2.5,.70,.18,.10,.04,'bouncing_guard',
  [['jab_flurry','jab',.25],['side_step_knee','knee',.40],['spin_kick','spin_kick',.45],['back_fist','cross',.30]],['afterimage_blink','jab',1.2],['blur_rush','hook',.90]],
 ['crane','Crane',[.34,.36,.34,.40],1.15,3.2,.95,.36,.18,.06,'one_leg_guard',
  [['palm_strike','palm_strike',.25],['high_kick','axe_kick',.30],['knife_hand','cross',.35],['crane_kick','spin_kick',.50]],['gliding_step','palm_strike',.75],['one_finger_strike','palm_strike',.40]],
];
export function fightingStyles(combat){
 const styles={}; const referenceCycle=specs[0][2].reduce((a,b)=>a+b,0);
 for(const [id,name,cadence,chain_window,reach,knockback_scale,knockback,stagger,hitstop,stance,combo,dash,finisher] of specs){
  const cycle=cadence.reduce((a,b)=>a+b,0),damage_scale=cycle/referenceCycle;
  const make=(row,step)=>({id:`${id}_${row[0]}`,strike:row[1],lunge:row[2],launch:step===3&&id==='brawler',
   windup:id==='brawler'?.10:id==='speedster'?.035:.06,contact:0,follow_through:cadence[step]*.55,recovery:cadence[step]*.45,blend:.10});
  styles[id]={id,name,stance,cadence,chain_window,reach,damage_scale,guard_pressure:damage_scale,knockback_scale,knockback,stagger,hitstop,
   combo:combo.map(make),dash_in:make(dash,0),finisher:make(finisher,3),
   balance:{cycle_seconds:cycle,ideal_cycle_damage:combat.meleeDamage*(3+combat.comboFinish)*damage_scale,ideal_dps:combat.meleeDamage*(3+combat.comboFinish)/referenceCycle}};
 }
 const npc_assignments={};
 for(const id of ['nappa','broly','recoome','dodoria','android_16','android_19','king_cold','fat_buu','super_buu','jiren','toppo','botamo','magetta','cell_max','saganbo','spopovich'])npc_assignments[id]='brawler';
 for(const id of ['hit','burter','jeice','kid_buu','kefla','gamma1','gamma2','merus','whis','vados','frieza','golden_frieza','black_frieza','frost'])npc_assignments[id]='speedster';
 for(const id of ['tien','piccolo','nail','beerus','zamasu','supreme_kai','kibito','granolah','gas','moro'])npc_assignments[id]='crane';
 return {version:1,default:'turtle',order:specs.map(s=>s[0]),styles,npc_assignments,
  balance:{reference_damage:combat.meleeDamage,finisher_multiplier:combat.comboFinish,reference_cycle_seconds:referenceCycle,notes:'damage_scale = cycle/reference cycle; equal ideal unblocked four-hit DPS. Guard Ki pressure per second is equal. Per-hit integer rounding may differ slightly. Technique/AI cadence and damage remain unchanged.'}};
}
