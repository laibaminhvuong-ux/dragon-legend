// Browser acceptance: visible/rebound interaction, quest choice, real kills and saved progression.
// Use the same PLAYWRIGHT_CORE / CHROMIUM environment as tools/check_smoke.mjs.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { serve } from './serve.mjs';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_CORE || 'playwright-core');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const server=await serve(5197,path.join(root,'web'));
let browser;
try {
  browser=await chromium.launch({executablePath:process.env.CHROMIUM || path.join(os.homedir(),'.cache/ms-playwright/chromium-1140/chrome-linux/chrome'),args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:1280,height:720}});page.setDefaultTimeout(90000);
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto('http://127.0.0.1:5197/?dev');
  await page.waitForFunction(()=>globalThis.__dragonlegend?.game && globalThis.__dragonlegend.loop.stats.frames>5);
  assert.equal(await page.locator('.screen-rpg').count(),1);
  await page.evaluate(async()=>{const {xpForLevels}=await import('/src/game/progression.js');globalThis.__dragonlegend.game.addXP(xpForLevels(1,9));});
  // Approach the guide through the test hook, then use actual keyboard/UI commands.
  await page.evaluate(()=>{
    const a=globalThis.__dragonlegend,n=a.story.npcs().find(n=>n.id==='guide_earth_plains');
    Object.assign(a.game.player.pos,{x:n.x+1,y:n.y,z:n.z});
    a.settings.set('bindings',{interact:['KeyH']});
  });
  await page.waitForFunction(()=>document.querySelector('.rpg-interact')?.textContent.includes('[H]'));
  assert.ok(await page.locator('.rpg-interact').isVisible());
  await page.keyboard.press('h');await page.waitForSelector('.rpg-dialogue:not([hidden])');
  assert.equal(await page.evaluate(()=>globalThis.__dragonlegend.game.slot.quests.hunt_earth_plains),undefined);
  await page.getByRole('button',{name:'Accept quest',exact:true}).click();
  await page.waitForFunction(()=>globalThis.__dragonlegend.game.slot.quests.hunt_earth_plains?.status==='active');
  await page.waitForSelector('.rpg-quest');
  const ids=await page.evaluate(()=>globalThis.__dragonlegend.game.combat.enemies.map(e=>e.id));
  for(const id of ids){
    await page.evaluate(id=>{
      const a=globalThis.__dragonlegend,e=a.game.combat.enemies.find(e=>e.id===id);
      Object.assign(a.game.player.pos,{x:e.pos.x,y:e.pos.y,z:e.pos.z-1.7});
      a.game.player.yaw=0;
      a.input.setVirtual('melee',true);
      // This is the same lock target the lock-on command selects; keyboard drives it below.
      a.game.player.lockTarget=null;
    },id);
    await page.keyboard.press('Tab');
    // Level-10 enemies take a few combos; knockback pushes them out of reach at SwiftShader frame rates, so stay adjacent.
    for(let t=0;t<120 && await page.evaluate(id=>globalThis.__dragonlegend.game.combat.enemies.find(e=>e.id===id).health>0,id);t++){
      await page.evaluate(id=>{const a=globalThis.__dragonlegend,e=a.game.combat.enemies.find(e=>e.id===id),p=a.game.player;
        if(Math.hypot(e.pos.x-p.pos.x,e.pos.z-p.pos.z)>1.9)Object.assign(p.pos,{x:e.pos.x,y:e.pos.y,z:e.pos.z-1.7});},id);
      await page.waitForTimeout(1000);
    }
    assert.ok(await page.evaluate(id=>globalThis.__dragonlegend.game.combat.enemies.find(e=>e.id===id).health<=0,id),`enemy ${id} defeated`);
    await page.evaluate(()=>globalThis.__dragonlegend.input.setVirtual('melee',false));
  }
  await page.waitForFunction(()=>globalThis.__dragonlegend.game.slot.quests.hunt_earth_plains.completions===1);
  assert.ok(await page.evaluate(()=>globalThis.__dragonlegend.game.slot.statPoints>0));
  await page.getByRole('button',{name:'Continue',exact:true}).click();
  await page.getByRole('button',{name:'Skills & stats',exact:true}).click();
  const points=await page.evaluate(()=>globalThis.__dragonlegend.game.slot.statPoints);
  await page.getByRole('button',{name:'+ Strength',exact:true}).click();
  assert.equal(await page.evaluate(()=>globalThis.__dragonlegend.game.slot.statPoints),points-1);
  await page.evaluate(()=>globalThis.__dragonlegend.saveNow());
  const saved=await page.evaluate(()=>JSON.parse(localStorage.getItem('dragonlegend.profile')).slots[0]);
  assert.equal(saved.quests.hunt_earth_plains.completions,1);
  await fs.mkdir(path.join(root,'out'),{recursive:true});await page.screenshot({path:path.join(root,'out','rpg.png')});
  assert.deepEqual(errors,[]);console.log('RPG browser smoke passed: interaction, quest choice, three combat kills, rewards, stats and save');
} finally {await browser?.close();server.close();}
