// ============================================================
// BlockDuel 9×9 — игровое ядро (упрощённое, для прототипа)
// Чистая логика: доска, фигуры, очистки, очки, бот.
// ============================================================
const SIZE = 9;

// --- Определения фигур (нормализованные координаты [row,col]) ---
const PIECES = {
  I: [[0,0],[0,1],[0,2],[0,3]],
  O: [[0,0],[0,1],[1,0],[1,1]],
  T: [[0,0],[0,1],[0,2],[1,1]],
  S: [[0,1],[0,2],[1,0],[1,1]],
  Z: [[0,0],[0,1],[1,1],[1,2]],
  J: [[0,0],[1,0],[1,1],[1,2]],
  L: [[0,2],[1,0],[1,1],[1,2]],
};
const PIECE_TYPES = Object.keys(PIECES);

// --- PRNG (mulberry32), детерминированный ---
function makeRng(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// --- 7-bag ---
function makeBag(seed) {
  const rng = makeRng(seed);
  let queue = [];
  function refill() {
    const arr = [...PIECE_TYPES];
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(rng() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    queue = queue.concat(arr);
  }
  return {
    draw() {
      if (queue.length === 0) refill();
      const type = queue.shift();
      return { id: "p" + Math.floor(rng() * 1e9) + "_" + type, type, cells: PIECES[type].map(c => [...c]) };
    }
  };
}

// --- Геометрия фигур ---
function normalize(cells) {
  const minR = Math.min(...cells.map(c => c[0]));
  const minC = Math.min(...cells.map(c => c[1]));
  return cells.map(([r, c]) => [r - minR, c - minC]);
}
function rotate90(cells) {
  // (r,c) -> (c, -r)
  return normalize(cells.map(([r, c]) => [c, -r]));
}
function flipH(cells) {
  return normalize(cells.map(([r, c]) => [r, -c]));
}
function pieceDims(cells) {
  const maxR = Math.max(...cells.map(c => c[0]));
  const maxC = Math.max(...cells.map(c => c[1]));
  return { rows: maxR + 1, cols: maxC + 1 };
}

// --- Доска ---
function emptyBoard() {
  return Array.from({ length: SIZE }, () =>
    Array.from({ length: SIZE }, () => ({ filled: false, owner: null }))
  );
}
function cloneBoard(board) {
  return board.map(row => row.map(cell => ({ ...cell })));
}
function canPlace(board, cells, r, c) {
  for (const [dr, dc] of cells) {
    const rr = r + dr, cc = c + dc;
    if (rr < 0 || rr >= SIZE || cc < 0 || cc >= SIZE) return false;
    if (board[rr][cc].filled) return false;
  }
  return true;
}
function place(board, cells, r, c, owner) {
  for (const [dr, dc] of cells) {
    board[r + dr][c + dc] = { filled: true, owner };
  }
}

// --- Очистки ---
function findClears(board) {
  const clearedSet = new Set();
  let rows = 0, cols = 0, boxes = 0;
  // строки
  for (let r = 0; r < SIZE; r++) {
    if (board[r].every(c => c.filled)) {
      rows++;
      for (let c = 0; c < SIZE; c++) clearedSet.add(r + "," + c);
    }
  }
  // столбцы
  for (let c = 0; c < SIZE; c++) {
    let full = true;
    for (let r = 0; r < SIZE; r++) if (!board[r][c].filled) { full = false; break; }
    if (full) {
      cols++;
      for (let r = 0; r < SIZE; r++) clearedSet.add(r + "," + c);
    }
  }
  // боксы 3×3
  for (let br = 0; br < 3; br++) {
    for (let bc = 0; bc < 3; bc++) {
      let full = true;
      for (let r = 0; r < 3 && full; r++)
        for (let c = 0; c < 3 && full; c++)
          if (!board[br * 3 + r][bc * 3 + c].filled) full = false;
      if (full) {
        boxes++;
        for (let r = 0; r < 3; r++)
          for (let c = 0; c < 3; c++) clearedSet.add((br * 3 + r) + "," + (bc * 3 + c));
      }
    }
  }
  const cleared = [...clearedSet].map(s => s.split(",").map(Number));
  return { count: rows + cols + boxes, cleared, rows, cols, boxes };
}
function applyClears(board, cleared) {
  for (const [r, c] of cleared) board[r][c] = { filled: false, owner: null };
}
function isPerfectClear(board) {
  return board.every(row => row.every(c => !c.filled));
}

// --- Очки ---
function scoreForMove(N, combo, perfect, cfg) {
  if (N <= 0) return 0;
  const base = (N * (N + 1)) / 2; // 1,3,6,10,15...
  const step = cfg && cfg.comboStep != null ? cfg.comboStep : 0.25;
  const cap = cfg && cfg.comboCap != null ? cfg.comboCap : 3;
  const mult = Math.min(1 + step * combo, cap);
  const bonus = perfect ? (cfg && cfg.perfectClearBonus != null ? cfg.perfectClearBonus : 12) : 0;
  return Math.round(base * mult * 10) + bonus; // ×10 для «сочных» чисел
}

// --- Перебор ходов ---
function orientations(type, rotationEnabled, flipEnabled) {
  const base = PIECES[type].map(c => [...c]);
  const seen = new Set();
  const result = [];
  const variants = [];
  let cur = normalize(base);
  const rots = rotationEnabled ? 4 : 1;
  for (let i = 0; i < rots; i++) {
    variants.push(cur);
    if (flipEnabled) variants.push(flipH(cur));
    cur = rotate90(cur);
  }
  for (const v of variants) {
    const key = JSON.stringify(v);
    if (!seen.has(key)) { seen.add(key); result.push(v); }
  }
  return result;
}

function enumerateMoves(board, hand, cfg) {
  const moves = [];
  for (const piece of hand) {
    const oris = orientations(piece.type, cfg.rotationEnabled, cfg.flipEnabled);
    for (const cells of oris) {
      for (let r = 0; r < SIZE; r++) {
        for (let c = 0; c < SIZE; c++) {
          if (canPlace(board, cells, r, c)) {
            moves.push({ pieceId: piece.id, type: piece.type, cells, r, c });
          }
        }
      }
    }
  }
  return moves;
}

function hasAnyMove(board, hand, cfg) {
  for (const piece of hand) {
    const oris = orientations(piece.type, cfg.rotationEnabled, cfg.flipEnabled);
    for (const cells of oris)
      for (let r = 0; r < SIZE; r++)
        for (let c = 0; c < SIZE; c++)
          if (canPlace(board, cells, r, c)) return true;
  }
  return false;
}

// Можно ли поставить конкретную фигуру (любой ориентацией) — для затемнения «мёртвых»
function pieceHasMove(board, piece, cfg) {
  const oris = orientations(piece.type, cfg.rotationEnabled, cfg.flipEnabled);
  for (const cells of oris)
    for (let r = 0; r < SIZE; r++)
      for (let c = 0; c < SIZE; c++)
        if (canPlace(board, cells, r, c)) return true;
  return false;
}

// --- Бот ---
function evalMove(board, move) {
  const b = cloneBoard(board);
  place(b, move.cells, move.r, move.c, 1);
  const clr = findClears(b);
  // эвристика: очистки сильно поощряем, центр слегка
  let filledAfter = 0;
  for (const row of b) for (const cell of row) if (cell.filled) filledAfter++;
  const perfect = (filledAfter - clr.cleared.length) === 0 && clr.count > 0;
  const score = clr.count * 100 + (perfect ? 500 : 0) - filledAfter * 0.3;
  return { clears: clr.count, score };
}

function chooseBotMove(board, hand, level, cfg, rng) {
  const moves = enumerateMoves(board, hand, cfg);
  if (moves.length === 0) return null;
  if (level === "easy") {
    return moves[Math.floor(rng() * moves.length)];
  }
  // оценим все
  const scored = moves.map(m => ({ m, e: evalMove(board, m) }));
  scored.sort((a, b) => b.e.score - a.e.score);
  if (level === "hard") {
    return scored[0].m;
  }
  // medium: из топ-30% случайно, чуть глупее
  const top = scored.slice(0, Math.max(1, Math.floor(scored.length * 0.3)));
  return top[Math.floor(rng() * top.length)].m;
}

// экспорт в глобал
Object.assign(window, {
  SIZE, PIECES, PIECE_TYPES, makeRng, makeBag,
  normalize, rotate90, flipH, pieceDims,
  emptyBoard, cloneBoard, canPlace, place,
  findClears, applyClears, isPerfectClear, scoreForMove,
  orientations, enumerateMoves, hasAnyMove, pieceHasMove,
  chooseBotMove,
});
