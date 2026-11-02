// Resolve authored NPC/camp points to nearby free ground. Cache callers' static placements.
export function freePosition(zone, point) {
  const half=zone.size/2-1;
  for(const radius of [0,2,4,8,12,20,32,64]) {
    for(let i=0;i<16;i++) {
      const x=point.x+Math.sin(i*Math.PI/8)*radius,z=point.z+Math.cos(i*Math.PI/8)*radius;
      if(Math.abs(x)>half || Math.abs(z)>half)continue;
      const y=point.y ?? zone.heightAt(x,z);
      if(y<-100 || (!Number.isFinite(point.y) && zone.normalAt(x,z).y<.6))continue;
      if(zone.props().near(x,z,.5).some(c=>y<=c.top && Math.hypot(x-c.x,z-c.z)<c.radius+.5))continue;
      return {x,y,z};
    }
  }
  return {x:zone.spawn.x,y:zone.heightAt(zone.spawn.x,zone.spawn.z),z:zone.spawn.z};
}
