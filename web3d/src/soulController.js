import * as THREE from 'three';

export const LANE_X = [-2.1, 0.0, 2.1];

export class SoulController {
  constructor(scene, soulGltf) {
    this.scene = scene;
    this.root = new THREE.Group();
    this.scene.add(this.root);

    this.modelPivot = new THREE.Group();
    this.root.add(this.modelPivot);

    this.model = soulGltf.scene;
    this.model.scale.setScalar(1.18);
    this.model.traverse((node) => {
      if (node.isMesh) {
        node.castShadow = true;
        node.receiveShadow = true;
        if (node.material) {
          node.material.roughness = Math.min(0.55, node.material.roughness ?? 0.45);
        }
      }
    });
    this.modelPivot.add(this.model);

    // Warm golden point light attached to Soul so his radiant body illuminates nearby stone & crystals in 3D!
    this.auraLight = new THREE.PointLight(0xffb84d, 1.35, 7.5, 1.6);
    this.auraLight.position.set(0, 0.95, 0);
    this.root.add(this.auraLight);

    // 3D Solar Shield Surf-Disk (visible when Solar Shield active!)
    const diskGeo = new THREE.CylinderGeometry(0.82, 0.68, 0.09, 24);
    const diskMat = new THREE.MeshStandardMaterial({
      color: 0xffd25a,
      emissive: 0xff9e24,
      emissiveIntensity: 0.95,
      roughness: 0.2,
      metalness: 0.35,
    });
    this.shieldDisk = new THREE.Mesh(diskGeo, diskMat);
    this.shieldDisk.position.y = 0.04;
    this.shieldDisk.visible = false;
    this.root.add(this.shieldDisk);

    // 3D Magnet Halo Ring
    const magGeo = new THREE.TorusGeometry(0.88, 0.035, 10, 32);
    const magMat = new THREE.MeshBasicMaterial({ color: 0xd49eff, transparent: true, opacity: 0.78 });
    this.magnetRing = new THREE.Mesh(magGeo, magMat);
    this.magnetRing.rotation.x = Math.PI / 2;
    this.magnetRing.position.y = 0.68;
    this.magnetRing.visible = false;
    this.root.add(this.magnetRing);

    // 3D Golden Ribbon Trail streaming behind Soul!
    this._buildGoldenRibbonTrail();

    // AnimationMixer & Clips from Blender 5.0 `soul.glb`!
    this.mixer = new THREE.AnimationMixer(this.model);
    this.actions = {};
    for (const clip of soulGltf.animations) {
      const act = this.mixer.clipAction(clip);
      this.actions[clip.name] = act;
    }

    if (this.actions.JumpStart) {
      this.actions.JumpStart.setLoop(THREE.LoopOnce, 1);
      this.actions.JumpStart.clampWhenFinished = true;
    }
    if (this.actions.JumpLand) {
      this.actions.JumpLand.setLoop(THREE.LoopOnce, 1);
      this.actions.JumpLand.clampWhenFinished = true;
    }
    if (this.actions.SlideRoll) {
      this.actions.SlideRoll.setLoop(THREE.LoopOnce, 1);
      this.actions.SlideRoll.clampWhenFinished = true;
    }
    if (this.actions.Stumble) {
      this.actions.Stumble.setLoop(THREE.LoopOnce, 1);
      this.actions.Stumble.clampWhenFinished = true;
    }

    this.currentClip = null;
    this.resetToTitle();
  }

