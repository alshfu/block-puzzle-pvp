import { useEffect, useRef, useState } from "react";
import type { OnlineProfile } from "../../../party/protocol";
import { Button } from "../components/Button";
import { openLobby, type LobbyConnection } from "../online/client";

interface Props {
  profile: OnlineProfile;
  onBack: () => void;
  onMatched: (roomId: string, opponent: OnlineProfile) => void;
  /** Lobby ответил bot_fallback — никого нет, играем с ботом локально. */
  onBotFallback: () => void;
}

type Phase = "idle" | "connecting" | "queued" | "error";

export function OnlineMenuScreen({ profile, onBack, onMatched, onBotFallback }: Props) {
  const [phase, setPhase] = useState<Phase>("idle");
  const [position, setPosition] = useState<number>(0);
  const [errorMsg, setErrorMsg] = useState<string>("");
  const lobbyRef = useRef<LobbyConnection | null>(null);

  useEffect(() => {
    return () => {
      lobbyRef.current?.close();
    };
  }, []);

  function startQuickPlay() {
    setPhase("connecting");
    setErrorMsg("");
    const lobby = openLobby({
      onQueued: (pos) => {
        setPhase("queued");
        setPosition(pos);
      },
      onMatched: (roomId, opponent) => {
        lobby.close();
        onMatched(roomId, opponent);
      },
      onBotFallback: () => {
        lobby.close();
        onBotFallback();
      },
      onError: (reason) => {
        setPhase("error");
        setErrorMsg(reason);
      },
      onClose: () => {
        // Если ещё не получили matched — считаем что отвалились.
        setPhase((p) => (p === "queued" || p === "connecting" ? "error" : p));
        setErrorMsg((e) => e || "Соединение разорвано");
      },
    });
    lobbyRef.current = lobby;
    // Сразу шлём queue с профилем
    setTimeout(() => lobby.send({ type: "queue", profile }), 50);
  }

  function cancelQueue() {
    lobbyRef.current?.send({ type: "cancel" });
    lobbyRef.current?.close();
    lobbyRef.current = null;
    setPhase("idle");
  }

  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={phase === "queued" ? cancelQueue : onBack}>
          ←
        </button>
        <div className="setup-title">Онлайн</div>
        <span className="mode-badge">pvp · pk</span>
      </div>

      <div className="setup-body">
        <section className="setup-sec">
          <div className="sec-cap">Игра с живым соперником</div>
          {phase === "idle" && (
            <Button kind="primary" className="start-btn" onClick={startQuickPlay}>
              ▶ Найти случайного соперника
            </Button>
          )}
          {phase === "connecting" && <div className="status-bar">Подключение к серверу…</div>}
          {phase === "queued" && (
            <>
              <div className="status-bar">
                Поиск соперника · ты {position}-й в очереди
              </div>
              <div className="ach-list" style={{ marginTop: 12 }}>
                <div className="ach-card unlocked">
                  <div className="ach-ico">🌐</div>
                  <div className="ach-text">
                    <div className="ach-title">{profile.nick}</div>
                    <div className="ach-desc">в поиске…</div>
                  </div>
                </div>
              </div>
              <Button kind="ghost" className="start-btn" onClick={cancelQueue}>
                Отменить
              </Button>
            </>
          )}
          {phase === "error" && (
            <>
              <div className="status-bar">Ошибка: {errorMsg || "соединение разорвано"}</div>
              <Button kind="primary" className="start-btn" onClick={startQuickPlay}>
                Попробовать снова
              </Button>
              <Button kind="ghost" className="start-btn" onClick={onBack}>
                В меню
              </Button>
            </>
          )}
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Как это работает</div>
          <div className="ach-card">
            <div className="ach-ico">⚡</div>
            <div className="ach-text">
              <div className="ach-title">Server-authoritative</div>
              <div className="ach-desc">ходы валидируются на сервере, синхронизация через WebSocket. Без таймера — играем спокойно.</div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
