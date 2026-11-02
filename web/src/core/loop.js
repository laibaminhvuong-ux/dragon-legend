// Game loop: fixed 60 Hz simulation steps + one render per animation frame.
// update(dt) always gets STEP seconds; render(frameDt, alpha) gets the real frame time and how far
// (0..1) we are between the last step and the next, for smoothing.
export const STEP = 1 / 60;
const MAX_STEPS = 5; // after a long hitch, drop time rather than spiral

export function createLoop({ beforeFrame, update, render }) {
  let acc = 0, last = 0, running = false, raf = 0;
  const stats = { fps: 0, frames: 0, steps: 0 };
  let fpsTime = 0, fpsFrames = 0;

  function frame(now) {
    if (!running) return;
    raf = requestAnimationFrame(frame);
    const frameDt = Math.min(0.25, (now - last) / 1000 || 0);
    last = now;
    acc += frameDt;
    beforeFrame && beforeFrame(frameDt);
    let n = 0;
    while (acc >= STEP && n < MAX_STEPS) {
      update(STEP);
      acc -= STEP;
      n++;
      stats.steps++;
    }
    if (n === MAX_STEPS) acc = 0;
    render(frameDt, acc / STEP);
    stats.frames++;
    fpsFrames++;
    fpsTime += frameDt;
    if (fpsTime >= 0.5) { stats.fps = Math.round(fpsFrames / fpsTime); fpsTime = 0; fpsFrames = 0; }
  }

  return {
    stats,
    start() {
      if (running) return;
      running = true;
      last = performance.now();
      raf = requestAnimationFrame(frame);
    },
    stop() {
      running = false;
      cancelAnimationFrame(raf);
    },
  };
}
