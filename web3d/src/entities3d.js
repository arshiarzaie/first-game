import * as THREE from 'three';
import { BIOMES } from './biomes.js';
import { LANE_X } from './soulController.js';

const PORTAL_VORTEX_VERT = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const PORTAL_VORTEX_FRAG = /* glsl */ `
  uniform vec3 uNextZenith;
  uniform vec3 uNextHorizon;
  uniform vec3 uNextGlow;
  uniform float uTime;
  varying vec2 vUv;

  void main() {
    vec2 p = vUv * 2.0 - 1.0;
    // Gothic pointed arch mask (100% tucked inside the 3D CrystalPortal archway!)
    float archTop = 1.0 - pow(abs(p.x), 1.45) * 0.95;
    if (p.y > archTop || abs(p.x) > 0.98) discard;

    float edgeDist = min(archTop - p.y, 0.98 - abs(p.x));
    float rimGlow = smoothstep(0.22, 0.0, edgeDist);

    // Live next-world sunset horizon + swirling dimensional ripples!
    float r = length(p * vec2(1.0, 0.85));
    float ang = atan(p.y, p.x);
    float swirl = sin(r * 12.0 - uTime * 4.5 + ang * 3.0) * 0.5 + 0.5;

    float h = clamp(vUv.y, 0.0, 1.0);
    vec3 vista = mix(uNextHorizon, uNextZenith, smoothstep(0.18, 0.92, h));
    float sun = exp(-length(p - vec2(0.0, -0.15)) * 2.8);
    vista += uNextGlow * sun * 0.85;
    vista += uNextGlow * swirl * 0.18 * (1.0 - r * 0.5);
    vista = mix(vista, uNextGlow * 1.25, rimGlow * 0.68);

    float alpha = smoothstep(0.0, 0.05, edgeDist);
    gl_FragColor = vec4(vista, alpha);
  }
`;

export class Entities3D {
  constructor(scene, propTemplates) {
    this.scene = scene;
    this.templates = propTemplates;

    this.obstacles = [];
    this.orbs = [];
    this.powerups = [];
    this.particles = [];
    this.shockwaves = [];
    this.portal = null;

    // Shared geometries & materials for blazing-fast 120Hz Sun-Orbs & Crystal Blessings!
    this.orbGeo = new THREE.OctahedronGeometry(0.32, 1);
    this.orbMat = new THREE.MeshStandardMaterial({
      color: 0xffe478,
      emissive: 0xffa024,
      emissiveIntensity: 1.35,
      roughness: 0.14,
      metalness: 0.25,
    });
    this.orbHaloGeo = new THREE.SphereGeometry(0.46, 12, 10);
    this.orbHaloMat = new THREE.MeshBasicMaterial({
      color: 0xffc84a,
      transparent: true,
      opacity: 0.26,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    });

    this.relicGeo = new THREE.OctahedronGeometry(0.48, 0);
    this.sparkGeo = new THREE.OctahedronGeometry(0.09, 0);
  }

  clearAll() {
    for (const o of this.obstacles) this.scene.remove(o.mesh);
    for (const o of this.orbs) this.scene.remove(o.mesh);
    for (const p of this.powerups) this.scene.remove(p.mesh);
    for (const pt of this.particles) this.scene.remove(pt.mesh);
    for (const sw of this.shockwaves) this.scene.remove(sw.mesh);
    if (this.portal) this.scene.remove(this.portal.group);

    this.obstacles = [];
    this.orbs = [];
    this.powerups = [];
    this.particles = [];
    this.shockwaves = [];
    this.portal = null;
  }

  tintBiomeProps(biomeId) {
    this.activeBiome = BIOMES[biomeId];
  }

  spawnObstacle(type, lane, z) {
    let tplName = 'ObstacleSpikes';
    if (type === 'arch') tplName = 'ObstacleArch';
    else if (type === 'monolith') tplName = 'ObstacleMonolith';
    else if (type === 'golden_cloud') tplName = 'GoldenCloud';
    else if (type === 'storm_cloud') tplName = 'StormCloud';

    const tpl = this.templates[tplName];
    if (!tpl) return;

    const mesh = tpl.clone(true);
    const biome = this.activeBiome || BIOMES.dusk_hollow;

    // Tint crystal accents per biome while casting real 3D shadows!
    mesh.traverse((n) => {
      if (n.isMesh) {
        n.castShadow = true;
        n.receiveShadow = true;
        if (n.material && n.material.name === 'Prop_AccentCryst') {
          n.material = n.material.clone();
          n.material.color.copy(biome.crystalColor);
          n.material.emissive.copy(biome.crystalEmissive);
        }
      }
    });

    const x = LANE_X[lane];
    let y = 0;
    if (type === 'golden_cloud') {
      y = 0.22;
      mesh.scale.set(1.05, 0.95, 1.05);
    } else if (type === 'storm_cloud') {
      y = 0.92;
      mesh.scale.set(1.12, 1.05, 1.12);
    } else if (type === 'spikes') {
      mesh.scale.setScalar(1.08);
    } else if (type === 'arch') {
      mesh.scale.set(0.96, 1.08, 1.05);
    } else if (type === 'monolith') {
      mesh.scale.setScalar(1.05);
    }

    mesh.position.set(x, y, z);
    this.scene.add(mesh);
    this.obstacles.push({
      type,
      lane,
      x,
      baseY: y,
      z,
      mesh,
      extraSpeed: type === 'storm_cloud' ? 5.5 : 0,
      hit: false,
    });
  }

