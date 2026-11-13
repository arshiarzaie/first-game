import * as THREE from 'three';
import { BIOMES, buildStoneTextures } from './biomes.js';

const SKY_VERT = /* glsl */ `
  varying vec3 vWorldDir;
  void main() {
    vec4 wp = modelMatrix * vec4(position, 1.0);
    vWorldDir = normalize(position);
    gl_Position = projectionMatrix * viewMatrix * wp;
  }
`;

const SKY_FRAG = /* glsl */ `
  uniform vec3 uZenith;
  uniform vec3 uMid;
  uniform vec3 uHorizon;
  uniform vec3 uSunGlow;
  uniform float uTime;
  varying vec3 vWorldDir;

  float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
  }

  void main() {
    vec3 d = normalize(vWorldDir);
    float h = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
    float above = clamp(d.y, -0.25, 1.0);

    vec3 col;
    if (above >= 0.0) {
      float t1 = smoothstep(0.0, 0.28, above);
      float t2 = smoothstep(0.24, 0.88, above);
      col = mix(uHorizon, uMid, t1);
      col = mix(col, uZenith, t2);
    } else {
      // Deep canyon abyss below horizon!
      float tb = smoothstep(0.0, 0.25, -above);
      col = mix(uHorizon * 0.72, uZenith * 0.35, tb);
    }

    // Warm sunset/moon glow ahead along -Z horizon!
    vec3 sunDir = normalize(vec3(0.08, 0.14, -1.0));
    float sunAmt = max(0.0, dot(d, sunDir));
    col += uSunGlow * pow(sunAmt, 9.0) * 0.42;
    col += uSunGlow * pow(sunAmt, 48.0) * 0.55;

    // Subtle twinkling stars in upper sky dome
    if (d.y > 0.22) {
      vec2 sg = floor(d.xz / max(0.2, d.y + 0.35) * 95.0);
      float st = hash(sg);
      if (st > 0.992) {
        float tw = 0.55 + 0.45 * sin(uTime * 3.2 + st * 90.0);
        col += vec3(0.85, 0.9, 1.0) * tw * smoothstep(0.22, 0.62, d.y) * 0.75;
      }
    }

    gl_FragColor = vec4(col, 1.0);
  }
`;

export class World3D {
  constructor(scene, propTemplates) {
    this.scene = scene;
    this.propTemplates = propTemplates;

    this.chunkLength = 7.5;
    this.chunkCount = 24; // 180m continuous 3D stone bridge!
    this.roadWidth = 6.8; // 3 generous lanes (-2.0, 0.0, +2.0)

    this.currentBiomeId = 'dusk_hollow';
    this.stoneTexCache = {};
    for (const id of Object.keys(BIOMES)) {
      this.stoneTexCache[id] = buildStoneTextures(BIOMES[id]);
    }

    this._buildSkyDome();
    this._buildLighting();
    this._buildMountainRing();
    this._buildFloatingIslands();
    this._buildRoadChunks();

    this.unfurlTimer = 0;
    this.applyBiome('dusk_hollow', 1.0);
  }

  _buildSkyDome() {
    const geo = new THREE.SphereGeometry(260, 40, 28);
    const b = BIOMES.dusk_hollow;
    this.skyUniforms = {
      uZenith: { value: b.skyZenith.clone() },
      uMid: { value: b.skyMid.clone() },
      uHorizon: { value: b.skyHorizon.clone() },
      uSunGlow: { value: b.sunGlow.clone() },
      uTime: { value: 0 },
    };
    const mat = new THREE.ShaderMaterial({
      vertexShader: SKY_VERT,
      fragmentShader: SKY_FRAG,
      uniforms: this.skyUniforms,
      side: THREE.BackSide,
      depthWrite: false,
    });
    this.skyDome = new THREE.Mesh(geo, mat);
    this.scene.add(this.skyDome);
  }

