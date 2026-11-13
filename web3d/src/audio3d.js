/**
 * Procedural WebAudio SFX for SOUL: DUSK RUN 3D.
 *
 * Every sound is synthesised at runtime (oscillators + generated noise
 * buffers), so the offline APK needs zero audio files and the WebGL2 bundle
 * stays tiny. The AudioContext is created lazily on the first real user
 * gesture (mobile browsers refuse to start audio otherwise) and every public
 * method is a no-op until then, so a blocked/missing WebAudio implementation
 * can never break the 3D render loop.
 */

const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);

export class Audio3D {
  constructor() {
    this.ctx = null;
    this.master = null;
    this.noiseBuffer = null;
    this.enabled = true;
    this.orbStreak = 0;
    this.orbStreakMs = 0;
  }

  /** Safe to call on every gesture; only the first one actually builds nodes. */
  unlock() {
    try {
      if (!this.ctx) {
        const Ctor = window.AudioContext || window.webkitAudioContext;
        if (!Ctor) return;
        this.ctx = new Ctor();
        this.master = this.ctx.createGain();
        this.master.gain.value = 0.42;
        this.master.connect(this.ctx.destination);
        this._buildNoise();
      }
      if (this.ctx.state === 'suspended') this.ctx.resume();
    } catch (err) {
      this.ctx = null;
    }
  }

  setEnabled(on) {
    this.enabled = !!on;
    if (this.master) {
      this.master.gain.value = this.enabled ? 0.42 : 0.0;
    }
  }

  _buildNoise() {
    const len = Math.floor(this.ctx.sampleRate * 1.2);
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    this.noiseBuffer = buf;
  }

  get _live() {
    return this.enabled && this.ctx && this.master;
  }

  _now() {
    return this.ctx.currentTime;
  }

  /** One-shot oscillator with an exponential AD envelope. */
  _tone({ type = 'sine', from, to, dur, gain = 0.3, delay = 0, curve = 'exp' }) {
    const t0 = this._now() + delay;
    const osc = this.ctx.createOscillator();
    const amp = this.ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(from, t0);
    if (to !== from) {
      if (curve === 'exp') osc.frequency.exponentialRampToValueAtTime(Math.max(1, to), t0 + dur);
      else osc.frequency.linearRampToValueAtTime(Math.max(1, to), t0 + dur);
    }
    amp.gain.setValueAtTime(0.0001, t0);
    amp.gain.exponentialRampToValueAtTime(gain, t0 + Math.min(0.018, dur * 0.25));
    amp.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(amp).connect(this.master);
    osc.start(t0);
    osc.stop(t0 + dur + 0.02);
  }

  /** Filtered burst of the shared noise buffer (whooshes, impacts, sparkles). */
  _noise({ dur = 0.22, gain = 0.25, type = 'bandpass', freq = 900, q = 1.2, delay = 0, sweepTo = 0 }) {
    const t0 = this._now() + delay;
    const src = this.ctx.createBufferSource();
    src.buffer = this.noiseBuffer;
    const filter = this.ctx.createBiquadFilter();
    filter.type = type;
    filter.frequency.setValueAtTime(freq, t0);
    if (sweepTo) filter.frequency.exponentialRampToValueAtTime(Math.max(40, sweepTo), t0 + dur);
    filter.Q.value = q;
    const amp = this.ctx.createGain();
    amp.gain.setValueAtTime(0.0001, t0);
    amp.gain.exponentialRampToValueAtTime(gain, t0 + Math.min(0.02, dur * 0.3));
    amp.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    src.connect(filter).connect(amp).connect(this.master);
    src.start(t0);
    src.stop(t0 + dur + 0.02);
  }

  // ---------------------------------------------------------------- events

  ui() {
    if (!this._live) return;
    this._tone({ type: 'triangle', from: 620, to: 880, dur: 0.12, gain: 0.16 });
  }

  jump() {
    if (!this._live) return;
    this._tone({ type: 'sine', from: 380, to: 760, dur: 0.16, gain: 0.2 });
    this._noise({ dur: 0.12, gain: 0.08, freq: 1800, sweepTo: 3200, q: 0.8 });
  }

  land() {
    if (!this._live) return;
    this._tone({ type: 'sine', from: 190, to: 110, dur: 0.14, gain: 0.16 });
    this._noise({ dur: 0.1, gain: 0.08, freq: 500, sweepTo: 180, q: 0.7 });
  }

