// Post-processing: multisampled HDR render, ambient occlusion (high), bloom, then tone mapping
// and colour output. Low quality skips all of it and renders straight to the screen.
import * as THREE from "three";
import { EffectComposer } from "../../vendor/three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "../../vendor/three/addons/postprocessing/RenderPass.js";
import { UnrealBloomPass } from "../../vendor/three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "../../vendor/three/addons/postprocessing/OutputPass.js";
import { GTAOPass } from "../../vendor/three/addons/postprocessing/GTAOPass.js";

export function createPost(renderer, scene, camera, quality) {
  if (!quality.post) return null;
  const size = renderer.getSize(new THREE.Vector2());
  const target = new THREE.WebGLRenderTarget(size.x, size.y, { type: THREE.HalfFloatType, samples: quality.msaa });
  const composer = new EffectComposer(renderer, target);
  composer.setPixelRatio(renderer.getPixelRatio());
  composer.setSize(size.x, size.y);
  composer.addPass(new RenderPass(scene, camera));

  let ao = null;
  if (quality.ao) {
    ao = new GTAOPass(scene, camera, size.x, size.y);
    ao.updateGtaoMaterial({ radius: 0.8, distanceExponent: 1.5, thickness: 1.2, scale: 1.0, samples: 8, distanceFallOff: 1 });
    // half resolution: AO is soft anyway, and this halves its cost
    const fullSetSize = ao.setSize.bind(ao);
    ao.setSize = (w, h) => fullSetSize(Math.max(1, Math.floor(w / 2)), Math.max(1, Math.floor(h / 2)));
    ao.setSize(size.x * renderer.getPixelRatio(), size.y * renderer.getPixelRatio());
    ao.blendIntensity = 0.85;
    // leaf cards, grass, water, clouds and sky would cast square/flat shadows in the AO buffer
    const cache = ao._visibilityCache;
    ao.overrideVisibility = function () {
      scene.traverse((o) => {
        cache.set(o, o.visible);
        if (o.isPoints || o.isLine || o.userData.noAO) o.visible = false;
      });
    };
    composer.addPass(ao);
  }
  const bloom = new UnrealBloomPass(new THREE.Vector2(size.x, size.y), 0.22, 0.55, 0.92);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());

  return {
    composer,
    setSize(w, h, pixelRatio) {
      composer.setPixelRatio(pixelRatio);
      composer.setSize(w, h);
    },
    render(dt) { composer.render(dt); },
    dispose() { composer.dispose(); target.dispose(); ao && ao.dispose(); bloom.dispose(); },
  };
}
