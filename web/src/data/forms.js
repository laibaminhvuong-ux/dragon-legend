import { renameDeep } from "./names.js";
// Transformation tuning for the level-2000 game. Legacy ids remain for save compatibility.
export const FORMS = {};
function form(id,race,name,unlockLevel,multiplier,kiDrain,auraColor,hairColor=null,options={}) {
  FORMS[id]={id,race,name,unlockLevel,multiplier,kiDrain,auraColor,hairColor,unlockQuest:"Form_"+id,...options};
}

form("SSJ","Saiyan","Super Saiyan",250,1.5,2,0xffdc3c,0xffdc3c,{"races":["Saiyan","HalfSaiyan"]});
form("SSJ2","Saiyan","Super Saiyan 2",500,2,4,0xffdc3c,0xffdc3c,{"races":["Saiyan","HalfSaiyan"]});
form("SSJ3","Saiyan","Super Saiyan 3",750,2.6,8,0xffdc3c,0xffdc3c,{"races":["Saiyan","HalfSaiyan"]});
form("SSJGod","Saiyan","Super Saiyan God",1000,3.2,6,0xe62828,0xc81e3c,{"races":["Saiyan","HalfSaiyan"]});
form("SSJBlue","Saiyan","Super Saiyan Blue",1250,4,9,0x3cc8ff,0x3cc8ff,{"races":["Saiyan","HalfSaiyan"]});
form("HSSJ","HalfSaiyan","Super Saiyan",250,1.5,2,0xffdc3c,0xffdc3c,{"legacy":true});
form("HSSJ2","HalfSaiyan","Super Saiyan 2",500,2,4,0xffdc3c,0xffdc3c,{"legacy":true});
form("SSJRage","HalfSaiyan","Super Saiyan Rage",500,2.5,6,0x78c8ff,0xffdc3c,{"legacy":false,"races":["Saiyan","HalfSaiyan"]});
form("Ultimate","HalfSaiyan","Ultimate",1000,3,3,0xf0f0ff,null,{"legacy":true});
form("Beast","HalfSaiyan","Beast",2000,7.2,9,0xc83cff,0xebebf5,{"path":"beast","races":["Saiyan","HalfSaiyan"]});
form("Kaioken","Human","Kaioken",250,1.4,3,0xe62828,null,{"races":["Saiyan","HalfSaiyan","Human"]});
form("Kaioken10","Human","Kaioken x10",500,2.1,8,0xe62828,null,{"races":["Saiyan","HalfSaiyan","Human"]});
form("PotentialUnleashed","Human","Potential Unleashed",900,3,2,0xf0f0ff,null,{});
form("NamekFusion","Namekian","Namekian Fusion",250,1.5,1,0xdcf0dc,null,{});
form("Giant","Namekian","Giant Form",500,2.1,5,0x78e678,null,{});
form("Orange","Namekian","Orange",1100,3.4,7,0xff8c28,null,{});
form("FinalForm","FrostDemon","Final Form",250,1.5,1,0xc878ff,null,{});
form("FullPower","FrostDemon","100% Full Power",550,2.2,6,0xc878ff,null,{});
form("Golden","FrostDemon","Golden",1000,3.1,7,0xffdc3c,null,{});
form("Black","FrostDemon","Black",1300,3.9,9,0x963cc8,null,{});
form("SuperMajin","Majin","Super Majin",250,1.5,2,0xff78c8,null,{});
form("KidForm","Majin","Kid Form",600,2.3,5,0xff50b4,null,{});
form("PureMajin","Majin","Pure Majin",1100,3.3,7,0xff3ca0,null,{});
form("Oozaru","Saiyan","Oozaru (Great Ape)",100,1.3,2,0xbe7846,null,{"races":["Saiyan","HalfSaiyan"],"size":3.2});
form("FalseSSJ","Saiyan","False Super Saiyan",150,1.4,2,0xffdc3c,null,{"races":["Saiyan","HalfSaiyan"]});
form("SSJFullPower","Saiyan","Full Power Super Saiyan",250,1.75,0.6,0xffdc3c,0xffdc3c,{"races":["Saiyan","HalfSaiyan"]});
form("GoldenOozaru","Saiyan","Golden Oozaru",100,2.4,7,0xffdc3c,0xffdc3c,{"races":["Saiyan","HalfSaiyan"],"size":3.2});
form("SSJ4","Saiyan","Super Saiyan 4",100,2.9,5,0xf03b35,null,{"races":["Saiyan","HalfSaiyan"]});
form("LegendarySSJ","Saiyan","Legendary Super Saiyan (Broly)",1400,4.5,8,0x8eff42,0x9bff55,{"races":["Saiyan","HalfSaiyan"]});
form("UIOmen","Saiyan","Ultra Instinct -Sign- (Form)",2000,5,8,0xcbeaff,null,{"races":["Saiyan","HalfSaiyan"],"path":"instinct","dodgeChance":0.35});
form("UIPerfected","Saiyan","Perfected Ultra Instinct",2000,5.8,10,0xe4f1ff,0xeeeeff,{"races":["Saiyan","HalfSaiyan"],"path":"instinct","dodgeChance":0.6});
form("UITrue","Saiyan","True Ultra Instinct",2000,6.2,9,0xb7daff,null,{"races":["Saiyan","HalfSaiyan"],"path":"instinct","dodgeChance":0.5});
form("UltraEgo","Saiyan","Ultra Ego",2000,6.2,10,0xb43cff,0x9343cd,{"races":["Saiyan","HalfSaiyan"],"path":"ego","damageGrowth":0.025});
form("SSJGrade2","Saiyan","Super Saiyan Grade 2 (Super Vegeta)",250,1.85,4,0xffdc3c,0xffdc3c,{"speedFactor":0.9,"races":["Saiyan","HalfSaiyan"]});
form("SSJGrade3","Saiyan","Super Saiyan Grade 3 (Super Trunks)",250,2.1,8,0xffdc3c,0xffdc3c,{"speedFactor":0.7,"races":["Saiyan","HalfSaiyan"]});

export const SHARED_SAIYAN_FORMS=["Oozaru","GoldenOozaru","SSJ4","FalseSSJ","SSJ","SSJGrade2","SSJGrade3","SSJFullPower","Kaioken","SSJ2","SSJRage","Kaioken10","SSJ3","SSJGod","SSJBlue","LegendarySSJ","Beast","UIOmen","UIPerfected","UITrue","UltraEgo"];
export const MASTERY_EVOLUTIONS=[
  {
    "from": "SSJ",
    "key": "SSJ",
    "to": "SSJGrade2",
    "required": 250
  },
  {
    "from": "SSJGrade2",
    "key": "SSJ",
    "to": "SSJGrade3",
    "required": 500
  },
  {
    "from": "SSJGrade3",
    "key": "SSJ",
    "to": "SSJFullPower",
    "required": 1000
  },
  {
    "from": "Oozaru",
    "key": "Oozaru",
    "to": "GoldenOozaru",
    "required": 1000
  },
  {
    "from": "GoldenOozaru",
    "key": "GoldenOozaru",
    "to": "SSJ4",
    "required": 2000
  },
  {
    "from": "SSJ2",
    "key": "SSJ2",
    "to": "SSJRage",
    "required": 1200,
    "after": "m31_zamasu"
  }
];
for(const edge of MASTERY_EVOLUTIONS)FORMS[edge.to].mastery=edge;
export const MASTERY_TUNING={"perSecond":2,"perHit":3,"perKill":25,"pointsPerLevel":10};

// player-facing names are the game's own (data/names.js)
renameDeep(FORMS);
