import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';

import { BIOMES, WORLD_ORDER, nextBiomeId } from './biomes.js';
import { World3D } from './world3d.js';
import { SoulController } from './soulController.js';
import { Entities3D } from './entities3d.js';
import { Audio3D } from './audio3d.js';

const STORAGE_KEY = 'soul_dusk_run_3d_save_v1';

function loadSave() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return {
    bestScore: 0,
    totalSuns: 0,
    selectedBiome: 'dusk_hollow',
    quality: 'high',
    sound: true,
  };
}

function writeSave(save) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(save));
  } catch (_) {}
}

class SoulDuskRun3DApp {
  constructor() {
    this.save = loadSave();
    this.canvas = document.getElementById('webgl-canvas');

    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      // `antialias` is deliberately false. Every draw lands in EffectComposer's
      // offscreen targets, so the renderer's own MSAA framebuffer would be
      // allocated and never read. Real MSAA is configured on the composer's
      // multisampled render target in _buildComposer().
      antialias: false,
      stencil: false,
      powerPreference: 'high-performance',
    });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.08;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(56, window.innerWidth / window.innerHeight, 0.25, 320);

    this._buildComposer(4);

    this.audio = new Audio3D();
    this.audio.setEnabled(this.save.sound !== false);

    this.state = 'LOADING'; // LOADING | TITLE | INTRO | RUNNING | PAUSED | GAMEOVER
    this.elapsed = 0;
    this.lastFrameMs = performance.now();

    this.camPos = new THREE.Vector3(0, 2.8, 4.2);
    this.camLook = new THREE.Vector3(0, 2.6, -2.0);
    this.camFov = 56;
    this.shakeTimer = 0;
    this.shakeAmp = 0;
    this.warpFovBoost = 0;

    this.applyQuality(this.save.quality || 'high');
    window.addEventListener('resize', () => this.onResize());
    this.onResize();

    this._bindUI();
    this._bindInputs();
    this._loadAssetsAndBoot();
  }

  /**
   * (Re)build the post-processing chain.
   *
   * `samples > 0` gives genuine hardware MSAA: three renders the scene into a
   * multisampled target and resolves it on read, which is the only way to get
   * AA once EffectComposer owns the framebuffer. HalfFloat keeps the scene
   * linear/HDR so UnrealBloomPass and ACES tone mapping work with real
   * highlight headroom instead of clipped 8-bit values.
   */
  _buildComposer(samples) {
    // Free the previous chain's GPU targets before allocating new ones --
    // quality toggles rebuild this and would otherwise leak both targets.
    if (this.composer) this.composer.dispose();
    this._msaaSamples = samples;
    const w = window.innerWidth;
    const h = window.innerHeight;
    const rt = new THREE.WebGLRenderTarget(w, h, {
      samples,
      type: THREE.HalfFloatType,
    });
    rt.texture.name = 'SoulComposer.rt1';
    this.composer = new EffectComposer(this.renderer, rt);
    this.renderPass = new RenderPass(this.scene, this.camera);
    this.bloomPass = new UnrealBloomPass(new THREE.Vector2(w, h), 0.38, 0.62, 0.78);
    this.outputPass = new OutputPass();
    this.composer.addPass(this.renderPass);
    this.composer.addPass(this.bloomPass);
    this.composer.addPass(this.outputPass);
    // The composer tracks its OWN pixel ratio; it must follow the renderer or
    // the whole scene renders at CSS resolution and is upscaled to the panel.
    this.composer.setPixelRatio(this.renderer.getPixelRatio());
    this.composer.setSize(w, h);
  }

  applyQuality(q) {
    this.save.quality = q;
    writeSave(this.save);
    const maxDpr = q === 'high' ? 2.0 : 1.25;
    const dpr = Math.min(window.devicePixelRatio || 1, maxDpr);
    this.renderer.setPixelRatio(dpr);
    this.renderer.shadowMap.enabled = q === 'high';
    const samples = q === 'high' ? 4 : 0;
    if (this._msaaSamples !== samples) {
      this._buildComposer(samples); // re-syncs composer DPR and size
    } else {
      this.composer.setPixelRatio(dpr);
    }
    this.bloomPass.enabled = q === 'high';
    const btn = document.getElementById('btn-quality');
    if (btn) btn.textContent = q.toUpperCase();
  }

  onResize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.camera.aspect = w / h;
    // Slightly wider vertical FOV on tall narrow phones so all 3 lanes breathe generously!
    this.baseFov = w / h < 0.62 ? 62 : 56;
    this.camera.fov = this.baseFov;
    this.camera.updateProjectionMatrix();
    // devicePixelRatio can change (zoom, display change) -- keep both the
    // renderer and the composer on the same ratio.
    const maxDpr = (this.save.quality || 'high') === 'high' ? 2.0 : 1.25;
    const dpr = Math.min(window.devicePixelRatio || 1, maxDpr);
    this.renderer.setPixelRatio(dpr);
    this.composer.setPixelRatio(dpr);
    this.renderer.setSize(w, h, false);
    this.composer.setSize(w, h);
  }

  async _loadAssetsAndBoot() {
    const fill = document.getElementById('loading-bar-fill');
    const status = document.getElementById('loading-status');
    const loader = new GLTFLoader();

    const loadGlb = (url, progBase, progSpan) =>
      new Promise((resolve, reject) => {
        loader.load(
          url,
          (gltf) => resolve(gltf),
          (ev) => {
            if (ev.total > 0 && fill) {
              const p = progBase + (ev.loaded / ev.total) * progSpan;
              fill.style.width = `${Math.round(p * 100)}%`;
            }
          },
          reject
        );
      });

    try {
      status.textContent = 'Loading Rigged 3D Soul (Blender 5 GLB)…';
      const soulGltf = await loadGlb('./models/soul.glb', 0.1, 0.55);

      status.textContent = 'Loading 3D Fantasy Architecture & Portals…';
      const propsGltf = await loadGlb('./models/props.glb', 0.65, 0.32);

      const propTemplates = {};
      for (const child of propsGltf.scene.children) {
        propTemplates[child.name] = child;
      }

      this.world = new World3D(this.scene, propTemplates);
      this.soul = new SoulController(this.scene, soulGltf);
      this.entities = new Entities3D(this.scene, propTemplates);

      if (fill) fill.style.width = '100%';
      this.enterTitleScreen();

      document.getElementById('loading-overlay').classList.remove('active');
      requestAnimationFrame((t) => this._loop(t));
    } catch (err) {
      console.error('3D Asset load error:', err);
      status.textContent = 'Failed to load 3D models: ' + (err?.message || err);
    }
  }

  enterTitleScreen() {
    this.state = 'TITLE';
    const biomeId = BIOMES[this.save.selectedBiome] ? this.save.selectedBiome : 'dusk_hollow';
    this.activeBiomeId = biomeId;

    this.entities.clearAll();
    this.entities.tintBiomeProps(biomeId);
    this.world.reset();
    this.world.applyBiome(biomeId, false);
    this.soul.resetToTitle();

    this.camPos.set(0, 2.82, 3.85);
    this.camLook.set(0, 2.75, -4.0);

    document.getElementById('title-overlay').classList.add('active');
    document.getElementById('hud-overlay').classList.add('hidden');
    document.getElementById('pause-modal').classList.add('hidden');
    document.getElementById('gameover-modal').classList.add('hidden');

    this._refreshTitleStats();
  }

  _refreshTitleStats() {
    document.getElementById('title-suns').textContent = String(this.save.totalSuns);
    document.getElementById('title-best').textContent = String(Math.floor(this.save.bestScore));
    document.getElementById('title-realm-chip').textContent = BIOMES[this.activeBiomeId].name;
  }

  startRunFromTitle() {
    if (this.state !== 'TITLE') return;
    this.state = 'INTRO';
    this.audio.unlock();
    this.audio.ui();
    document.getElementById('title-overlay').classList.remove('active');
    document.getElementById('hud-overlay').classList.remove('hidden');
    document.getElementById('hud-hint').style.opacity = '1';

    this._initRunMetrics();
    this.soul.startIntroDive();
  }

  restartRunImmediate() {
    this.audio.unlock();
    this.audio.ui();
    document.getElementById('gameover-modal').classList.add('hidden');
    document.getElementById('pause-modal').classList.add('hidden');
    document.getElementById('hud-overlay').classList.remove('hidden');

    const biomeId = this.save.selectedBiome || 'dusk_hollow';
    this.activeBiomeId = biomeId;
    this.entities.clearAll();
    this.entities.tintBiomeProps(biomeId);
    this.world.reset();
    this.world.applyBiome(biomeId, false);

    this.soul.resetToTitle();
    this._initRunMetrics();
    this.state = 'INTRO';
    this.soul.startIntroDive();
  }

  _initRunMetrics() {
    this.distance = 0;
    this.score = 0;
    this.runSuns = 0;
    this.forwardSpeed = 20.5;
    this.maxSpeed = 38.0;
    this.nextWaveDist = 36;
    this.nextPortalDist = 480; // ~20s per realm for thrilling Abyssal Portal transitions!
    this.stumbleGrace = 0;
    this.shieldCooldown = 0;
    this.powerUps = {
      shield: false,
      shieldTimer: 0,
      magnet: 0,
      multiplier: 0,
      sneakers: 0,
      solarDash: 0,
    };
    this._updateHud();
  }

  triggerShake(amp, dur = 0.32) {
    this.shakeAmp = Math.max(this.shakeAmp, amp);
    this.shakeTimer = Math.max(this.shakeTimer, dur);
  }

  triggerFlash() {
    const fl = document.getElementById('screen-flash');
    fl.style.transition = 'none';
    fl.style.opacity = '0.88';
    requestAnimationFrame(() => {
      fl.style.transition = 'opacity 0.55s ease-out';
      fl.style.opacity = '0';
    });
  }

  showPortalBanner(worldName) {
    const banner = document.getElementById('portal-banner');
    document.getElementById('portal-world-name').textContent = worldName;
    banner.classList.remove('hidden');
    banner.style.animation = 'none';
    void banner.offsetWidth;
    banner.style.animation = '';
    clearTimeout(this._bannerTimeout);
    this._bannerTimeout = setTimeout(() => banner.classList.add('hidden'), 2250);
  }

  activateSolarShield() {
    if (this.state !== 'RUNNING') return;
    if (this.powerUps.shield || this.shieldCooldown > 0) return;
    this.powerUps.shield = true;
    this.powerUps.shieldTimer = 10.0;
    this.audio.shield();
    this.entities.spawnBurst(this.soul.x, this.soul.y + 0.4, 0, 0xffdf6e, 14);
  }

  _spawnNextWave() {
    // Do NOT spawn any obstacles behind an active Terminal Abyssal Crystal Portal!
    if (this.entities.portal) return;

    // Check if it is time to spawn the Terminal Abyssal Crystal Portal!
    if (this.distance >= this.nextPortalDist) {
      const nextId = nextBiomeId(this.activeBiomeId);
      this.entities.spawnTerminalPortal(-125, nextId);
      // Guiding golden trail of Sun-Orbs leading straight into the Portal doorway!
      for (let k = 0; k < 6; k++) {
        this.entities.spawnOrb(1, -92 - k * 5.0, 0.78);
      }
      this.nextPortalDist = this.distance + 520;
      this.nextWaveDist = this.distance + 80;
      return;
    }

    const spawnZ = -132;
    const diff = Math.min(1, (this.forwardSpeed - 20.5) / 17.5);
    const lanes = [0, 1, 2];
    // Guarantee at least 1 completely open or maneuverable safe lane!
    const safeLane = lanes[Math.floor(Math.random() * 3)];
    const types = ['spikes', 'arch', 'monolith', 'golden_cloud', 'storm_cloud'];

    for (const lane of lanes) {
      if (lane === safeLane) {
        // Spawn a guiding ribbon of 3D Sun-Orbs (plus occasional Power-Up Crystal!)
        if (Math.random() < 0.88) {
          for (let k = 0; k < 4; k++) {
            this.entities.spawnOrb(lane, spawnZ + 6 - k * 3.2, 0.68);
          }
        }
        if (Math.random() < 0.14) {
          const kinds = ['magnet', 'multiplier', 'sneakers', 'solarDash'];
          const kind = kinds[Math.floor(Math.random() * kinds.length)];
          this.entities.spawnPowerUp(kind, lane, spawnZ - 8, 0.95);
        }
        continue;
      }

      if (Math.random() < 0.48 + diff * 0.34) {
        const r = Math.random();
        let t = types[0];
        if (r < 0.30) t = 'spikes';
        else if (r < 0.56) t = 'arch';
        else if (r < 0.78) t = 'monolith';
        else if (r < 0.90) t = 'golden_cloud';
        else t = 'storm_cloud';

        this.entities.spawnObstacle(t, lane, spawnZ);

        // Rewarding skill-line orbs: arc OVER spikes/golden_cloud, or low line UNDER stone arch!
        if (t === 'spikes') {
          for (let k = -2; k <= 2; k++) {
            const arcY = 0.75 + (1 - (k * k) / 5) * 1.45;
            this.entities.spawnOrb(lane, spawnZ + k * 2.4, arcY);
          }
        } else if (t === 'arch') {
          for (let k = -1; k <= 1; k++) {
            this.entities.spawnOrb(lane, spawnZ + k * 2.5, 0.45);
          }
        } else if (t === 'golden_cloud') {
          for (let k = 1; k <= 4; k++) {
            this.entities.spawnOrb(lane, spawnZ - k * 3.4, 1.4 + Math.sin((k / 4) * Math.PI) * 2.1);
          }
        }
      }
    }

    const minSpacing = Math.max(19, 27 - diff * 6.5);
    this.nextWaveDist = this.distance + minSpacing;
  }

  _checkCollisions() {
    const sx = this.soul.x;
    const sy = this.soul.y;

    // 1. Collect 3D Sun-Orbs
    for (let i = this.entities.orbs.length - 1; i >= 0; i--) {
      const orb = this.entities.orbs[i];
      if (
        Math.abs(orb.z) < 1.15 &&
        Math.abs(orb.x - sx) < 0.92 &&
        Math.abs(orb.y - (sy + 0.72)) < 1.15
      ) {
        this.runSuns += 1;
        this.save.totalSuns += 1;
        const mult = this.powerUps.multiplier > 0 ? 2 : 1;
        this.score += 15 * mult;
        this.entities.spawnBurst(orb.x, orb.y, orb.z, 0xffe066, 7);
        this.audio.orb();
        this.scene.remove(orb.mesh);
        this.entities.orbs.splice(i, 1);
      }
    }

    // 2. Collect 3D Crystal Blessing Power-Ups
    for (let i = this.entities.powerups.length - 1; i >= 0; i--) {
      const p = this.entities.powerups[i];
      if (
        Math.abs(p.z) < 1.25 &&
        Math.abs(p.x - sx) < 0.95 &&
        Math.abs(p.y - (sy + 0.75)) < 1.25
      ) {
        if (p.kind === 'magnet') this.powerUps.magnet = 10.0;
        else if (p.kind === 'multiplier') this.powerUps.multiplier = 10.0;
        else if (p.kind === 'sneakers') this.powerUps.sneakers = 10.0;
        else if (p.kind === 'solarDash') this.powerUps.solarDash = 5.0;

        this.entities.spawnBurst(p.x, p.y, p.z, 0xc98aff, 16);
        this.audio.powerup();
        this.scene.remove(p.mesh);
        this.entities.powerups.splice(i, 1);
      }
    }

    // 3. Sensational Terminal Abyssal Crystal Portal Breach!
    if (this.entities.portal && this.entities.portal.z >= -0.8 && this.entities.portal.z <= 2.5) {
      const nextId = this.entities.portal.nextBiomeId;
      this.activeBiomeId = nextId;
      this.entities.tintBiomeProps(nextId);

      // Clear remaining old-world obstacles & unfurl the new 3D stone causeway!
      for (const o of this.entities.obstacles) this.scene.remove(o.mesh);
      this.entities.obstacles = [];

      this.scene.remove(this.entities.portal.group);
      this.entities.portal = null;

      this.world.applyBiome(nextId, true);
      this.entities.spawnPortalShockwave(-1.5, BIOMES[nextId].sunGlow.getHex());
      this.entities.spawnBurst(sx, sy + 1.0, -0.5, 0xfff0a8, 24);
      this.warpFovBoost = 18.0;
      this.triggerShake(0.32, 0.45);
      this.triggerFlash();
      this.showPortalBanner(BIOMES[nextId].name);
      this.audio.portal();
      this.score += 150;
      return;
    }

    // Invulnerable while soaring in Solar Dash!
    if (this.powerUps.solarDash > 0) return;

    // 4. 3D Obstacle Clearance & Collisions
    for (let i = this.entities.obstacles.length - 1; i >= 0; i--) {
      const o = this.entities.obstacles[i];
      if (o.hit) continue;
      if (Math.abs(o.z) > 0.92) continue;

      const dx = Math.abs(o.x - sx);
      if (dx > 0.96) continue;

      // Golden Bounce-Cloud launches Soul sky-high!
      if (o.type === 'golden_cloud') {
        o.hit = true;
        this.soul.triggerCloudBounce();
        this.audio.cloud();
        this.entities.spawnBurst(o.x, o.baseY + 0.4, o.z, 0xffe47a, 18);
        this.triggerShake(0.16, 0.22);
        continue;
      }

      // Check true 3D vertical clearance!
      if (o.type === 'spikes' && sy > 0.92) continue; // Cleared over crystal spikes!
      if (o.type === 'arch' && this.soul.isSliding && sy < 0.35) continue; // Rolled cleanly under 3D arch!
      if (o.type === 'arch' && sy > 2.25) continue; // Soared above arch!
      if (o.type === 'storm_cloud' && sy > 1.85) continue; // Soared above storm cloud!
      if (o.type === 'monolith' && sy > 3.1) continue;

      o.hit = true;

      // Grazing edge-brush -> Stumble recovery instead of unfair instant death!
      if (dx > 0.62 && this.stumbleGrace <= 0) {
        this.stumbleGrace = 2.4;
        this.soul.triggerStumble();
        this.audio.stumble();
        this.triggerShake(0.22, 0.28);
        this.entities.spawnBurst(sx, sy + 0.7, 0, 0xff9b54, 12);
        continue;
      }

      // Solar Shield absorbs full crash!
      if (this.powerUps.shield) {
        this.powerUps.shield = false;
        this.powerUps.shieldTimer = 0;
        this.shieldCooldown = 10.0;
        this.triggerShake(0.30, 0.35);
        this.triggerFlash();
        this.audio.shieldBreak();
        this.entities.spawnBurst(o.x, 1.0, o.z, 0xffd866, 22);
        this.scene.remove(o.mesh);
        this.entities.obstacles.splice(i, 1);
        continue;
      }

      // Fatal impact -> Game Over!
      this._onGameOver();
      return;
    }
  }

  _onGameOver() {
    this.state = 'GAMEOVER';
    this.audio.crash();
    this.audio.gameOver();
    this.soul.triggerStumble();
    this.triggerShake(0.42, 0.48);
    this.entities.spawnBurst(this.soul.x, this.soul.y + 0.8, 0, 0xff7a45, 22);

    if (this.score > this.save.bestScore) {
      this.save.bestScore = Math.floor(this.score);
    }
    writeSave(this.save);

    document.getElementById('go-score').textContent = String(Math.floor(this.score));
    document.getElementById('go-best').textContent = String(Math.floor(this.save.bestScore));
    document.getElementById('go-suns').textContent = `+${this.runSuns}`;
    document.getElementById('gameover-modal').classList.remove('hidden');
  }

  _updatePowerUpTimers(dt) {
    if (this.shieldCooldown > 0) this.shieldCooldown = Math.max(0, this.shieldCooldown - dt);
    if (this.stumbleGrace > 0) this.stumbleGrace = Math.max(0, this.stumbleGrace - dt);

    if (this.powerUps.shield) {
      this.powerUps.shieldTimer -= dt;
      if (this.powerUps.shieldTimer <= 0) {
        this.powerUps.shield = false;
        this.shieldCooldown = 8.0;
      }
    }
    for (const k of ['magnet', 'multiplier', 'sneakers', 'solarDash']) {
      if (this.powerUps[k] > 0) {
        this.powerUps[k] = Math.max(0, this.powerUps[k] - dt);
      }
    }
  }

  _updateCamera(dt) {
    let targetPos;
    let targetLook;

    if (this.state === 'TITLE') {
      targetPos = new THREE.Vector3(
        Math.sin(this.elapsed * 0.7) * 0.22,
        2.78 + Math.sin(this.elapsed * 1.4) * 0.06,
        3.75
      );
      targetLook = new THREE.Vector3(0, 2.72, -3.5);
    } else if (this.state === 'INTRO') {
      const u = this.soul.introProgress;
      const s = u * u * (3 - 2 * u);
      // Orbit smoothly from close-up front of Soul -> low behind-character 3D chase angle!
      const orbitAngle = (1 - s) * Math.PI * 0.0;
      targetPos = new THREE.Vector3(
        Math.sin(s * Math.PI) * 1.35 * (1 - s * 0.6),
        THREE.MathUtils.lerp(2.78, 3.15, s),
        THREE.MathUtils.lerp(3.75, 5.95, s)
      );
      targetLook = new THREE.Vector3(
        0,
        THREE.MathUtils.lerp(2.72, 1.35, s),
        THREE.MathUtils.lerp(-3.5, -14.0, s)
      );
      void orbitAngle;
    } else {
      // Dynamic low over-the-shoulder 3D Chase Camera!
      const highAir = Math.max(0, this.soul.y);
      targetPos = new THREE.Vector3(
        this.soul.x * 0.52,
        3.12 + highAir * 0.42,
        5.95 + (this.powerUps.solarDash > 0 ? 1.1 : 0)
      );
      targetLook = new THREE.Vector3(
        this.soul.x * 0.34,
        1.32 + highAir * 0.28,
        -15.0
      );
    }

    const camLerp = 1 - Math.exp(-10.5 * dt);
    this.camPos.lerp(targetPos, camLerp);
    this.camLook.lerp(targetLook, camLerp);

    // Camera impact shake & dimensional portal FOV warp!
    let sx = 0;
    let sy = 0;
    if (this.shakeTimer > 0) {
      this.shakeTimer = Math.max(0, this.shakeTimer - dt);
      const a = this.shakeAmp * (this.shakeTimer / 0.45);
      sx = Math.sin(this.elapsed * 65) * a;
      sy = Math.cos(this.elapsed * 53) * a * 0.75;
    }

    if (this.warpFovBoost > 0.05) {
      this.warpFovBoost *= Math.exp(-4.5 * dt);
    } else {
      this.warpFovBoost = 0;
    }
    const desiredFov =
      this.baseFov + this.warpFovBoost + (this.powerUps.solarDash > 0 ? 8 : 0);
    if (Math.abs(this.camera.fov - desiredFov) > 0.05) {
      this.camera.fov += (desiredFov - this.camera.fov) * (1 - Math.exp(-9 * dt));
      this.camera.updateProjectionMatrix();
    }

    this.camera.position.set(this.camPos.x + sx, this.camPos.y + sy, this.camPos.z);
    this.camera.lookAt(this.camLook);

    // Keep DirectionalLight shadow frustum centered on Soul!
    if (this.world && this.soul) {
      this.world.sunLight.position.set(this.soul.x + 10, 22, 12);
      this.world.sunLight.target.position.set(this.soul.x, 0, -6);
    }
  }

  _updateHud() {
    const mult = this.powerUps.multiplier > 0 ? 2 : 1;
    document.getElementById('hud-score').textContent = String(Math.floor(this.score));
    document.getElementById('hud-suns').textContent = String(this.save.totalSuns);
    document.getElementById('hud-mult').textContent = `x${mult}`;

    const container = document.getElementById('hud-powerups');
    const chips = [];
    if (this.powerUps.shield) {
      chips.push(`SOLAR SHIELD ${Math.ceil(this.powerUps.shieldTimer)}s`);
    }
    if (this.powerUps.magnet > 0) {
      chips.push(`MAGNET ${Math.ceil(this.powerUps.magnet)}s`);
    }
    if (this.powerUps.multiplier > 0) {
      chips.push(`2X SCORE ${Math.ceil(this.powerUps.multiplier)}s`);
    }
    if (this.powerUps.sneakers > 0) {
      chips.push(`SKY LEAP ${Math.ceil(this.powerUps.sneakers)}s`);
    }
    if (this.powerUps.solarDash > 0) {
      chips.push(`SOLAR DASH ${Math.ceil(this.powerUps.solarDash)}s`);
    }
    container.innerHTML = chips.map((t) => `<div class="power-chip">${t}</div>`).join('');

    if (this.distance > 90) {
      document.getElementById('hud-hint').style.opacity = '0';
    }
  }

  _loop(nowMs) {
    requestAnimationFrame((t) => this._loop(t));
    const rawDt = (nowMs - this.lastFrameMs) / 1000;
    this.lastFrameMs = nowMs;
    const dt = Math.min(0.05, Math.max(0.001, rawDt));

    if (this.state !== 'PAUSED') {
      this.elapsed += dt;
    }

    if (this.state === 'TITLE') {
      this.world.update(dt, 4.5, this.elapsed, null);
      this.soul.updateTitleHover(dt, this.elapsed);
      this._updateCamera(dt);
    } else if (this.state === 'INTRO') {
      this.world.update(dt, 14.0, this.elapsed, null);
      const done = this.soul.updateIntroDive(dt);
      this._updateCamera(dt);
      if (done) {
        this.state = 'RUNNING';
        this.triggerShake(0.18, 0.25);
        this.entities.spawnBurst(0, 0.15, 0, 0xffda6e, 14);
      }
    } else if (this.state === 'RUNNING') {
      const dashMult = this.powerUps.solarDash > 0 ? 1.55 : 1.0;
      this.forwardSpeed = Math.min(this.maxSpeed, this.forwardSpeed + 0.36 * dt);
      const effSpeed = this.forwardSpeed * dashMult;

      this.distance += effSpeed * dt;
      const mult = this.powerUps.multiplier > 0 ? 2 : 1;
      this.score += effSpeed * dt * 1.45 * mult;

      this._updatePowerUpTimers(dt);

      if (this.distance >= this.nextWaveDist) {
        this._spawnNextWave();
      }

      const terminalPortalZ = this.entities.portal ? this.entities.portal.z : null;
      this.world.update(dt, effSpeed, this.elapsed, terminalPortalZ);
      this.soul.updateGameplay(dt, effSpeed, this.powerUps);
      this.entities.update(
        dt,
        effSpeed,
        this.elapsed,
        this.soul.root.position,
        this.powerUps.magnet > 0
      );

      // Landing thud is raised by the controller and consumed here.
      if (this.soul.justLanded) {
        this.soul.justLanded = false;
        this.audio.land();
      }

      this._checkCollisions();
      this._updateCamera(dt);
      this._updateHud();
    } else if (this.state === 'GAMEOVER') {
      this.soul.mixer.update(dt);
      this.entities.update(dt, 0, this.elapsed, this.soul.root.position, false);
      this._updateCamera(dt);
    }

    if (this.bloomPass.enabled) {
      this.composer.render();
    } else {
      this.renderer.render(this.scene, this.camera);
    }
  }

  _bindUI() {
    document.getElementById('btn-play').addEventListener('click', () => this.startRunFromTitle());
    document.getElementById('soul-tap-zone').addEventListener('click', () => this.startRunFromTitle());

    document.getElementById('btn-pause').addEventListener('click', () => {
      if (this.state === 'RUNNING') {
        this.state = 'PAUSED';
        document.getElementById('pause-modal').classList.remove('hidden');
      }
    });
    document.getElementById('btn-resume').addEventListener('click', () => {
      if (this.state === 'PAUSED') {
        this.state = 'RUNNING';
        this.lastFrameMs = performance.now();
        document.getElementById('pause-modal').classList.add('hidden');
      }
    });
    document.getElementById('btn-pause-home').addEventListener('click', () => this.enterTitleScreen());
    document.getElementById('btn-retry').addEventListener('click', () => this.restartRunImmediate());
    document.getElementById('btn-go-home').addEventListener('click', () => this.enterTitleScreen());

    // Procedural WebAudio sound toggle
    const soundBtn = document.getElementById('btn-sound');
    const _syncSoundBtn = () => {
      const on = this.save.sound !== false;
      soundBtn.textContent = on ? '🔊' : '🔇';
      soundBtn.setAttribute('aria-label', on ? 'Mute sound' : 'Unmute sound');
    };
    soundBtn.addEventListener('click', () => {
      this.audio.unlock();
      this.save.sound = !(this.save.sound !== false);
      writeSave(this.save);
      this.audio.setEnabled(this.save.sound);
      _syncSoundBtn();
      this.audio.ui();
    });
    _syncSoundBtn();

    // World Select Modal
    document.getElementById('btn-worlds').addEventListener('click', () => {
      this._renderWorldsModal();
      document.getElementById('worlds-modal').classList.remove('hidden');
    });
    document.getElementById('btn-close-worlds').addEventListener('click', () => {
      document.getElementById('worlds-modal').classList.add('hidden');
    });

    // Settings Modal
    document.getElementById('btn-settings').addEventListener('click', () => {
      document.getElementById('settings-modal').classList.remove('hidden');
    });
    document.getElementById('btn-close-settings').addEventListener('click', () => {
      document.getElementById('settings-modal').classList.add('hidden');
    });
    document.getElementById('btn-quality').addEventListener('click', () => {
      const nextQ = this.save.quality === 'high' ? 'balanced' : 'high';
      this.applyQuality(nextQ);
    });
  }

  _renderWorldsModal() {
    const list = document.getElementById('worlds-list');
    list.innerHTML = '';
    for (const id of WORLD_ORDER) {
      const b = BIOMES[id];
      const unlocked = this.save.totalSuns >= b.unlockSuns;
      const isAct = this.save.selectedBiome === id;
      const row = document.createElement('div');
      row.className = `world-item${isAct ? ' active' : ''}${unlocked ? '' : ' locked'}`;
      row.innerHTML = `
        <div>
          <div class="world-name">${b.name}</div>
          <div class="world-desc">${b.subtitle}</div>
        </div>
        <div class="setting-val">${unlocked ? (isAct ? 'ACTIVE' : 'SELECT') : `☀ ${b.unlockSuns}`}</div>
      `;
      if (unlocked) {
        row.addEventListener('click', () => {
          this.save.selectedBiome = id;
          writeSave(this.save);
          document.getElementById('worlds-modal').classList.add('hidden');
          this.enterTitleScreen();
        });
      }
      list.appendChild(row);
    }
  }

  _bindInputs() {
    let touchStartX = 0;
    let touchStartY = 0;
    let swipedThisTouch = false;
    let lastTapMs = 0;

    const handleAction = (action) => {
      if (this.state !== 'RUNNING') return;
      if (action === 'left') {
        if (this.soul.moveLane(-1)) this.audio.lane();
      } else if (action === 'right') {
        if (this.soul.moveLane(1)) this.audio.lane();
      } else if (action === 'up') {
        if (this.soul.y <= this.soul.supportY + 0.14) {
          const jumpV = this.powerUps.sneakers > 0 ? 14.8 : 11.6;
          this.soul.jump(jumpV);
          this.audio.jump();
        }
      } else if (action === 'down') {
        this.soul.slide();
        this.audio.slide();
      }
    };

    window.addEventListener(
      'pointerdown',
      (e) => {
        if (e.target.closest('button') || e.target.closest('.modal-card')) return;
        this.audio.unlock();
        touchStartX = e.clientX;
        touchStartY = e.clientY;
        swipedThisTouch = false;

        if (this.state === 'RUNNING') {
          const now = performance.now();
          if (now - lastTapMs < 290) {
            this.activateSolarShield();
            lastTapMs = 0;
          } else {
            lastTapMs = now;
          }
        }
      },
      { passive: true }
    );

    // Instant mid-drag swipe trigger (zero finger-lift latency!)
    window.addEventListener(
      'pointermove',
      (e) => {
        if (swipedThisTouch || this.state !== 'RUNNING') return;
        if (e.buttons === 0 && e.pointerType === 'mouse') return;
        const dx = e.clientX - touchStartX;
        const dy = e.clientY - touchStartY;
        if (Math.hypot(dx, dy) < 26) return;

        swipedThisTouch = true;
        if (Math.abs(dx) > Math.abs(dy)) {
          handleAction(dx > 0 ? 'right' : 'left');
        } else {
          handleAction(dy < 0 ? 'up' : 'down');
        }
      },
      { passive: true }
    );

    window.addEventListener('keydown', (e) => {
      this.audio.unlock();
      if (this.state === 'TITLE' && (e.code === 'Space' || e.code === 'Enter')) {
        this.startRunFromTitle();
        return;
      }
      if (e.code === 'ArrowLeft' || e.code === 'KeyA') handleAction('left');
      else if (e.code === 'ArrowRight' || e.code === 'KeyD') handleAction('right');
      else if (e.code === 'ArrowUp' || e.code === 'KeyW' || e.code === 'Space') handleAction('up');
      else if (e.code === 'ArrowDown' || e.code === 'KeyS') handleAction('down');
      else if (e.code === 'ShiftLeft' || e.code === 'KeyE') this.activateSolarShield();
    });
  }
}

new SoulDuskRun3DApp();
