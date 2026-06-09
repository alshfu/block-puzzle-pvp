export type AchievementCategory = "single" | "progressive" | "series" | "hidden" | "online";

export interface AchievementDef {
  id: string;
  title: string;
  description: string;
  icon: string;
  total: number;          // прогресс target
  hidden?: boolean;       // скрыто пока не разблокировано
  category: AchievementCategory;
  rewardXp: number;
}

export const ACHIEVEMENTS: AchievementDef[] = [
  // ─── Single-event ───────────────────────────────────────────────────────
  {
    id: "first_blood",
    title: "Первая кровь",
    description: "Выиграй свою первую партию",
    icon: "🩸",
    total: 1,
    category: "single",
    rewardXp: 50,
  },
  {
    id: "flawless",
    title: "Безупречно",
    description: "Сделай perfect clear (опустоши доску одним ходом)",
    icon: "💎",
    total: 1,
    category: "single",
    rewardXp: 75,
  },
  {
    id: "combinator",
    title: "Комбинатор",
    description: "Очисти 4 линии/бокса одним ходом",
    icon: "💥",
    total: 1,
    category: "single",
    rewardXp: 50,
  },
  {
    id: "ai_tamer",
    title: "Укротитель ИИ",
    description: "Победи бота уровня Сложный",
    icon: "🤖",
    total: 1,
    category: "single",
    rewardXp: 100,
  },
  {
    id: "strategist",
    title: "Стратег",
    description: "Достигни комбо ×5 в одной партии",
    icon: "🧠",
    total: 5,
    category: "single",
    rewardXp: 75,
  },

  // ─── Progressive ────────────────────────────────────────────────────────
  {
    id: "cleaner_100",
    title: "Чистильщик",
    description: "Очисти 100 линий/боксов суммарно",
    icon: "🧹",
    total: 100,
    category: "progressive",
    rewardXp: 50,
  },
  {
    id: "cleaner_1k",
    title: "Опытный чистильщик",
    description: "Очисти 1 000 линий/боксов суммарно",
    icon: "🧽",
    total: 1000,
    category: "progressive",
    rewardXp: 200,
  },
  {
    id: "cleaner_10k",
    title: "Мастер очистки",
    description: "Очисти 10 000 линий/боксов суммарно",
    icon: "✨",
    total: 10000,
    category: "progressive",
    rewardXp: 1000,
  },
  {
    id: "veteran_10",
    title: "Ветеран",
    description: "Сыграй 10 партий",
    icon: "🎮",
    total: 10,
    category: "progressive",
    rewardXp: 50,
  },
  {
    id: "veteran_100",
    title: "Старожил",
    description: "Сыграй 100 партий",
    icon: "🏆",
    total: 100,
    category: "progressive",
    rewardXp: 250,
  },

  // ─── Series ─────────────────────────────────────────────────────────────
  {
    id: "streak_3",
    title: "В ударе",
    description: "Выиграй 3 партии подряд",
    icon: "🔥",
    total: 3,
    category: "series",
    rewardXp: 50,
  },
  {
    id: "streak_5",
    title: "Доминатор",
    description: "Выиграй 5 партий подряд",
    icon: "💪",
    total: 5,
    category: "series",
    rewardXp: 100,
  },
  {
    id: "streak_10",
    title: "Чемпион",
    description: "Выиграй 10 партий подряд",
    icon: "👑",
    total: 10,
    category: "series",
    rewardXp: 250,
  },

  // ─── Hidden ─────────────────────────────────────────────────────────────
  {
    id: "king_five",
    title: "Король пятёрки",
    description: "Очисти 5+ линий/боксов одним ходом",
    icon: "🕵",
    total: 1,
    category: "hidden",
    hidden: true,
    rewardXp: 150,
  },
  {
    id: "persistence",
    title: "Упорство",
    description: "Сыграй 3 партии подряд через «Реванш»",
    icon: "🔁",
    total: 3,
    category: "hidden",
    hidden: true,
    rewardXp: 50,
  },

  // ═════════════════════════════════════════════════════════════════════
  //   ONLINE ACHIEVEMENTS — 100 штук, разбиты по подкатегориям комментариями.
  //   Все category="online".
  // ═════════════════════════════════════════════════════════════════════

  // ── 1. Прогрессия побед (10) ────────────────────────────────────────
  { id: "on_w_1",    title: "Первая онлайн-победа",  description: "Выиграй 1 онлайн-матч",       icon: "🌐", total: 1,    category: "online", rewardXp: 75 },
  { id: "on_w_5",    title: "Боец PvP",              description: "5 онлайн-побед",              icon: "⚔️", total: 5,    category: "online", rewardXp: 100 },
  { id: "on_w_10",   title: "Завсегдатай арены",     description: "10 онлайн-побед",             icon: "🛡️", total: 10,   category: "online", rewardXp: 150 },
  { id: "on_w_25",   title: "Знаток",                description: "25 онлайн-побед",             icon: "🎖️", total: 25,   category: "online", rewardXp: 200 },
  { id: "on_w_50",   title: "Ветеран PvP",           description: "50 онлайн-побед",             icon: "🏅", total: 50,   category: "online", rewardXp: 300 },
  { id: "on_w_100",  title: "Стогранитный",          description: "100 онлайн-побед",            icon: "💯", total: 100,  category: "online", rewardXp: 500 },
  { id: "on_w_250",  title: "Завоеватель",           description: "250 онлайн-побед",            icon: "👑", total: 250,  category: "online", rewardXp: 800 },
  { id: "on_w_500",  title: "Полководец",            description: "500 онлайн-побед",            icon: "🦅", total: 500,  category: "online", rewardXp: 1500 },
  { id: "on_w_1000", title: "Тысячник",              description: "1 000 онлайн-побед",          icon: "🐉", total: 1000, category: "online", rewardXp: 3000 },
  { id: "on_w_2500", title: "Легенда PvP",           description: "2 500 онлайн-побед",          icon: "🌟", total: 2500, category: "online", rewardXp: 7500 },

  // ── 2. Матчи всего (8) ───────────────────────────────────────────────
  { id: "on_g_10",   title: "Новичок-онлайн",        description: "Сыграй 10 онлайн-матчей",     icon: "🕹️", total: 10,   category: "online", rewardXp: 50 },
  { id: "on_g_50",   title: "Постоянный игрок",      description: "50 онлайн-матчей",            icon: "🎮", total: 50,   category: "online", rewardXp: 150 },
  { id: "on_g_100",  title: "Сотня",                 description: "100 онлайн-матчей",           icon: "💪", total: 100,  category: "online", rewardXp: 250 },
  { id: "on_g_250",  title: "Заядлый",               description: "250 онлайн-матчей",           icon: "🔥", total: 250,  category: "online", rewardXp: 500 },
  { id: "on_g_500",  title: "Завсегдатай",           description: "500 онлайн-матчей",           icon: "♾️", total: 500,  category: "online", rewardXp: 1000 },
  { id: "on_g_1000", title: "Один из тысячи",        description: "1 000 онлайн-матчей",         icon: "🧙", total: 1000, category: "online", rewardXp: 2000 },
  { id: "on_g_5000", title: "Машина PvP",            description: "5 000 онлайн-матчей",         icon: "🤖", total: 5000, category: "online", rewardXp: 5000 },
  { id: "on_g_10k",  title: "Профессионал",          description: "10 000 онлайн-матчей",        icon: "🦾", total: 10000,category: "online", rewardXp: 10000 },

  // ── 3. Стрики побед онлайн (8) ───────────────────────────────────────
  { id: "on_s_3",    title: "Раз-два-три",           description: "3 онлайн-победы подряд",      icon: "✨", total: 3,    category: "online", rewardXp: 75 },
  { id: "on_s_5",    title: "Пятёрка",               description: "5 онлайн-побед подряд",       icon: "🔥", total: 5,    category: "online", rewardXp: 150 },
  { id: "on_s_7",    title: "Семёрка",               description: "7 онлайн-побед подряд",       icon: "🎰", total: 7,    category: "online", rewardXp: 250 },
  { id: "on_s_10",   title: "Десятник",              description: "10 онлайн-побед подряд",      icon: "🏆", total: 10,   category: "online", rewardXp: 400 },
  { id: "on_s_15",   title: "Пятнадцать чисто",      description: "15 онлайн-побед подряд",      icon: "💫", total: 15,   category: "online", rewardXp: 600 },
  { id: "on_s_20",   title: "Безостановочно",        description: "20 онлайн-побед подряд",      icon: "🌀", total: 20,   category: "online", rewardXp: 900 },
  { id: "on_s_25",   title: "Король горы",           description: "25 онлайн-побед подряд",      icon: "👑", total: 25,   category: "online", rewardXp: 1500 },
  { id: "on_s_50",   title: "Неуязвимый",            description: "50 онлайн-побед подряд",      icon: "🛡️", total: 50,   category: "online", rewardXp: 5000 },

  // ── 4. Без поражения (включая ничьи) (4) ─────────────────────────────
  { id: "on_nl_5",   title: "Без срывов",            description: "5 онлайн-матчей без поражения",      icon: "🧱", total: 5,    category: "online", rewardXp: 100 },
  { id: "on_nl_10",  title: "Стена",                 description: "10 онлайн-матчей без поражения",     icon: "🧱", total: 10,   category: "online", rewardXp: 200 },
  { id: "on_nl_25",  title: "Каменная стена",        description: "25 онлайн-матчей без поражения",     icon: "🏰", total: 25,   category: "online", rewardXp: 500 },
  { id: "on_nl_50",  title: "Айсберг",               description: "50 онлайн-матчей без поражения",     icon: "🧊", total: 50,   category: "online", rewardXp: 1500 },

  // ── 5. ELO milestones (10) ──────────────────────────────────────────
  { id: "on_e_1100", title: "1100 ELO",              description: "Достигни 1100 ELO",                  icon: "📈", total: 1100, category: "online", rewardXp: 100 },
  { id: "on_e_1200", title: "1200 ELO",              description: "Достигни 1200 ELO",                  icon: "📈", total: 1200, category: "online", rewardXp: 150 },
  { id: "on_e_1300", title: "1300 ELO",              description: "Достигни 1300 ELO",                  icon: "📈", total: 1300, category: "online", rewardXp: 200 },
  { id: "on_e_1400", title: "1400 ELO",              description: "Достигни 1400 ELO",                  icon: "📊", total: 1400, category: "online", rewardXp: 300 },
  { id: "on_e_1500", title: "1500 ELO",              description: "Достигни 1500 ELO",                  icon: "📊", total: 1500, category: "online", rewardXp: 400 },
  { id: "on_e_1600", title: "1600 ELO",              description: "Достигни 1600 ELO",                  icon: "🎯", total: 1600, category: "online", rewardXp: 500 },
  { id: "on_e_1700", title: "1700 ELO",              description: "Достигни 1700 ELO",                  icon: "🎯", total: 1700, category: "online", rewardXp: 700 },
  { id: "on_e_1800", title: "1800 ELO",              description: "Достигни 1800 ELO",                  icon: "🚀", total: 1800, category: "online", rewardXp: 1000 },
  { id: "on_e_1900", title: "1900 ELO",              description: "Достигни 1900 ELO",                  icon: "🚀", total: 1900, category: "online", rewardXp: 1500 },
  { id: "on_e_2000", title: "Двойка",                description: "Достигни 2000 ELO",                  icon: "👑", total: 2000, category: "online", rewardXp: 3000 },

  // ── 6. Очистки онлайн (5) ───────────────────────────────────────────
  { id: "on_c_100",  title: "Метла онлайн",          description: "100 линий/боксов в онлайне",         icon: "🧹", total: 100,  category: "online", rewardXp: 75 },
  { id: "on_c_500",  title: "Тряпка",                description: "500 онлайн-очисток",                 icon: "🧽", total: 500,  category: "online", rewardXp: 150 },
  { id: "on_c_1k",   title: "Уборщик-онлайн",        description: "1 000 онлайн-очисток",               icon: "✨", total: 1000, category: "online", rewardXp: 300 },
  { id: "on_c_5k",   title: "Чистота PvP",           description: "5 000 онлайн-очисток",               icon: "💫", total: 5000, category: "online", rewardXp: 1000 },
  { id: "on_c_10k",  title: "Король метлы",          description: "10 000 онлайн-очисток",              icon: "🌟", total: 10000,category: "online", rewardXp: 3000 },

  // ── 7. Perfect clears онлайн (5) ────────────────────────────────────
  { id: "on_p_1",    title: "Первый онлайн-perfect", description: "Сделай 1 perfect clear онлайн",      icon: "💎", total: 1,    category: "online", rewardXp: 150 },
  { id: "on_p_5",    title: "Безупречный",           description: "5 perfect clear онлайн",             icon: "💎", total: 5,    category: "online", rewardXp: 300 },
  { id: "on_p_10",   title: "Сапфир",                description: "10 perfect clear онлайн",            icon: "🔷", total: 10,   category: "online", rewardXp: 500 },
  { id: "on_p_25",   title: "Бриллиант",             description: "25 perfect clear онлайн",            icon: "💠", total: 25,   category: "online", rewardXp: 1500 },
  { id: "on_p_50",   title: "Платиновый блеск",      description: "50 perfect clear онлайн",            icon: "✴️", total: 50,   category: "online", rewardXp: 3000 },

  // ── 8. Multi-clear / комбо за матч (8) ──────────────────────────────
  { id: "on_mc_3",   title: "Тройка онлайн",         description: "3 линии одним ходом в онлайн-матче", icon: "🎯", total: 1,    category: "online", rewardXp: 100 },
  { id: "on_mc_4",   title: "Квадра",                description: "4 линии одним ходом в онлайн-матче", icon: "💥", total: 1,    category: "online", rewardXp: 200 },
  { id: "on_mc_5",   title: "Пента",                 description: "5 линий одним ходом в онлайн-матче", icon: "🔥", total: 1,    category: "online", rewardXp: 500 },
  { id: "on_mc_6",   title: "Невероятно",            description: "6+ линий одним ходом в онлайн-матче",icon: "🌪️", total: 1,    category: "online", rewardXp: 1000 },
  { id: "on_co_3",   title: "Цепочка-3",             description: "Комбо ×3 в онлайн-матче",            icon: "⛓️", total: 3,    category: "online", rewardXp: 75 },
  { id: "on_co_5",   title: "Цепочка-5",             description: "Комбо ×5 в онлайн-матче",            icon: "⛓️", total: 5,    category: "online", rewardXp: 200 },
  { id: "on_co_8",   title: "Турбо-комбо",           description: "Комбо ×8 в онлайн-матче",            icon: "🌀", total: 8,    category: "online", rewardXp: 500 },
  { id: "on_co_10",  title: "Десятка комбо",         description: "Комбо ×10 в онлайн-матче",           icon: "🚀", total: 10,   category: "online", rewardXp: 1000 },

  // ── 9. Разрывы и камбэки (10) ───────────────────────────────────────
  { id: "on_gap_10", title: "С запасом",             description: "Победа с отрывом 10+",               icon: "📐", total: 1,    category: "online", rewardXp: 75 },
  { id: "on_gap_25", title: "Уверенно",              description: "Победа с отрывом 25+",               icon: "📏", total: 1,    category: "online", rewardXp: 100 },
  { id: "on_gap_50", title: "Доминатор",             description: "Победа с отрывом 50+",               icon: "💪", total: 1,    category: "online", rewardXp: 200 },
  { id: "on_gap_100",title: "Размазал",              description: "Победа с отрывом 100+",              icon: "🌋", total: 1,    category: "online", rewardXp: 500 },
  { id: "on_gap_200",title: "Аннигиляция",           description: "Победа с отрывом 200+",              icon: "☄️", total: 1,    category: "online", rewardXp: 1500 },
  { id: "on_cb_10",  title: "С возвратом",           description: "Победил отыграв 10+ очков",          icon: "🔄", total: 1,    category: "online", rewardXp: 100 },
  { id: "on_cb_25",  title: "Камбэк",                description: "Победил отыграв 25+ очков",          icon: "🔁", total: 1,    category: "online", rewardXp: 200 },
  { id: "on_cb_50",  title: "Феникс",                description: "Победил отыграв 50+ очков",          icon: "🦅", total: 1,    category: "online", rewardXp: 500 },
  { id: "on_cb_100", title: "Чудо",                  description: "Победил отыграв 100+ очков",         icon: "🎩", total: 1,    category: "online", rewardXp: 1500 },
  { id: "on_close",  title: "В одном шаге",          description: "Победа с отрывом ровно в 1 очко",    icon: "🤏", total: 1,    category: "online", rewardXp: 150 },

  // ── 10. Темп и реванши (8) ──────────────────────────────────────────
  { id: "on_fast_15",title: "Молниеносный",          description: "Победа за ≤15 ходов",                icon: "⚡", total: 1,    category: "online", rewardXp: 200 },
  { id: "on_fast_25",title: "Быстро и чисто",        description: "Победа за ≤25 ходов",                icon: "🏃", total: 1,    category: "online", rewardXp: 100 },
  { id: "on_long_75",title: "Марафонец",             description: "Победа в матче длиной 75+ ходов",    icon: "🛣️", total: 1,    category: "online", rewardXp: 150 },
  { id: "on_long_120",title:"Эпический матч",        description: "Победа в матче длиной 120+ ходов",   icon: "🏛️", total: 1,    category: "online", rewardXp: 400 },
  { id: "on_rm_2",   title: "Двукратный реванш",     description: "Выиграй 2 реванша подряд против того же соперника", icon: "🔁", total: 2, category: "online", rewardXp: 150 },
  { id: "on_rm_3",   title: "Жнец",                  description: "3 реванш-победы подряд",             icon: "🪓", total: 3,    category: "online", rewardXp: 300 },
  { id: "on_rm_5",   title: "Безжалостный жнец",     description: "5 реванш-побед подряд",              icon: "💀", total: 5,    category: "online", rewardXp: 750 },
  { id: "on_rm_10",  title: "Деспот",                description: "10 реванш-побед подряд",             icon: "👹", total: 10,   category: "online", rewardXp: 2500 },

  // ── 11. Соперники (12) ──────────────────────────────────────────────
  { id: "on_opp_3",  title: "Три знакомца",          description: "Сыграй с 3 разными соперниками",     icon: "🤝", total: 3,    category: "online", rewardXp: 50 },
  { id: "on_opp_10", title: "Социальный",            description: "10 разных соперников",               icon: "🤝", total: 10,   category: "online", rewardXp: 150 },
  { id: "on_opp_25", title: "Лицо толпы",            description: "25 разных соперников",               icon: "👥", total: 25,   category: "online", rewardXp: 300 },
  { id: "on_opp_50", title: "Половина города",       description: "50 разных соперников",               icon: "🏙️", total: 50,   category: "online", rewardXp: 600 },
  { id: "on_opp_100",title: "Все знакомы",           description: "100 разных соперников",              icon: "🌆", total: 100,  category: "online", rewardXp: 1500 },
  { id: "on_rival_3",title: "Знакомое лицо",         description: "Сыграй с одним соперником 3 раза",   icon: "👤", total: 3,    category: "online", rewardXp: 50 },
  { id: "on_rival_5",title: "Соперничество",         description: "5 матчей с одним и тем же",          icon: "⚔️", total: 5,    category: "online", rewardXp: 100 },
  { id: "on_rival_10",title:"Заклятая дружба",       description: "10 матчей с одним соперником",       icon: "🤺", total: 10,   category: "online", rewardXp: 250 },
  { id: "on_rival_25",title:"Вечная вражда",         description: "25 матчей с одним соперником",       icon: "🐉", total: 25,   category: "online", rewardXp: 600 },
  { id: "on_dom_3",  title: "Трижды громил",         description: "3 победы подряд над одним соперником", icon: "💢", total: 3,  category: "online", rewardXp: 100 },
  { id: "on_dom_5",  title: "Кошмар соперника",      description: "5 побед подряд над одним соперником",  icon: "👻", total: 5,  category: "online", rewardXp: 300 },
  { id: "on_dom_10", title: "Лютый",                 description: "10 побед подряд над одним соперником", icon: "🐺", total: 10, category: "online", rewardXp: 1000 },

  // ── 12. Тематические (5) ─────────────────────────────────────────────
  { id: "on_th_neutral", title: "Чистый профессионал", description: "10 онлайн-побед в нейтральной теме", icon: "🟧", total: 10, category: "online", rewardXp: 100 },
  { id: "on_th_candy",   title: "Сладкая победа",      description: "10 онлайн-побед в карамельной теме", icon: "🍬", total: 10, category: "online", rewardXp: 100 },
  { id: "on_th_night",   title: "Тень побеждает",      description: "10 онлайн-побед в ночной теме",      icon: "🌙", total: 10, category: "online", rewardXp: 100 },
  { id: "on_th_all3",    title: "Всеми гранями",       description: "Сыграй онлайн во всех 3 темах",      icon: "🎨", total: 3,  category: "online", rewardXp: 150 },
  { id: "on_th_all3_w",  title: "Триумф трёх стихий",  description: "Побеждай онлайн во всех 3 темах",    icon: "🌈", total: 3,  category: "online", rewardXp: 300 },

  // ── 13. Ежедневная активность (5) ───────────────────────────────────
  { id: "on_d_2",    title: "Возвращение",           description: "Играй онлайн 2 дня подряд",          icon: "📅", total: 2,    category: "online", rewardXp: 50 },
  { id: "on_d_7",    title: "Неделя онлайн",         description: "Играй онлайн 7 дней подряд",         icon: "🗓️", total: 7,    category: "online", rewardXp: 150 },
  { id: "on_d_14",   title: "Две недели",            description: "Играй онлайн 14 дней подряд",        icon: "📆", total: 14,   category: "online", rewardXp: 300 },
  { id: "on_d_30",   title: "Месяц-онлайн",          description: "Играй онлайн 30 дней подряд",        icon: "🗓️", total: 30,   category: "online", rewardXp: 750 },
  { id: "on_d_100",  title: "Сотня дней",            description: "Играй онлайн 100 дней подряд",       icon: "🌅", total: 100,  category: "online", rewardXp: 3000 },

  // ── 14. Прочее редкое / hidden (5) ──────────────────────────────────
  { id: "on_resign", title: "Достойный соперник",    description: "Победи когда соперник сдался",       icon: "🏳️", total: 1,    category: "online", hidden: true, rewardXp: 100 },
  { id: "on_timeout",title: "Слишком медленно",      description: "Победи по таймауту соперника",       icon: "⏳", total: 1,    category: "online", hidden: true, rewardXp: 100 },
  { id: "on_draw",   title: "Равные силы",           description: "Сделай ничью в онлайн-матче",        icon: "🤝", total: 1,    category: "online", hidden: true, rewardXp: 75 },
  { id: "on_revenge",title: "Реванш-сладкий",        description: "Победи соперника после поражения от него", icon: "🎭", total: 1, category: "online", hidden: true, rewardXp: 100 },
  { id: "on_dragon", title: "Победа дракона",        description: "Победа с отрывом 50+ ходом длиной ≤25", icon: "🐲", total: 1, category: "online", hidden: true, rewardXp: 500 },

  // ── 15. Большие финальные (2) ────────────────────────────────────────
  { id: "on_zen",    title: "Дзен PvP",              description: "Сыграй 1 000 онлайн-матчей и набей 100 perfect", icon: "🧘", total: 1, category: "online", hidden: true, rewardXp: 5000 },
  { id: "on_top",    title: "Король арены",          description: "Достигни 2200 ELO и 100 побед подряд", icon: "👑", total: 1, category: "online", hidden: true, rewardXp: 10000 },
];

export const ACHIEVEMENTS_BY_ID: Record<string, AchievementDef> = Object.fromEntries(
  ACHIEVEMENTS.map((a) => [a.id, a]),
);