  _buildGoldenRibbonTrail() {
    this.trailCount = 22;
    this.trailPts = Array.from({ length: this.trailCount }, () => new THREE.Vector3(0, 0.5, 0));
    const positions = new Float32Array(this.trailCount * 2 * 3);
    const alphas = new Float32Array(this.trailCount * 2);
    for (let i = 0; i < this.trailCount; i++) {
      const a = Math.pow(1 - i / (this.trailCount - 1), 1.5);
      alphas[i * 2] = a;
      alphas[i * 2 + 1] = a;
    }
    this.trailGeo = new THREE.BufferGeometry();
    this.trailGeo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    this.trailGeo.setAttribute('aAlpha', new THREE.BufferAttribute(alphas, 1));
    const indices = [];
    for (let i = 0; i < this.trailCount - 1; i++) {
      const b = i * 2;
      indices.push(b, b + 1, b + 2, b + 1, b + 3, b + 2);
    }
    this.trailGeo.setIndex(indices);

    const trailMat = new THREE.ShaderMaterial({
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
      side: THREE.DoubleSide,
      uniforms: {
        uOpacity: { value: 0.65 },
      },
      vertexShader: /* glsl */ `
        attribute float aAlpha;
        varying float vAlpha;
        void main() {
          vAlpha = aAlpha;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: /* glsl */ `
        uniform float uOpacity;
        varying float vAlpha;
        void main() {
          vec3 c = mix(vec3(1.0, 0.48, 0.12), vec3(1.0, 0.94, 0.62), vAlpha);
          gl_FragColor = vec4(c, vAlpha * uOpacity * 0.58);
        }
      `,
    });
    this.trailMesh = new THREE.Mesh(this.trailGeo, trailMat);
    this.trailMesh.frustumCulled = false;
    this.scene.add(this.trailMesh);
  }

  playClip(name, fadeDuration = 0.16, timeScale = 1.0) {
    const next = this.actions[name];
    if (!next) return;
    if (this.currentClip === name && next.isRunning()) {
      next.timeScale = timeScale;
      return;
    }
    const prev = this.currentClip ? this.actions[this.currentClip] : null;
    next.reset();
    next.timeScale = timeScale;
    next.enabled = true;
    next.setEffectiveWeight(1.0);
    if (prev && prev !== next) {
      next.crossFadeFrom(prev, fadeDuration, false);
    }
    next.play();
    this.currentClip = name;
  }

  resetToTitle() {
    this.lane = 1;
    this.x = 0;
    this.y = 2.15;
    this.vy = 0;
    this.supportY = 0;
    this.isJumping = false;
    this.isSliding = false;
    this.slideTimer = 0;
    this.landTimer = 0;
    this.justLanded = false;
    this.stumbleTimer = 0;
    this.laneHopTimer = 0;
    this.turnVelX = 0;
    this.introProgress = 0;

    this.root.position.set(0, this.y, 0);
    // Face +Z toward Title Camera!
    this.modelPivot.rotation.set(0, 0, 0);
    this.modelPivot.scale.set(1, 1, 1);
    this.shieldDisk.visible = false;
    this.magnetRing.visible = false;
    this.playClip('HoverIdle', 0.12, 1.0);

    for (const p of this.trailPts) {
      p.set(0, this.y + 0.45, 0);
    }
  }

  startIntroDive() {
    this.introProgress = 0.0001;
    this.playClip('JumpApex', 0.22, 1.15);
  }

  moveLane(delta) {
    const next = Math.max(0, Math.min(2, this.lane + delta));
    if (next !== this.lane) {
      this.lane = next;
      if (this.y <= this.supportY + 0.08 && !this.isSliding) {
        this.laneHopTimer = 0.22;
      }
      return true;
    }
    return false;
  }

  jump(jumpVelocity = 11.4) {
    this.isSliding = false;
    this.slideTimer = 0;
    this.vy = jumpVelocity;
    this.isJumping = true;
    this.playClip('JumpStart', 0.10, 1.25);
    this.jumpApexQueued = true;
  }

  triggerCloudBounce() {
    this.isSliding = false;
    this.slideTimer = 0;
    this.vy = 15.8;
    this.isJumping = true;
    this.playClip('JumpApex', 0.14, 1.1);
    this.jumpApexQueued = false;
  }

  slide() {
    if (this.y > this.supportY + 0.15) {
      // Mid-air fast-fall slam straight into parkour roll!
      this.vy = Math.min(this.vy, -24.0);
      this.pendingRollOnLand = true;
      return;
    }
    this._startRollNow();
  }

  _startRollNow() {
    this.isSliding = true;
    this.slideTimer = 0.58;
    this.playClip('SlideRoll', 0.09, 1.05);
  }

  triggerStumble() {
    this.stumbleTimer = 0.42;
    this.playClip('Stumble', 0.08, 1.1);
  }

  updateTitleHover(dt, elapsed) {
    this.y = 2.15 + Math.sin(elapsed * 1.9) * 0.12;
    this.root.position.set(Math.sin(elapsed * 1.1) * 0.08, this.y, 0);
    this.modelPivot.rotation.set(
      Math.sin(elapsed * 1.5) * 0.04,
      Math.sin(elapsed * 0.9) * 0.16,
      Math.cos(elapsed * 1.3) * 0.04
    );
    this.mixer.update(dt);
    this._updateTrail(dt, 0.25, 2.0);
  }

  /**
   * 4-Phase Living Title -> 180° 3D Spin -> Blazing Golden Comet Dive -> Cushioned Touchdown!
   * Returns true when intro completes (`introProgress >= 1.0`).
   */
  updateIntroDive(dt) {
    this.introProgress = Math.min(1.0, this.introProgress + dt / 1.28);
    const u = this.introProgress;

    // 1. Elevation arc: rises from 2.15m -> 2.75m peak at u=0.26 -> dives smoothly to 0.0m!
    let elev;
    if (u < 0.28) {
      const t = u / 0.28;
      elev = 2.15 + Math.sin(t * Math.PI * 0.5) * 0.62;
    } else {
      const t = (u - 0.28) / 0.72;
      const smooth = t * t * (3 - 2 * t);
      elev = 2.77 * (1 - smooth);
    }
    this.y = elev;
    this.root.position.set(0, this.y, 0);

    // 2. Smooth 3D 180° Y-axis spin from facing camera (0) to facing horizon (Math.PI)!
    const spinT = Math.max(0, Math.min(1, (u - 0.10) / 0.42));
    const spinSmooth = spinT * spinT * (3 - 2 * spinT);
    const yaw = spinSmooth * Math.PI;
    const divePitch = u > 0.25 && u < 0.88 ? -Math.sin(((u - 0.25) / 0.63) * Math.PI) * 0.38 : 0;

    this.modelPivot.rotation.set(divePitch, yaw, 0);

    if (u > 0.84 && this.currentClip !== 'JumpLand') {
      this.playClip('JumpLand', 0.12, 1.15);
    }

    this.mixer.update(dt);
    this._updateTrail(dt, 0.95, 18.0);

    if (u >= 1.0) {
      this.y = 0;
      this.vy = 0;
      this.modelPivot.rotation.set(0, Math.PI, 0);
      this.playClip('Run', 0.16, 1.05);
      return true;
    }
    return false;
  }

  updateGameplay(dt, forwardSpeed, powerUps) {
    const targetX = LANE_X[this.lane];
    const prevX = this.x;
    const lerpRate = 1.0 - Math.exp(-16.5 * dt);
    this.x += (targetX - this.x) * lerpRate;
    this.turnVelX = (this.x - prevX) / Math.max(0.001, dt);

    // Subtle lateral dodge hop
    let hopOffset = 0;
    if (this.laneHopTimer > 0) {
      this.laneHopTimer = Math.max(0, this.laneHopTimer - dt);
      hopOffset = Math.sin((1 - this.laneHopTimer / 0.22) * Math.PI) * 0.24;
    }

    // Vertical gravity & support physics
    const gravity = -30.5;
    if (powerUps.solarDash > 0) {
      // Soaring golden comet dash at y = 2.35m!
      this.y += (2.35 - this.y) * (1 - Math.exp(-10 * dt));
      this.vy = 0;
      this.isJumping = true;
      this.isSliding = false;
      this.playClip('JumpApex', 0.15, 1.25);
    } else if (this.y > this.supportY || this.vy > 0) {
      this.vy += gravity * dt;
      this.y += this.vy * dt;

      if (this.jumpApexQueued && this.vy < 6.5) {
        this.jumpApexQueued = false;
        this.playClip('JumpApex', 0.16, 1.0);
      }

      if (this.y <= this.supportY) {
        this.y = this.supportY;
        this.vy = 0;
        this.isJumping = false;
        this.jumpApexQueued = false;
        if (this.pendingRollOnLand) {
          this.pendingRollOnLand = false;
          this._startRollNow();
        } else {
          this.landTimer = 0.18;
          this.justLanded = true; // consumed by the app for the impact SFX
          this.playClip('JumpLand', 0.08, 1.15);
        }
      }
    } else {
      this.y = this.supportY;
    }

    // Timers & automatic smooth crossfade back into Run!
    if (this.isSliding) {
      this.slideTimer -= dt;
      if (this.slideTimer <= 0) {
        this.isSliding = false;
        this.playClip('Run', 0.15, 1.0 + (forwardSpeed - 18) * 0.025);
      }
    } else if (this.stumbleTimer > 0) {
      this.stumbleTimer -= dt;
      if (this.stumbleTimer <= 0 && !this.isJumping) {
        this.playClip('Run', 0.16, 1.0 + (forwardSpeed - 18) * 0.025);
      }
    } else if (this.landTimer > 0) {
      this.landTimer -= dt;
      if (this.landTimer <= 0 && !this.isJumping) {
        this.playClip('Run', 0.15, 1.0 + (forwardSpeed - 18) * 0.025);
      }
    } else if (!this.isJumping) {
      const runScale = 0.98 + Math.max(0, (forwardSpeed - 18) / 22) * 0.42;
      this.playClip('Run', 0.18, runScale);
    }

    // Power-up visuals
    const shieldHover = powerUps.shield ? 0.16 + Math.sin(performance.now() * 0.008) * 0.05 : 0;
    this.shieldDisk.visible = powerUps.shield;
    if (powerUps.shield) {
      this.shieldDisk.rotation.y += dt * 3.8;
    }
    this.magnetRing.visible = powerUps.magnet > 0;
    if (powerUps.magnet > 0) {
      this.magnetRing.rotation.z += dt * 3.2;
    }

    this.root.position.set(this.x, this.y + hopOffset + shieldHover, 0);

    // Real 3D Turn Banking (roll + yaw into lane switches) & tactile squash/stretch!
    const bankRoll = THREE.MathUtils.clamp(-this.turnVelX * 0.042, -0.34, 0.34);
    const bankYaw = THREE.MathUtils.clamp(-this.turnVelX * 0.032, -0.28, 0.28);
    this.modelPivot.rotation.set(0, Math.PI + bankYaw, bankRoll);

    let sy = 1.18;
    let sxz = 1.18;
    if (this.landTimer > 0) {
      const sq = Math.sin((this.landTimer / 0.18) * Math.PI) * 0.09;
      sy *= 1 - sq;
      sxz *= 1 + sq * 0.6;
    } else if (this.isJumping) {
      const st = Math.min(0.06, Math.abs(this.vy) * 0.004);
      sy *= 1 + st;
      sxz *= 1 - st * 0.4;
    }
    this.model.scale.set(sxz, sy, sxz);

    this.mixer.update(dt);
    this._updateTrail(dt, powerUps.solarDash > 0 ? 0.95 : 0.58, forwardSpeed);
  }

  _updateTrail(dt, opacity, speedZ) {
    this.trailMesh.material.uniforms.uOpacity.value = opacity;
    // Shift existing points backward along +Z as world moves past Soul!
    for (let i = this.trailCount - 1; i > 0; i--) {
      this.trailPts[i].copy(this.trailPts[i - 1]);
      this.trailPts[i].z += speedZ * dt * 0.72;
    }
    this.trailPts[0].set(this.root.position.x, this.root.position.y + 0.52, this.root.position.z + 0.18);

    const posAttr = this.trailGeo.attributes.position;
    for (let i = 0; i < this.trailCount; i++) {
      const p = this.trailPts[i];
      const hw = 0.32 * (1 - (i / this.trailCount) * 0.75);
      posAttr.setXYZ(i * 2, p.x - hw, p.y, p.z);
      posAttr.setXYZ(i * 2 + 1, p.x + hw, p.y, p.z);
    }
    posAttr.needsUpdate = true;
  }

  /** Effective collider height for obstacle clearance checks */
  get colliderHeight() {
    return this.isSliding ? 0.85 : 1.52;
  }
}