  _buildLighting() {
    const b = BIOMES.dusk_hollow;
    this.hemiLight = new THREE.HemisphereLight(b.hemiSky, b.hemiGround, 1.15);
    this.scene.add(this.hemiLight);

    this.sunLight = new THREE.DirectionalLight(b.sunLightColor, 2.15);
    this.sunLight.position.set(12, 22, 14);
    this.sunLight.castShadow = true;
    this.sunLight.shadow.mapSize.set(2048, 2048);
    this.sunLight.shadow.camera.near = 2;
    this.sunLight.shadow.camera.far = 68;
    const d = 14;
    this.sunLight.shadow.camera.left = -d;
    this.sunLight.shadow.camera.right = d;
    this.sunLight.shadow.camera.top = d * 1.4;
    this.sunLight.shadow.camera.bottom = -d;
    this.sunLight.shadow.bias = -0.0008;
    this.scene.add(this.sunLight);
    this.scene.add(this.sunLight.target);

    this.scene.fog = new THREE.FogExp2(b.fogColor, 0.0092);
  }

  _buildMountainRing() {
    this.mountainGroup = new THREE.Group();
    this.matMtnNear = new THREE.MeshStandardMaterial({
      color: BIOMES.dusk_hollow.mountainNear,
      roughness: 0.92,
      flatShading: true,
    });
    this.matMtnFar = new THREE.MeshStandardMaterial({
      color: BIOMES.dusk_hollow.mountainFar,
      roughness: 0.95,
      flatShading: true,
    });

    // Sculpted 3D mountain peaks around the horizon ring (leaving abyss open right at -Z center!)
    for (let i = 0; i < 26; i++) {
      const ang = (i / 26) * Math.PI * 2;
      const dist = i % 2 === 0 ? 165 : 198;
      const mx = Math.sin(ang) * dist;
      const mz = -Math.cos(ang) * dist;
      // Leave central portal corridor slightly lower so sky glow shines!
      const centerFront = Math.max(0, -Math.cos(ang));
      const h = (24 + ((i * 17) % 28)) * (1.0 - centerFront * 0.42);
      const r = 18 + ((i * 11) % 14);
      const cone = new THREE.Mesh(
        new THREE.ConeGeometry(r, h, 6),
        i % 2 === 0 ? this.matMtnNear : this.matMtnFar
      );
      cone.position.set(mx, -14 + h * 0.42, mz);
      cone.rotation.y = i * 0.7;
      this.mountainGroup.add(cone);
    }
    this.scene.add(this.mountainGroup);
  }

  _buildFloatingIslands() {
    this.islands = [];
    this.skyClouds = [];
    const islandTpl = this.propTemplates.FloatingIsland;
    const cloudTpl = this.propTemplates.GoldenCloud;

    const slots = [
      [-18, 8.5, -36, 1.35],
      [19, 10.5, -48, 1.45],
      [-26, 13.0, -76, 1.85],
      [25, 7.5, -88, 1.65],
      [-16, 11.5, -118, 1.55],
      [21, 14.0, -135, 1.95],
      [-22, 9.0, 14, 1.25],
      [20, 11.0, 18, 1.30],
    ];

    slots.forEach(([x, y, z, sc], idx) => {
      if (islandTpl) {
        const isl = islandTpl.clone(true);
        isl.scale.setScalar(sc);
        isl.position.set(x, y, z);
        this.scene.add(isl);
        this.islands.push({ mesh: isl, baseY: y, baseZ: z, baseX: x, phase: idx * 1.1 });
      }
    });

    for (let i = 0; i < 12; i++) {
      if (cloudTpl) {
        const cl = cloudTpl.clone(true);
        cl.traverse((n) => {
          if (n.isMesh) {
            n.material = new THREE.MeshStandardMaterial({
              color: 0xffe6cc,
              roughness: 0.75,
              transparent: true,
              opacity: 0.65,
            });
          }
        });
        const side = i % 2 === 0 ? -1 : 1;
        const x = side * (14 + (i % 4) * 9);
        const y = -5.5 + (i % 3) * 7.5;
        const z = -15 - i * 12;
        cl.scale.set(3.4, 2.2, 3.0);
        cl.position.set(x, y, z);
        this.scene.add(cl);
        this.skyClouds.push({ mesh: cl, speed: 1.5 + (i % 3) * 0.6, phase: i });
      }
    }
  }

