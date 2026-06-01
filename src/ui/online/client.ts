import PartySocket from "partysocket";
import type {
  LobbyClient2Server,
  LobbyServer2Client,
  OnlineProfile,
  RoomClient2Server,
  RoomServer2Client,
} from "../../../party/protocol";

/**
 * PartyKit host: можно переопределить через `VITE_PARTY_HOST`. В деве
 * партикит поднимается на `localhost:1999`.
 */
export const PARTY_HOST: string =
  (import.meta.env.VITE_PARTY_HOST as string | undefined) ?? "localhost:1999";

function makeSocket(party: "lobby" | "room", room: string): PartySocket {
  return new PartySocket({
    host: PARTY_HOST,
    party,
    room,
  });
}

// ─── Lobby client ────────────────────────────────────────────────────────

export interface LobbyHandlers {
  onQueued?: (position: number) => void;
  onMatched?: (roomId: string, opponent: OnlineProfile) => void;
  onError?: (reason: string) => void;
  onClose?: () => void;
}

export interface LobbyConnection {
  send: (msg: LobbyClient2Server) => void;
  close: () => void;
}

export function openLobby(handlers: LobbyHandlers): LobbyConnection {
  const ws = makeSocket("lobby", "main");
  ws.addEventListener("message", (e) => {
    let m: LobbyServer2Client;
    try {
      m = JSON.parse(String(e.data));
    } catch {
      return;
    }
    if (m.type === "queued") handlers.onQueued?.(m.position);
    else if (m.type === "matched") handlers.onMatched?.(m.roomId, m.opponent);
    else if (m.type === "error") handlers.onError?.(m.reason);
  });
  ws.addEventListener("close", () => handlers.onClose?.());
  return {
    send: (msg) => ws.send(JSON.stringify(msg)),
    close: () => ws.close(),
  };
}

// ─── Room client ─────────────────────────────────────────────────────────

export interface RoomHandlers {
  onMessage: (msg: RoomServer2Client) => void;
  onClose?: () => void;
  onOpen?: () => void;
}

export interface RoomConnection {
  send: (msg: RoomClient2Server) => void;
  close: () => void;
}

export function openRoom(roomId: string, handlers: RoomHandlers): RoomConnection {
  const ws = makeSocket("room", roomId);
  ws.addEventListener("open", () => handlers.onOpen?.());
  ws.addEventListener("message", (e) => {
    let m: RoomServer2Client;
    try {
      m = JSON.parse(String(e.data));
    } catch {
      return;
    }
    handlers.onMessage(m);
  });
  ws.addEventListener("close", () => handlers.onClose?.());
  return {
    send: (msg) => ws.send(JSON.stringify(msg)),
    close: () => ws.close(),
  };
}
