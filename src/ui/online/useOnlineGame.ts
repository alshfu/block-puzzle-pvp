import { useCallback, useEffect, useRef, useState } from "react";
import type { OnlineGameState, OnlineProfile, RoomServer2Client } from "../../../party/protocol";
import { openRoom, type RoomConnection } from "./client";

interface State {
  state: OnlineGameState | null;
  you: 0 | 1 | null;
  connected: boolean;
  opponentLeft: boolean;
  lastError: string | null;
  /** Тик последнего отказа в ходе — для shake-анимации. */
  rejectTick: number;
  /** Последняя инфа о ходе соперника для UI-эффектов. */
  lastMove?: { owner: 0 | 1; gained: number; perfect: boolean };
  rematchYours: boolean;
  rematchTheirs: boolean;
}

export interface UseOnlineGameApi {
  state: State;
  sendMove: (pieceId: string, cells: [number, number][], r: number, c: number) => void;
  resign: () => void;
  requestRematch: (want: boolean) => void;
  close: () => void;
}

export function useOnlineGame(roomId: string, profile: OnlineProfile): UseOnlineGameApi {
  const [s, setS] = useState<State>({
    state: null,
    you: null,
    connected: false,
    opponentLeft: false,
    lastError: null,
    rejectTick: 0,
    rematchYours: false,
    rematchTheirs: false,
  });
  const connRef = useRef<RoomConnection | null>(null);

  useEffect(() => {
    const conn = openRoom(roomId, {
      onOpen: () => {
        setS((p) => ({ ...p, connected: true, lastError: null }));
        conn.send({ type: "hello", profile });
      },
      onClose: () => {
        setS((p) => ({ ...p, connected: false }));
      },
      onMessage: (msg: RoomServer2Client) => {
        if (msg.type === "joined") {
          setS((p) => ({ ...p, you: msg.you, state: msg.state, opponentLeft: false, rematchYours: false, rematchTheirs: false }));
        } else if (msg.type === "state") {
          setS((p) => ({
            ...p,
            state: msg.state,
            opponentLeft: false,
            // Если сервер прислал свежий "playing" — это значит начался новый раунд (rematch).
            rematchYours: msg.state.status === "playing" ? false : p.rematchYours,
            rematchTheirs: msg.state.status === "playing" ? false : p.rematchTheirs,
            lastMove:
              msg.lastMoveOwner !== undefined
                ? { owner: msg.lastMoveOwner, gained: msg.gained ?? 0, perfect: msg.perfect ?? false }
                : p.lastMove,
          }));
        } else if (msg.type === "opponent_left") {
          setS((p) => ({ ...p, opponentLeft: true }));
        } else if (msg.type === "opponent_reconnected") {
          setS((p) => ({ ...p, opponentLeft: false }));
        } else if (msg.type === "move_rejected") {
          setS((p) => ({ ...p, lastError: msg.reason, rejectTick: p.rejectTick + 1 }));
        } else if (msg.type === "rematch_status") {
          setS((p) => ({ ...p, rematchYours: msg.yours, rematchTheirs: msg.theirs }));
        } else if (msg.type === "error") {
          setS((p) => ({ ...p, lastError: msg.reason }));
        }
      },
    });
    connRef.current = conn;
    return () => {
      conn.close();
      connRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [roomId]);

  const sendMove = useCallback(
    (pieceId: string, cells: [number, number][], r: number, c: number) => {
      connRef.current?.send({ type: "move", pieceId, cells, r, c });
    },
    [],
  );
  const resign = useCallback(() => connRef.current?.send({ type: "resign" }), []);
  const requestRematch = useCallback((want: boolean) => {
    connRef.current?.send({ type: want ? "rematch_request" : "rematch_cancel" });
  }, []);
  const close = useCallback(() => connRef.current?.close(), []);

  return { state: s, sendMove, resign, requestRematch, close };
}
