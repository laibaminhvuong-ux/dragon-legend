// Authored Godot-only presentation recipes. Times are visual envelopes, never damage delays.
const rows = {
 EnergyWave:['wave','cupped_wave','cast_origin',0x64d6ff,'wave',0.18,0.6],
 KiBlast:['orb','palm_shot','hand_r',0xffdb62,'blast',0.12,0.3],
 Kamehameha:['wave','cupped_wave','cast_origin',0x4dd6ff,'wave',0.26,0.7],
 DestructoDisc:['disc','disc_throw','hand_r',0xffdc50,'disc',0.38,0.7],
 SolarFlare:['sunburst','face_flare','head',0xfff6b5,'flare',1.4,0.7],
 TriBeam:['triad','triangle_hands','cast_origin',0xffc864,'triad',0.48,0.65],
 WolfFangFist:['claw','claw_flurry','hand_r',0xa0e5ff,'rush',0.8,0.55],
 Kaioken:['surge','strain_activation','aura_root',0xff4646,'transform',1.3,0.7],
 SpiritBomb:['spirit','overhead_sphere','head',0x9beaff,'spirit',1.7,0.95],
 SpecialBeamCannon:['spiral','two_finger_focus','hand_r',0xe2a0ff,'spiral',0.18,0.7],
 Masenko:['lance','forehead_push','cast_origin',0xffe678,'lance',0.24,0.55],
 GalickGun:['double_wave','side_palm_wave','cast_origin',0xc191ff,'galick',0.32,0.65],
 FinalFlash:['wide_wave','wide_palm_release','cast_origin',0xffe65d,'flash',0.65,0.9],
 BigBangAttack:['heavy_orb','one_hand_burst','hand_r',0x70caff,'heavy',0.62,0.8],
 DeathBeam:['needle','finger_lance','hand_r',0xff7ab1,'needle',0.055,0.35],
 DeathBall:['eclipse','raised_finger_orb','hand_r',0xb876ff,'eclipse',1.45,0.95],
 Regeneration:['heal','healing_breath','chest',0x7fffba,'heal',1.0,1.3],
 CandyBeam:['ribbon','tentacle_cast','head',0xff83d6,'sweet',0.18,0.65],
 InstantTransmission:['transfer','forehead_transfer','chest',0xbfeaff,'transfer',1.0,0.45],
 Afterimage:['afterimage','evasive_step','chest',0xa5c9ff,'evade',1.0,0.5],
 ExplodingDemonWave:['demon_wave','open_palm_surge','hand_r',0xffc768,'demon',0.46,0.7],
 FusionDance:['formation','fusion_choreography','chest',0xf9eea0,'chime',1.0,1.2],
 Hakai:['destruction','destruction_palm','hand_r',0xcd78ff,'destroy',1.4,0.85],
 GodKi:['focus','controlled_breath','aura_root',0xffc1d8,'focus',0.6,0.8],
 UltraInstinctSign:['focus','instinct_focus','chest',0xbadaff,'focus',0.65,0.7],
 UltraInstinctAvatar:['avatar','avatar_manifest','aura_root',0xc0ddff,'avatar',2.4,1.0],
 EnergyField:['shield','barrier_brace','chest',0x69dfff,'shield',1.25,0.8],
 Melee:['claw','melee_combo','hand_r',0xffddb0,'impact',0.6,0.3],
};
export function skillPresentation(moves,starter){
 const skills={};
 for(const [id,row] of Object.entries(rows)){
  const [geometry,pose,socket,accent,audio,width,lifetime]=row;
  const def=id==='EnergyWave'?starter:id==='Melee'?{name:'Melee combo',kind:'melee'}:moves[id];
  if(!def)throw new Error('Missing gameplay definition for '+id);
  const availability=id==='GodKi'?'passive':id==='FusionDance'?'not_castable':'active';
  skills[id]={id,name:def.name,kind:def.kind,availability,geometry,pose,socket,accent,
   custom_ki:true,width,lifetime,delivery:def.kind==='blast'?'projectile':def.kind==='beam'||def.kind==='ultimate'?'instant_ray':def.kind==='melee'?'contact':'utility',
   phases:{prepare:{socket,visual:'gather',audio:audio+'_charge'},release:{visual:geometry,audio:audio+'_release'},impact:{visual:geometry,audio:audio+'_impact'},recovery:{duration:Math.min(.4,lifetime*.4)}},
   max_duration:Math.max(2,lifetime+1),seeded_variations:3};
 }
 for(const id of Object.keys(moves))if(!skills[id])throw new Error('Missing presentation for '+id);
 return {version:1,event_version:1,sockets:['hand_l','hand_r','chest','head','pelvis','foot_l','foot_r','aura_root','cast_origin'],
  quality:{low:{effects:12,segments:12,particles:8},medium:{effects:28,segments:24,particles:20},high:{effects:48,segments:40,particles:36}},skills};
}
