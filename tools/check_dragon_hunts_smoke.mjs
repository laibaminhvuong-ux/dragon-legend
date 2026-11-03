// Real-browser coverage of all three new sets and actual summoned dragons. Teleports are fixtures.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {serve} from './serve.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(import.meta.url),{chromium}=require(process.env.PLAYWRIGHT_CORE || 'playwright-core');
const server=await serve(5194,path.join(root,'web'));let browser;
try{
 browser=await chromium.launch({executablePath:process.env.CHROMIUM || path.join(os.homedir(),'.cache/ms-playwright/chromium-1140/chrome-linux/chrome'),args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:1280,height:820}});page.setDefaultTimeout(90000);const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.goto('http://127.0.0.1:5194/?dev');await page.waitForFunction(()=>globalThis.__dragonlegend?.playerModel);
 await page.evaluate(async()=>{const {QUESTS}=await import('/src/data/story.js');const a=__dragonlegend;a.game.addXP(1e12);for(const q of QUESTS.filter(q=>q.main))a.game.slot.quests[q.id]={status:'done'};a.saveNow();});
 const hunts=await page.evaluate(async()=>{const {DRAGON_HUNTS}=await import('/src/data/dragon_hunts.js');return DRAGON_HUNTS;});
 async function enter(zone){
  if(await page.evaluate(zone=>__dragonlegend.game?.zone.id===zone,zone))return;
  await page.evaluate(zone=>__dragonlegend.travel(zone),zone);await page.waitForFunction(zone=>__dragonlegend.game?.zone.id===zone,zone);
  await page.waitForFunction(()=>!document.getElementById('loading'));
 }
 async function dismiss(){const b=page.locator('.rpg-dialogue:not([hidden])').getByRole('button',{name:'Continue',exact:true});if(await b.count())await b.click();}
 await fs.mkdir(path.join(root,'out'),{recursive:true});
 for(const hunt of hunts){
  await enter(hunt.zone);
  assert.equal(await page.evaluate(hunt=>{const a=__dragonlegend,n=a.story.npcs().find(n=>n.id===hunt.giver);Object.assign(a.game.player.pos,{x:n.x,y:n.y,z:n.z});return a.story.acceptQuest(hunt.id);},hunt),true);await dismiss();
  for(const spot of hunt.spots){await enter(spot.zone || hunt.zone);await page.evaluate(spot=>{const a=__dragonlegend;Object.assign(a.game.player.pos,{x:spot.x,y:a.game.zone.heightAt(spot.x,spot.z),z:spot.z});a.story.update(1/60,{});},spot);}
  await enter(hunt.zone);
  await page.waitForFunction(id=>!!__dragonlegend.gfx.scene.getObjectByName('wish-dragon-'+id),hunt.dragon);
  await page.evaluate(id=>{const a=__dragonlegend,n=a.story.npcs().find(n=>n.id==='dragon_'+id);Object.assign(a.game.player.pos,{x:n.x,y:n.y,z:n.z-3});},hunt.dragon);
  await page.screenshot({path:path.join(root,'out','dragon-'+hunt.dragon+'.png')});
  for(let i=0;i<hunt.wishes;i++){await page.keyboard.press('g');await page.waitForFunction(()=>__dragonlegend.dialogueOpen);await dismiss();}
  await page.waitForFunction(id=>__dragonlegend.game.slot.quests[id]?.status==='done',hunt.id);
  await page.waitForFunction(id=>!__dragonlegend.gfx.scene.getObjectByName('wish-dragon-'+id),hunt.dragon);
 }
 await page.evaluate(()=>__dragonlegend.saveNow());await page.reload();await page.waitForFunction(()=>globalThis.__dragonlegend?.playerModel);
 for(const hunt of hunts)assert.equal(await page.evaluate(id=>__dragonlegend.game.slot.quests[id]?.status,hunt.id),'done');
 assert.deepEqual(errors,[]);console.log('Dragon hunt browser smoke passed: 7 Namek, 7 Super beacons, 2 Cereal, models, scripted wishes, dismissal and persistence');
}finally{await browser?.close();server.close();}