  _buildRoadChunks() {
    const tex = this.stoneTexCache.dusk_hollow;
    this.deckMat = new THREE.MeshStandardMaterial({
      map: tex.map,
      bumpMap: tex.bumpMap,
      bumpScale: 0.08,
      roughness: 0.72,
      metalness: 0.06,
    });
    this.curbMat = new THREE.MeshStandardMaterial({
      color: BIOMES.dusk_hollow.curbColor,
      roughness: 0.58,
      metalness: 0.1,
    });
    this.runeMat = new THREE.MeshStandardMaterial({
      color: BIOMES.dusk_hollow.runeColor,
      emissive: BIOMES.dusk_hollow.runeColor,
      emissiveIntensity: 0.95,
      roughness: 0.25,
    });
    this.underArchMat = new THREE.MeshStandardMaterial({
      color: BIOMES.dusk_hollow.mountainNear,
      roughness: 0.85,
    });

    const deckGeo = new THREE.BoxGeometry(this.roadWidth, 0.55, this.chunkLength);
    const curbGeo = new THREE.BoxGeometry(0.46, 0.34, this.chunkLength);
    const runeGeo = new THREE.BoxGeometry(0.11, 0.05, this.chunkLength);
    const pierGeo = new THREE.BoxGeometry(this.roadWidth * 0.76, 3.6, 1.35);

    this.chunks = [];
    const pillarTpl = this.propTemplates.CorridorPillar;

    for (let i = 0; i < this.chunkCount; i++) {
      const grp = new THREE.Group();

      const deck = new THREE.Mesh(deckGeo, this.deckMat);
      deck.position.y = -0.275;
      deck.receiveShadow = true;
      grp.add(deck);

      for (const side of [-1, 1]) {
        const curb = new THREE.Mesh(curbGeo, this.curbMat);
        curb.position.set(side * (this.roadWidth * 0.5 + 0.16), 0.11, 0);
        curb.castShadow = true;
        curb.receiveShadow = true;
        grp.add(curb);
      }

      // Glowing 3D lane divider rune channels between the 3 lanes (x = -1.08, +1.08)
      for (const lx of [-1.08, 1.08]) {
        const rune = new THREE.Mesh(runeGeo, this.runeMat);
        rune.position.set(lx, 0.015, 0);
        grp.add(rune);
      }

      // Sculptural viaduct support pier descending into the abyss every 2nd chunk
      if (i % 2 === 0) {
        const pier = new THREE.Mesh(pierGeo, this.underArchMat);
        pier.position.set(0, -2.25, 0);
        grp.add(pier);

        if (pillarTpl) {
          for (const side of [-1, 1]) {
            const pil = pillarTpl.clone(true);
            pil.scale.setScalar(0.72);
            pil.position.set(side * (this.roadWidth * 0.5 + 0.35), 0.26, 0);
            pil.traverse((n) => {
              if (n.isMesh) n.castShadow = true;
            });
            grp.add(pil);
          }
        }
      }

      const z = 12.0 - i * this.chunkLength;
      grp.position.set(0, 0, z);
      this.scene.add(grp);
      this.chunks.push({ group: grp, z });
    }
  }

