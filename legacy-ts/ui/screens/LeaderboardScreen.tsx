import { useEffect, useRef, useState } from "react";
import type { LeaderboardEntry } from "../../../party/protocol";
import { openLeaderboard, type LeaderboardConnection } from "../online/client";

interface Props {
  myId: string;
  onBack: () => void;
}

export function LeaderboardScreen({ myId, onBack }: Props) {
  const [top, setTop] = useState<LeaderboardEntry[] | null>(null);
  const [me, setMe] = useState<LeaderboardEntry | undefined>();
  const [myRank, setMyRank] = useState<number | undefined>();
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const connRef = useRef<LeaderboardConnection | null>(null);

  useEffect(() => {
    const conn = openLeaderboard({
      onSnapshot: (snap) => {
        setTop(snap.top);
        setMe(snap.you);
        setMyRank(snap.yourRank);
        setTotal(snap.totalPlayers);
      },
      onClose: () => {
        setError((e) => e ?? "Соединение разорвано");
      },
    });
    connRef.current = conn;
    // подождём open и подписываемся
    const t = setTimeout(() => conn.send({ type: "subscribe", myId }), 150);
    return () => {
      clearTimeout(t);
      conn.close();
      connRef.current = null;
    };
  }, [myId]);

  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>
          ←
        </button>
        <div className="setup-title">Лидерборд</div>
        <span className="mode-badge">{total} игроков</span>
      </div>

      <div className="setup-body">
        {me && myRank && (
          <section className="setup-sec">
            <div className="sec-cap">Ваша позиция</div>
            <LbRow rank={myRank} entry={me} highlight />
          </section>
        )}

        <section className="setup-sec">
          <div className="sec-cap">Топ-100</div>
          {top === null && <div className="status-bar">Загрузка…</div>}
          {error && <div className="status-bar danger">{error}</div>}
          {top && top.length === 0 && (
            <div className="status-bar">Пока никого. Сыграй первый онлайн-матч.</div>
          )}
          <div className="lb-list">
            {top?.map((e, idx) => (
              <LbRow key={e.id} rank={idx + 1} entry={e} highlight={e.id === myId} />
            ))}
          </div>
        </section>

        <section className="setup-sec">
          <div className="ach-card">
            <div className="ach-ico">📈</div>
            <div className="ach-text">
              <div className="ach-title">Как считается ELO</div>
              <div className="ach-desc">
                Стартовый рейтинг — 1000. K = 24. Победа над более сильным даёт больше очков, поражение от слабого больше отнимает. Ничья учитывается как 0.5.
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

function LbRow({ rank, entry, highlight }: { rank: number; entry: LeaderboardEntry; highlight?: boolean }) {
  const games = entry.wins + entry.losses + entry.draws;
  return (
    <div className={`lb-row ${highlight ? "me" : ""}`}>
      <div className="lb-rank">#{rank}</div>
      <div className="lb-avatar">{entry.avatar}</div>
      <div className="lb-text">
        <div className="lb-nick">{entry.nick}</div>
        <div className="lb-meta">
          {games} матч{games === 1 ? "" : games < 5 ? "а" : "ей"} · {entry.wins}↑ {entry.losses}↓
        </div>
      </div>
      <div className="lb-elo">{entry.elo}</div>
    </div>
  );
}
