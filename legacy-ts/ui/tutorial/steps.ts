import { BASE_SHAPES, emptyBoard, SIZE, type Board, type Coord, type PieceInstance, type PieceType } from "../../core";

export interface TutorialStep {
  id: string;
  title: string;
  description: string;
  /** Подсказка снизу под доской пока шаг идёт. */
  hint: string;
  /** Стартовая доска для шага. */
  buildBoard: () => Board;
  /** Стартовая рука. */
  buildHand: () => PieceInstance[];
  /**
   * Цель шага: вызывается после применения хода игрока.
   * @param clearsCount  N очищенных единиц в этом ходу
   * @param cumulativeCombo  достигнутое в этом шаге комбо
   * @param boardEmptyAfter  пуста ли доска после хода
   */
  isGoalMet: (args: { clearsCount: number; combo: number; boardEmptyAfter: boolean }) => boolean;
  /** Допускать ли неподходящий ход (если false — место запрещаем, и шаг не двигается). По умолчанию true. */
  allowAnyMove?: boolean;
}

let pieceCounter = 0;
function mkPiece(type: PieceType): PieceInstance {
  pieceCounter += 1;
  return { id: `tut_${type}_${pieceCounter}`, type, cells: BASE_SHAPES[type].map((c) => [...c]) as Coord[] };
}

function fill(board: Board, cells: Coord[], owner: 0 | 1 = 0): void {
  for (const [r, c] of cells) {
    if (r >= 0 && r < SIZE && c >= 0 && c < SIZE) {
      board[r][c] = { filled: true, owner };
    }
  }
}

function rowCells(r: number, except: number[] = []): Coord[] {
  const out: Coord[] = [];
  for (let c = 0; c < SIZE; c++) if (!except.includes(c)) out.push([r, c]);
  return out;
}

export const TUTORIAL_STEPS: TutorialStep[] = [
  {
    id: "place",
    title: "Шаг 1 · Поставь фигуру",
    description: "Перетащи фигуру из руки на любую клетку доски. На десктопе — мышью, на телефоне — пальцем.",
    hint: "перетащи фигуру",
    buildBoard: () => emptyBoard(),
    buildHand: () => [mkPiece("L")],
    isGoalMet: () => true, // любой ход = успех
  },
  {
    id: "close_row",
    title: "Шаг 2 · Закрой строку",
    description: "Строка почти полная — поставь I-фигуру горизонтально в правый край, чтобы заполнить её. Целая строка = очистка!",
    hint: "поставь I в строку 4",
    buildBoard: () => {
      const b = emptyBoard();
      // Заполняем строку 4 кроме клеток (4, 5..8) — 4 пустые клетки справа.
      for (let c = 0; c <= 4; c++) b[4][c] = { filled: true, owner: 0 };
      return b;
    },
    buildHand: () => [mkPiece("I")],
    isGoalMet: ({ clearsCount }) => clearsCount >= 1,
  },
  {
    id: "rotate",
    title: "Шаг 3 · Поверни и закрой столбец",
    description: "Сейчас почти полный столбец 3. Поверни I в вертикальное положение (тап по выбранной фигуре или клавиша R) и поставь.",
    hint: "поверни и закрой столбец 3",
    buildBoard: () => {
      const b = emptyBoard();
      // столбец 3 заполнен сверху до r=4 (5 клеток), остаются r=5..8 (4 пустые)
      for (let r = 0; r <= 4; r++) b[r][3] = { filled: true, owner: 0 };
      return b;
    },
    buildHand: () => [mkPiece("I")],
    isGoalMet: ({ clearsCount }) => clearsCount >= 1,
  },
  {
    id: "box",
    title: "Шаг 4 · Закрой бокс 3×3",
    description: "Верхний-левый квадрат 3×3 заполнен на 5 клеток — поставь O (квадрат 2×2) в его свободный угол, чтобы закрыть.",
    hint: "поставь O в угол бокса",
    buildBoard: () => {
      const b = emptyBoard();
      // Бокс 0 (0..2, 0..2): заполняем верхний ряд (0,0)(0,1)(0,2) и (1,0)(2,0) — 5 клеток.
      // Оставляем пустыми (1,1)(1,2)(2,1)(2,2) — 2×2 в нижнем-правом углу.
      fill(b, [[0, 0], [0, 1], [0, 2], [1, 0], [2, 0]]);
      return b;
    },
    buildHand: () => [mkPiece("O")],
    isGoalMet: ({ clearsCount }) => clearsCount >= 1,
  },
  {
    id: "combo",
    title: "Шаг 5 · Сделай комбо",
    description: "Два хода подряд с очисткой = комбо ×2. Используй обе фигуры — каждая закрывает свою строку.",
    hint: "оба хода должны очистить — добьёшься комбо",
    buildBoard: () => {
      const b = emptyBoard();
      // Строка 3 пустая в столбцах 5..8 (4 пустые), всё остальное в строке 3 заполнено.
      fill(b, rowCells(3, [5, 6, 7, 8]));
      // Строка 5 — то же самое, пустые 5..8.
      fill(b, rowCells(5, [5, 6, 7, 8]));
      return b;
    },
    buildHand: () => [mkPiece("I"), mkPiece("I")],
    isGoalMet: ({ combo }) => combo >= 2,
  },
];

/** Награда за прохождение туториала. */
export const TUTORIAL_REWARD_COINS = 50;
