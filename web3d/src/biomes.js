import * as THREE from 'three';

export const WORLD_ORDER = ['dusk_hollow', 'moonveil_marsh', 'emberfall_canyon'];

export const BIOMES = {
  dusk_hollow: {
    id: 'dusk_hollow',
    name: 'DUSK HOLLOW',
    subtitle: 'Twilight Sky Citadels & Amethyst Causeway',
    unlockSuns: 0,
    skyZenith: new THREE.Color('#1d113a'),
    skyMid: new THREE.Color('#6b3878'),
    skyHorizon: new THREE.Color('#ffb876'),
    sunGlow: new THREE.Color('#ffe6a6'),
    fogColor: new THREE.Color('#4a2964'),
    sunLightColor: new THREE.Color('#ffd39b'),
    hemiSky: new THREE.Color('#a47ad6'),
    hemiGround: new THREE.Color('#2c1842'),
    stoneBase: '#69588c',
    stoneDark: '#473966',
    stoneLight: '#8e7bb4',
    curbColor: new THREE.Color('#7f6ca8'),
    runeColor: new THREE.Color('#ffd178'),
    crystalColor: new THREE.Color('#b95cff'),
    crystalEmissive: new THREE.Color('#7b26d9'),
    mountainNear: new THREE.Color('#341f52'),
    mountainFar: new THREE.Color('#533173'),
  },
  moonveil_marsh: {
    id: 'moonveil_marsh',
    name: 'MOONVEIL MARSH',
    subtitle: 'Bioluminescent Mist & Jade Sanctuaries',
    unlockSuns: 25,
    skyZenith: new THREE.Color('#09202e'),
    skyMid: new THREE.Color('#165968'),
    skyHorizon: new THREE.Color('#6bf5df'),
    sunGlow: new THREE.Color('#b8fff4'),
    fogColor: new THREE.Color('#134654'),
    sunLightColor: new THREE.Color('#aef7ee'),
    hemiSky: new THREE.Color('#5fe8da'),
    hemiGround: new THREE.Color('#0c2832'),
    stoneBase: '#386a76',
    stoneDark: '#234752',
    stoneLight: '#5994a0',
    curbColor: new THREE.Color('#4b8592'),
    runeColor: new THREE.Color('#66ffea'),
    crystalColor: new THREE.Color('#34f5c8'),
    crystalEmissive: new THREE.Color('#0fb898'),
    mountainNear: new THREE.Color('#0f3542'),
    mountainFar: new THREE.Color('#1c5564'),
  },
  emberfall_canyon: {
    id: 'emberfall_canyon',
    name: 'EMBERFALL CANYON',
    subtitle: 'Solar Gold Sandstone & Molten Spires',
    unlockSuns: 60,
    skyZenith: new THREE.Color('#381410'),
    skyMid: new THREE.Color('#9c3f1c'),
    skyHorizon: new THREE.Color('#ffd068'),
    sunGlow: new THREE.Color('#fff2b2'),
    fogColor: new THREE.Color('#7a3218'),
    sunLightColor: new THREE.Color('#ffda8a'),
    hemiSky: new THREE.Color('#ffb25c'),
    hemiGround: new THREE.Color('#3c180c'),
    stoneBase: '#9e6c46',
    stoneDark: '#6c4428',
    stoneLight: '#c48e62',
    curbColor: new THREE.Color('#b88052'),
    runeColor: new THREE.Color('#ffdf72'),
    crystalColor: new THREE.Color('#ff5e3a'),
    crystalEmissive: new THREE.Color('#d92e14'),
    mountainNear: new THREE.Color('#4d1f12'),
    mountainFar: new THREE.Color('#7d351c'),
  },
};

export function nextBiomeId(currentId) {
  const idx = WORLD_ORDER.indexOf(currentId);
  return WORLD_ORDER[(idx + 1) % WORLD_ORDER.length];
}

/**
 * Generates seamless PBR albedo + bump height textures for the carved 3-lane
 * stone causeway so every flagstone joint catches real 3D directional sunlight!
 */
export function buildStoneTextures(biome) {
  const W = 512;
  const H = 512;
  const cAlbedo = document.createElement('canvas');
  cAlbedo.width = W;
  cAlbedo.height = H;
  const ctx = cAlbedo.getContext('2d');

  const cBump = document.createElement('canvas');
  cBump.width = W;
  cBump.height = H;
  const bctx = cBump.getContext('2d');

  ctx.fillStyle = biome.stoneBase;
  ctx.fillRect(0, 0, W, H);
  bctx.fillStyle = '#c8c8c8';
  bctx.fillRect(0, 0, W, H);

  // Carved stone slabs across 3 lanes (6 columns x 8 rows)
  const rows = 8;
  const rowH = H / rows;
  for (let r = 0; r < rows; r++) {
    const y = r * rowH;
    const cols = 6;
    const colW = W / cols;
    const stagger = (r % 2) * (colW * 0.28);

    for (let c = -1; c <= cols; c++) {
      const x = c * colW + stagger;
      const shade = ((r * 7 + c * 13) % 5) * 0.03 - 0.06;
      ctx.fillStyle = shade > 0 ? biome.stoneLight : biome.stoneBase;
      ctx.globalAlpha = Math.abs(shade) * 3.2;
      ctx.fillRect(x + 3, y + 3, colW - 6, rowH - 6);
      ctx.globalAlpha = 1.0;

      // Bevel highlight top/left
      ctx.strokeStyle = biome.stoneLight;
      ctx.lineWidth = 2;
      ctx.strokeRect(x + 3, y + 3, colW - 6, rowH - 6);

      // Deep mortar groove
      ctx.strokeStyle = biome.stoneDark;
      ctx.lineWidth = 4;
      ctx.strokeRect(x, y, colW, rowH);

      bctx.strokeStyle = '#383838';
      bctx.lineWidth = 5;
      bctx.strokeRect(x, y, colW, rowH);
    }
  }

  // Subtle weathered stone grain
  for (let i = 0; i < 1600; i++) {
    const gx = (i * 97) % W;
    const gy = (i * 57) % H;
    ctx.fillStyle = i % 2 === 0 ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.06)';
    ctx.fillRect(gx, gy, 3, 3);
  }

  const map = new THREE.CanvasTexture(cAlbedo);
  map.wrapS = THREE.RepeatWrapping;
  map.wrapT = THREE.RepeatWrapping;
  map.colorSpace = THREE.SRGBColorSpace;
  map.anisotropy = 4;

  const bumpMap = new THREE.CanvasTexture(cBump);
  bumpMap.wrapS = THREE.RepeatWrapping;
  bumpMap.wrapT = THREE.RepeatWrapping;

  return { map, bumpMap };
}
