// Real browser acceptance: aim marker, base charge aura, menu colour and save/reload.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {serve} from './serve.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(import.meta.url),{chromium}=require(process.env.PLAYWRIGHT_CORE || 'playwright-core');
const server=await serve(5195,path.join(root,'web'));let browser;
try{
  browser=await chromium.launch({executablePath:process.env.CHROMIUM || path.join(os.homedir(),'.cache/ms-playwright/chromium-1140/chrome-linux/chrome'),args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:1280,height:820}});page.setDefaultTimeout(90000);
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.goto('http://127.0.0.1:5195/?dev');await page.waitForFunction(()=>globalThis.__dragonlegend?.playerModel);
  await page.waitForFunction(()=>!document.querySelector('.aim-reticle')?.hidden);
  await page.getByRole('button',{name:'Character',exact:true}).click();
  const modal=page.locator('.rpg-dialogue');await modal.getByRole('combobox',{name:'Ki colour',exact:true}).selectOption('6');
  await page.waitForFunction(()=>__dragonlegend.game.slot.appearance.kiColor===6);
  const chart=modal.getByRole('group',{name:'Ki colour map',exact:true});
  const fighterId=await page.evaluate(()=>__dragonlegend.playerModel.object3d.id);
  await modal.getByRole('slider',{name:'Ki hue',exact:true}).press('Home');
  const chartBox=await chart.boundingBox();
  await page.mouse.move(chartBox.x+chartBox.width*.2,chartBox.y+chartBox.height*.2);await page.mouse.down();
  await page.mouse.move(chartBox.x+chartBox.width*.8,chartBox.y+chartBox.height*.1,{steps:8});
  const dragged=await page.evaluate(()=>__dragonlegend.game.slot.appearance.kiColorHex);assert.match(dragged,/^#[0-9a-f]{6}$/);
  assert.equal(await page.evaluate(()=>__dragonlegend.playerModel.object3d.id),fighterId,'drag keeps the fighter model');
  await page.mouse.up();
  await modal.getByRole('textbox',{name:'Ki hex colour',exact:true}).fill('#12');
  await modal.getByRole('button',{name:'Apply hex colour',exact:true}).click();
  assert.equal(await modal.getByRole('textbox',{name:'Ki hex colour',exact:true}).getAttribute('aria-invalid'),'true');
  await modal.getByRole('textbox',{name:'Ki hex colour',exact:true}).fill('12aB34');
  await modal.getByRole('textbox',{name:'Ki hex colour',exact:true}).press('Enter');
  await page.waitForFunction(()=>__dragonlegend.game.slot.appearance.kiColorHex==='#12ab34');
  assert.equal(await page.locator('.aim-reticle').isVisible(),false,'no reticle over fighter menu');
  await modal.getByRole('button',{name:'Apply appearance',exact:true}).click();
  await page.keyboard.down('c');
  await page.waitForFunction(()=>__dragonlegend.game.player.charging && __dragonlegend.playerModel.object3d.getObjectByName('ki-charge-aura')?.visible);
  const charge=await page.evaluate(()=>{
    const a=__dragonlegend,fx=a.playerModel.object3d.getObjectByName('ki-charge-aura');
    return {form:a.game.player.form,color:fx.children[0].material.uniforms.uColor.value.getHex(),ki:a.game.slot.appearance.kiColor};
  });assert.deepEqual(charge,{form:'',color:0x12ab34,ki:6});
  await fs.mkdir(path.join(root,'out'),{recursive:true});await page.screenshot({path:path.join(root,'out','ki-charge.png')});
  await page.keyboard.up('c');await page.waitForFunction(()=>!__dragonlegend.playerModel.object3d.getObjectByName('ki-charge-aura')?.visible);
  await page.evaluate(()=>{
    const a=__dragonlegend,p=a.game.player,e=a.game.combat.enemies.find(e=>e.health>0);
    e.pos={x:p.pos.x+Math.sin(p.yaw)*12,y:p.pos.y+3,z:p.pos.z+Math.cos(p.yaw)*12};e.home={...e.pos};p.lockTarget=e.id;
  });await page.waitForFunction(()=>document.querySelector('.aim-reticle.locked') && !document.querySelector('.aim-reticle').hidden);
  await page.evaluate(()=>__dragonlegend.saveNow());await page.reload();
  await page.waitForFunction(()=>globalThis.__dragonlegend?.playerModel);assert.equal(await page.evaluate(()=>__dragonlegend.game.slot.appearance.kiColor),6);
  assert.equal(await page.evaluate(()=>__dragonlegend.game.slot.appearance.kiColorHex),'#12ab34');
  // Learned training fixture: real menu activates the independent overlay while keeping a beam.
  await page.evaluate(()=>{const a=__dragonlegend;a.game.addXP(1e12);a.game.slot.moves.push('Kaioken');a.game.slot.forms.push('SSJBlue','Kaioken10');a.game.selectForm('SSJBlue');});
  await page.getByRole('button',{name:'Techniques',exact:true}).click();
  await modal.getByRole('combobox',{name:'Kaiyoken intensity',exact:true}).selectOption('10');
  await modal.getByRole('button',{name:'Activate Kaiyoken',exact:true}).click();
  await modal.getByRole('button',{name:'Continue',exact:true}).click();
  await page.waitForFunction(()=>__dragonlegend.playerModel.object3d.getObjectByName('kaioken-overlay-aura')?.visible);
  assert.equal(await page.evaluate(()=>__dragonlegend.game.player.form),'SSJBlue');
  assert.equal(await page.evaluate(()=>__dragonlegend.game.combat.snapshot().technique),'EnergyWave');
  await page.screenshot({path:path.join(root,'out','blue-kaioken.png')});
  await page.keyboard.press('k');await page.waitForFunction(()=>!__dragonlegend.game.kaioken.snapshot().active && !__dragonlegend.playerModel.object3d.getObjectByName('kaioken-overlay-aura')?.visible);
  assert.deepEqual(errors,[]);console.log('Ki/aim browser smoke passed: reticle, lock-on, base aura, colour menu, release cleanup, save/reload and Blue + Kaioken');
}finally{await browser?.close();server.close();}