  spawnOrb(lane, z, y = 0.68) {
    const grp = new THREE.Group();
    const core = new THREE.Mesh(this.orbGeo, this.orbMat);
    const halo = new THREE.Mesh(this.orbHaloGeo, this.orbHaloMat);
    grp.add(core);
    grp.add(halo);
    const x = LANE_X[lane];
    grp.position.set(x, y, z);
    this.scene.add(grp);
    this.orbs.push({ lane, x, y, z, baseY: y, mesh: grp, phase: z * 0.3 });
  }

  spawnPowerUp(kind, lane, z, y = 0.92) {
    const colors = {
      magnet: [0xc97aff, 0x8d2eff],
      multiplier: [0xffdf5e, 0xff9818],
      sneakers: [0x5effc8, 0x12b888],
      solarDash: [0xfff08a, 0xff6a14],
    };
    const [col, em] = colors[kind] || colors.magnet;
    const mat = new THREE.MeshStandardMaterial({
      color: col,
      emissive: em,
      emissiveIntensity: 1.2,
      roughness: 0.12,
      metalness: 0.3,
    });
    const grp = new THREE.Group();
    const gem = new THREE.Mesh(this.relicGeo, mat);
    gem.scale.set(0.85, 1.32, 0.85);
    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(0.62, 0.04, 8, 24),
      new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.75 })
    );
    grp.add(gem);
    grp.add(ring);
    const x = LANE_X[lane];
    grp.position.set(x, y, z);
    this.scene.add(grp);
    this.powerups.push({ kind, lane, x, y, z, mesh: grp, ring });
  }

  spawnTerminalPortal(z, nextBiomeId) {
    if (this.portal) {
      this.scene.remove(this.portal.group);
    }
    const nextB = BIOMES[nextBiomeId];
    const grp = new THREE.Group();

    const tpl = this.templates.CrystalPortal;
    if (tpl) {
      const arch = tpl.clone(true);
      arch.scale.set(1.06, 1.05, 1.06);
      arch.traverse((n) => {
        if (n.isMesh) {
          n.castShadow = true;
          n.receiveShadow = true;
        }
      });
      grp.add(arch);
    }

    // Live 3D Shader Vortex Window tucked strictly inside the 3D Crystal Archway!
    const vortexGeo = new THREE.PlaneGeometry(6.35, 6.15);
    const uniforms = {
      uNextZenith: { value: nextB.skyZenith.clone() },
      uNextHorizon: { value: nextB.skyHorizon.clone() },
      uNextGlow: { value: nextB.sunGlow.clone() },
      uTime: { value: 0 },
    };
    const vortexMat = new THREE.ShaderMaterial({
      vertexShader: PORTAL_VORTEX_VERT,
      fragmentShader: PORTAL_VORTEX_FRAG,
      uniforms,
      transparent: true,
      side: THREE.DoubleSide,
      depthWrite: false,
    });
    const vortexMesh = new THREE.Mesh(vortexGeo, vortexMat);
    vortexMesh.position.set(0, 3.65, 0.02);
    grp.add(vortexMesh);

    // Portal point light illuminating the bridge threshold!
    const pLight = new THREE.PointLight(nextB.sunGlow, 3.2, 18, 1.5);
    pLight.position.set(0, 3.2, 1.5);
    grp.add(pLight);

    grp.position.set(0, 0, z);
    this.scene.add(grp);
    this.portal = { z, nextBiomeId, group: grp, uniforms };
  }

  spawnBurst(x, y, z, colorHex = 0xffd562, count = 14) {
    const mat = new THREE.MeshBasicMaterial({ color: colorHex });
    for (let i = 0; i < count; i++) {
      const m = new THREE.Mesh(this.sparkGeo, mat);
      m.position.set(x, y, z);
      const ang = (i / count) * Math.PI * 2 + Math.random() * 0.4;
      const spd = 2.5 + Math.random() * 5.2;
      const vx = Math.cos(ang) * spd;
      const vy = 2.0 + Math.random() * 4.8;
      const vz = Math.sin(ang) * spd;
      this.scene.add(m);
      this.particles.push({ mesh: m, vx, vy, vz, life: 0.48, maxLife: 0.48 });
    }
  }

  spawnPortalShockwave(z, colorHex = 0xffe89c) {
    const geo = new THREE.TorusGeometry(1.2, 0.14, 12, 36);
    const mat = new THREE.MeshBasicMaterial({
      color: colorHex,
      transparent: true,
      opacity: 0.92,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    });
    const mesh = new THREE.Mesh(geo, mat);
    mesh.position.set(0, 1.8, z);
    this.scene.add(mesh);
    this.shockwaves.push({ mesh, mat, life: 0.65, maxLife: 0.65 });
  }

  update(dt, forwardSpeed, elapsed, soulPos, hasMagnet) {
    // 1. Obstacles
    for (let i = this.obstacles.length - 1; i >= 0; i--) {
      const o = this.obstacles[i];
      o.z += (forwardSpeed + o.extraSpeed) * dt;
      // Smooth emergence from distant horizon (-150m..-128m) — zero pop-in!
      let emergeScale = 1.0;
      if (o.z < -128) {
        emergeScale = Math.max(0.01, 1 - (-128 - o.z) / 26);
      }
      const bob =
        o.type === 'golden_cloud' || o.type === 'storm_cloud'
          ? Math.sin(elapsed * 3.2 + i) * 0.12
          : 0;
      o.mesh.position.set(o.x, o.baseY + bob, o.z);
      o.mesh.visible = emergeScale > 0.02;

      // Remove only AFTER passing cleanly behind the chase camera (z > +9.5m) — zero sudden pop-out!
      if (o.z > 9.5) {
        this.scene.remove(o.mesh);
        this.obstacles.splice(i, 1);
      }
    }

    // 2. Orbs (with real 3D vector magnet attraction!)
    for (let i = this.orbs.length - 1; i >= 0; i--) {
      const orb = this.orbs[i];
      orb.z += forwardSpeed * dt;
      if (hasMagnet && orb.z > -22 && orb.z < 3.5) {
        const pull = 1 - Math.exp(-12 * dt);
        orb.x += (soulPos.x - orb.x) * pull;
        orb.y += (soulPos.y + 0.75 - orb.y) * pull;
      } else {
        orb.y = orb.baseY + Math.sin(elapsed * 4.2 + orb.phase) * 0.1;
      }
      orb.mesh.position.set(orb.x, orb.y, orb.z);
      orb.mesh.rotation.y += dt * 2.8;

      if (orb.z > 9.0) {
        this.scene.remove(orb.mesh);
        this.orbs.splice(i, 1);
      }
    }

    // 3. Crystal Blessing Power-ups
    for (let i = this.powerups.length - 1; i >= 0; i--) {
      const p = this.powerups[i];
      p.z += forwardSpeed * dt;
      p.mesh.position.set(p.x, p.y + Math.sin(elapsed * 3.6 + i) * 0.14, p.z);
      p.mesh.rotation.y += dt * 2.2;
      p.ring.rotation.x += dt * 3.0;
      if (p.z > 9.0) {
        this.scene.remove(p.mesh);
        this.powerups.splice(i, 1);
      }
    }

    // 4. Terminal Abyssal Crystal Portal
    if (this.portal) {
      this.portal.z += forwardSpeed * dt;
      this.portal.uniforms.uTime.value = elapsed;
      this.portal.group.position.z = this.portal.z;
      if (this.portal.z > 12.0) {
        this.scene.remove(this.portal.group);
        this.portal = null;
      }
    }

    // 5. 3D Spark Particles & Dimensional Shockwaves
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const pt = this.particles[i];
      pt.life -= dt;
      if (pt.life <= 0) {
        this.scene.remove(pt.mesh);
        this.particles.splice(i, 1);
        continue;
      }
      pt.vy -= 14 * dt;
      pt.mesh.position.x += pt.vx * dt;
      pt.mesh.position.y += pt.vy * dt;
      pt.mesh.position.z += (pt.vz + forwardSpeed * 0.5) * dt;
      pt.mesh.scale.setScalar(pt.life / pt.maxLife);
    }

    for (let i = this.shockwaves.length - 1; i >= 0; i--) {
      const sw = this.shockwaves[i];
      sw.life -= dt;
      if (sw.life <= 0) {
        this.scene.remove(sw.mesh);
        this.shockwaves.splice(i, 1);
        continue;
      }
      const u = 1 - sw.life / sw.maxLife;
      sw.mesh.scale.setScalar(1 + u * 9.5);
      sw.mesh.position.z += forwardSpeed * dt * 1.4;
      sw.mat.opacity = (1 - u) * 0.85;
    }
  }
}
