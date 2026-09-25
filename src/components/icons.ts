// Sprites de 8x8. Cada carácter es un píxel; '.' es transparente.
export const palette: Record<string, string> = {
  k: '#1a1410', // contorno
  w: '#e8dcc0', // hueso / pergamino
  g: '#7a8f4a', // verde
  b: '#8a5a32', // madera
  d: '#5a3a22', // madera oscura
  r: '#a8322d', // rojo
  y: '#e0a83a', // oro
  o: '#e07a2a', // naranja
  s: '#7a7a78', // piedra
  l: '#b8b8b0', // piedra clara
  p: '#7a4a8a', // púrpura
  c: '#4a8ab0', // azul
};

const sprites = {
  log: ['........', '.kkkkkk.', 'kbbbbkyk', 'kdddbkok', 'kbbbbkyk', '.kkkkkk.', '........', '........'],
  plank: ['........', '........', 'kkkkkkkk', 'kbbbbbbk', 'kddbdddk', 'kkkkkkkk', '........', '........'],
  stone: ['........', '...kkk..', '..klllk.', '.kllsslk', 'kllssssk', 'kssssssk', '.kkkkkk.', '........'],
  ore: ['........', '...kkk..', '..kslsk.', '.ksoslsk', 'ksslsosk', 'ksosssk.', '.kkkkk..', '........'],
  ingot: ['........', '........', '..kkkkk.', '.klllllk', 'kssssslk', 'kkkkkkk.', '........', '........'],
  nails: ['........', '.kkk.kkk', '..s...s.', '..s...s.', '..s...s.', '..l...l.', '........', '........'],
  bone: ['.kk.....', 'kwwk....', 'kwwwk...', '.kwwwk..', '..kwwwk.', '...kwwwk', '....kwwk', '.....kk.'],
  meat: ['........', '...kkkk.', '..krrrrk', '.krrwrrk', '.krrrrk.', 'kwkkkk..', 'kwk.....', '.k......'],
  fat: ['........', '........', '..kkkk..', '.kwwwyk.', 'kwwyywwk', 'kwwwwwyk', '.kkkkkk.', '........'],
  wax: ['........', '..kkkk..', '.kyoyyk.', 'kyyoyoyk', 'kyoyyyyk', '.kyyoyk.', '..kkkk..', '........'],
  herb: ['...g....', '..ggg.g.', '...g.gg.', '.g.gg...', 'ggg.g...', '.g..g...', '....g...', '...kkk..'],
  herb_blue: ['...c....', '..ccc.c.', '...g.cc.', '.c.gg...', 'ccc.g...', '.g..g...', '....g...', '...kkk..'],
  water: ['..kkkk..', '.k....k.', 'kkkkkkkk', 'kccccclk', 'kbccccbk', '.kbbbbk.', '.kbbbbk.', '..kkkk..'],
  wheat: ['...y....', '..yoy...', '..yoy.y.', '...y.yoy', '...y..y.', '...y.y..', '...yy...', '...y....'],
  sack: ['...kk...', '..kbbk..', '...kk...', '..kwwk..', '.kwwwwk.', 'kwwwwwwk', 'kwwwwwwk', '.kkkkkk.'],
  scroll: ['........', '.kkkkkk.', 'kwwwwwwk', 'kwkkkkwk', 'kwwwwwwk', 'kwkkkwwk', 'kwwwwwwk', '.kkkkkk.'],
  potion: ['...kk...', '..kddk..', '...kk...', '..krrk..', '.krwrrk.', '.krrrrk.', '.krrrrk.', '..kkkk..'],
  potion_dark: ['...kk...', '..kddk..', '...kk...', '..kppk..', '.kpwppk.', '.kppppk.', '.kppppk.', '..kkkk..'],
  candle: ['...o....', '..oyo...', '...y....', '..kkkk..', '..kwwk..', '..kwwk..', '..kwwk..', '.kkkkkk.'],
  bread: ['........', '..kkkk..', '.kyyyyk.', 'kyoyoyyk', 'kyyyyyyk', 'kbbbbbbk', '.kkkkkk.', '........'],
  burger: ['........', '..kkkk..', '.kyyyyk.', 'kyywyyyk', 'kggggggk', 'kddddddk', 'kyyyyyyk', '.kkkkkk.'],
  coffin: ['..kkkk..', '.kbbbbk.', '.kbybbk.', '.kyyybk.', '.kbybbk.', '.kbbbbk.', '.kbbbbk.', '..kkkk..'],
  grave: ['..kkkk..', '.kllllk.', '.klsllk.', '.kssslk.', '.klsllk.', '.kllllk.', 'kkkkkkkk', 'gggggggg'],
  crown: ['........', 'y.y..y.y', 'yyy..yyy', 'yyyyyyyy', 'yryyyyry', 'yyyyyyyy', 'kkkkkkkk', '........'],
  coin: ['..kkkk..', '.kyyyyk.', 'kyyooyyk', 'kyoyyyyk', 'kyyooyyk', 'kyyyyoyk', '.kyooyk.', '..kkkk..'],
  heart: ['........', '.kk..kk.', 'krrkkrrk', 'krwrrrrk', 'krrrrrrk', '.krrrrk.', '..krrk..', '...kk...'],
  eye: ['........', '..kkkk..', '.kwwwwk.', 'kwgkkgwk', 'kwgkkgwk', '.kwwwwk.', '..kkkk..', '........'],
  skull: ['..kkkk..', '.kwwwwk.', 'kwwwwwwk', 'kkkwwkkk', 'kkkwwkkk', 'kwwkkwwk', '.kwwwwk.', '.kwkkwk.'],
  moon: ['...kkk..', '..kyyk..', '.kyyk...', '.kyk....', '.kyk....', '.kyyk...', '..kyyk..', '...kkk..'],
  anvil: ['........', 'kkkkkkkk', 'klllllsk', '.kssssk.', '..kssk..', '.kssssk.', 'kkkkkkkk', '........'],
  cauldron: ['...c....', '..c..c..', 'kkkkkkkk', 'kggcgggk', 'kssssssk', 'kssssssk', '.kssssk.', '.k....k.'],
  person: ['..kkkk..', '.kddddk.', '.kdwwdk.', '.kdwwdk.', '..kkkk..', '.kddddk.', 'kddddddk', 'kkkkkkkk'],
} satisfies Record<string, string[]>;

export type IconName = keyof typeof sprites;
export const iconNames = Object.keys(sprites) as IconName[];
export { sprites };