  applyBiome(biomeId, triggerUnfurl = false) {
    this.currentBiomeId = biomeId;
    const b = BIOMES[biomeId];
    const tex = this.stoneTexCache[biomeId];

    this.skyUniforms.uZenith.value.copy(b.skyZenith);
    this.skyUniforms.uMid.value.copy(b.skyMid);
    this.skyUniforms.uHorizon.value.copy(b.skyHorizon);
    this.skyUniforms.uSunGlow.value.copy(b.sunGlow);

    this.scene.fog.color.copy(b.fogColor);
    this.sunLight.color.copy(b.sunLightColor);
    this.hemiLight.color.copy(b.hemiSky);
    this.hemiLight.groundColor.copy(b.hemiGround);

    this.deckMat.map = tex.map;
    this.deckMat.bumpMap = tex.bumpMap;
    this.deckMat.needsUpdate = true;

    this.curbMat.color.copy(b.curbColor);
    this.runeMat.color.copy(b.runeColor);
    this.runeMat.emissive.copy(b.runeColor);
    this.matMtnNear.color.copy(b.mountainNear);
    this.matMtnFar.color.copy(b.mountainFar);
    this.underArchMat.color.copy(b.mountainNear);

    if (triggerUnfurl) {
      this.unfurlTimer = 1.15;
    }
  }

  reset() {
    for (let i = 0; i < this.chunks.length; i++) {
      const z = 12.0 - i * this.chunkLength;
      this.chunks[i].z = z;
      this.chunks[i].group.position.set(0, 0, z);
      this.chunks[i].group.visible = true;
    }
    this.unfurlTimer = 0;
  }

  /**
   * Advances the 3D chunked stone bridge & sky islands!
   * @param {number|null} terminalPortalZ If an Abyssal Crystal Portal is active
   *   ahead at `terminalPortalZ` (e.g. -60m), ALL road chunks beyond
   *   `terminalPortalZ` are hidden so NOTHING exists behind the portal!
   */
  update(dt, forwardSpeed, elapsed, terminalPortalZ = null) {
    this.skyUniforms.uTime.value = elapsed;

    if (this.unfurlTimer > 0) {
      this.unfurlTimer = Math.max(0, this.unfurlTimer - dt);
    }

    const totalSpan = this.chunkCount * this.chunkLength;

    for (const ch of this.chunks) {
      ch.z += forwardSpeed * dt;
      if (ch.z > 16.5) {
        ch.z -= totalSpan;
      }

      // TERMINAL PORTAL CUTOFF (`پشتش هیچی نباشد`!):
      // Road chunks exist along -Z; anything deeper than `terminalPortalZ`
      // (i.e. `ch.z < terminalPortalZ - 0.5`) terminates cleanly into the cosmic abyss!
      if (terminalPortalZ !== null && ch.z < terminalPortalZ - 0.8) {
        ch.group.visible = false;
        continue;
      }
      ch.group.visible = true;

      // Smooth遠 emergence at far horizon (-150m..-125m) + dramatic new-world unfurl!
      let dropY = 0;
      if (ch.z < -130) {
        const tFar = Math.min(1, (-130 - ch.z) / 34);
        dropY -= tFar * tFar * 5.5;
      }
      if (this.unfurlTimer > 0 && ch.z < -8) {
        const uProg = 1.0 - this.unfurlTimer / 1.15; // 0..1
        const waveFrontZ = -8 - uProg * 155;
        if (ch.z < waveFrontZ) {
          const distAhead = Math.min(1, (waveFrontZ - ch.z) / 32);
          dropY -= distAhead * distAhead * 11.0;
        }
      }
      ch.group.position.set(0, dropY, ch.z);
    }

    // Gentle parallax motion on 3D Floating Sky Islands & Puffy 3D Clouds
    for (const isl of this.islands) {
      isl.mesh.position.z += forwardSpeed * dt * 0.14;
      if (isl.mesh.position.z > 28) {
        isl.mesh.position.z -= 175;
      }
      isl.mesh.position.y = isl.baseY + Math.sin(elapsed * 1.1 + isl.phase) * 0.85;
      isl.mesh.rotation.y += dt * 0.08;
    }

    for (const cl of this.skyClouds) {
      cl.mesh.position.z += (forwardSpeed * 0.22 + cl.speed) * dt;
      if (cl.mesh.position.z > 24) {
        cl.mesh.position.z -= 165;
      }
    }
  }
}