  slide() {
    if (!this._live) return;
    this._noise({ dur: 0.3, gain: 0.16, freq: 2400, sweepTo: 420, q: 1.6 });
  }

  /** Short air-cut whoosh when Soul hops one lane sideways. */
  lane() {
    if (!this._live) return;
    this._noise({ dur: 0.16, gain: 0.1, freq: 1500, sweepTo: 520, q: 2.2 });
    this._tone({ type: 'sine', from: 520, to: 700, dur: 0.1, gain: 0.07 });
  }

  /** Rising pentatonic ladder while chaining Sun-Orbs in one streak. */
  orb() {
    if (!this._live) return;
    const now = performance.now();
    this.orbStreak = now - this.orbStreakMs < 900 ? Math.min(7, this.orbStreak + 1) : 0;
    this.orbStreakMs = now;
    const scale = [0, 2, 4, 7, 9, 12, 14, 16];
    const semi = scale[clamp01(this.orbStreak / 7) * 7 | 0];
    const freq = 740 * Math.pow(2, semi / 12);
    this._tone({ type: 'triangle', from: freq, to: freq * 1.5, dur: 0.13, gain: 0.18 });
    this._tone({ type: 'sine', from: freq * 2, to: freq * 2.4, dur: 0.09, gain: 0.07, delay: 0.01 });
  }

  powerup() {
    if (!this._live) return;
    [0, 4, 7, 12].forEach((semi, i) => {
      this._tone({
        type: 'triangle',
        from: 520 * Math.pow(2, semi / 12),
        to: 780 * Math.pow(2, semi / 12),
        dur: 0.2,
        gain: 0.15,
        delay: i * 0.055,
      });
    });
  }

  shield() {
    if (!this._live) return;
    this._tone({ type: 'sawtooth', from: 180, to: 520, dur: 0.3, gain: 0.14, curve: 'lin' });
    this._tone({ type: 'sine', from: 900, to: 1500, dur: 0.34, gain: 0.1, delay: 0.04 });
    this._noise({ dur: 0.36, gain: 0.1, freq: 700, sweepTo: 3600, q: 0.9 });
  }

  shieldBreak() {
    if (!this._live) return;
    this._noise({ dur: 0.42, gain: 0.24, freq: 2600, sweepTo: 260, q: 1.1 });
    this._tone({ type: 'square', from: 420, to: 90, dur: 0.3, gain: 0.12, curve: 'lin' });
  }

  stumble() {
    if (!this._live) return;
    this._tone({ type: 'square', from: 240, to: 150, dur: 0.16, gain: 0.1, curve: 'lin' });
    this._noise({ dur: 0.2, gain: 0.12, freq: 900, sweepTo: 300, q: 0.8 });
  }

  cloud() {
    if (!this._live) return;
    this._tone({ type: 'sine', from: 520, to: 1320, dur: 0.28, gain: 0.18 });
    this._noise({ dur: 0.24, gain: 0.08, freq: 1200, sweepTo: 3800, q: 0.7 });
  }

  /** Dimensional Crystal Portal breach: descending shimmer into a rising chord. */
  portal() {
    if (!this._live) return;
    this._noise({ dur: 0.7, gain: 0.2, freq: 260, sweepTo: 5200, q: 0.6 });
    [0, 7, 12, 16, 19].forEach((semi, i) => {
      this._tone({
        type: 'sine',
        from: 330 * Math.pow(2, semi / 12),
        to: 660 * Math.pow(2, semi / 12),
        dur: 0.8,
        gain: 0.13,
        delay: 0.16 + i * 0.07,
      });
    });
    this._tone({ type: 'sawtooth', from: 90, to: 42, dur: 0.9, gain: 0.12, curve: 'lin' });
  }

  crash() {
    if (!this._live) return;
    this._noise({ dur: 0.6, gain: 0.3, freq: 1600, sweepTo: 90, q: 0.7 });
    this._tone({ type: 'sawtooth', from: 260, to: 48, dur: 0.7, gain: 0.18, curve: 'lin' });
    this._tone({ type: 'square', from: 130, to: 60, dur: 0.5, gain: 0.1, curve: 'lin', delay: 0.05 });
  }

  gameOver() {
    if (!this._live) return;
    [0, -3, -7, -12].forEach((semi, i) => {
      this._tone({
        type: 'triangle',
        from: 440 * Math.pow(2, semi / 12),
        to: 300 * Math.pow(2, semi / 12),
        dur: 0.55,
        gain: 0.14,
        delay: 0.45 + i * 0.13,
      });
    });
  }
}
