import { useState } from "react";
import { POWERUPS, type PowerupDef } from "../shop/powerups";
import { SKINS, type SkinDef, type SkinId } from "../shop/skins";
import type { Inventory } from "../storage/inventory";
import type { PlayerSkins } from "../storage/skins";
import type { Wallet } from "../storage/wallet";

interface Props {
  wallet: Wallet;
  player: PlayerSkins;
  inventory: Inventory;
  onBuySkin: (skin: SkinDef) => void;
  onEquipSkin: (id: SkinId) => void;
  onBuyPowerup: (p: PowerupDef) => void;
  onBack: () => void;
}

type Tab = "skins" | "powerups";

export function ShopScreen({
  wallet,
  player,
  inventory,
  onBuySkin,
  onEquipSkin,
  onBuyPowerup,
  onBack,
}: Props) {
  const [tab, setTab] = useState<Tab>("powerups");

  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>
          ←
        </button>
        <div className="setup-title">Магазин</div>
        <div className="shop-wallets">
          <span className="coin-chip read-only" title="Монеты">
            <span className="coin-icon">🪙</span>
            <span className="coin-amount">{wallet.coins}</span>
          </span>
          <span className="coin-chip read-only crystal" title="Кристаллы силы (1 кристалл = 150 очков)">
            <span className="coin-icon">💎</span>
            <span className="coin-amount">{wallet.crystals}</span>
          </span>
        </div>
      </div>

      <div className="shop-tabs">
        <button className={`shop-tab ${tab === "powerups" ? "on" : ""}`} onClick={() => setTab("powerups")}>
          💎 Power-ups
        </button>
        <button className={`shop-tab ${tab === "skins" ? "on" : ""}`} onClick={() => setTab("skins")}>
          🪙 Скины
        </button>
      </div>

      <div className="setup-body">
        {tab === "powerups" && (
          <>
            <section className="setup-sec">
              <div className="sec-cap">Бонусы силы (за 💎 кристаллы)</div>
              <div className="shop-list">
                {POWERUPS.map((p) => (
                  <PowerupCard
                    key={p.id}
                    def={p}
                    owned={inventory[p.id]}
                    canBuy={wallet.crystals >= p.price}
                    onBuy={() => onBuyPowerup(p)}
                  />
                ))}
              </div>
            </section>
            <section className="setup-sec">
              <div className="ach-card">
                <div className="ach-ico">💎</div>
                <div className="ach-text">
                  <div className="ach-title">Как получить кристаллы</div>
                  <div className="ach-desc">
                    Каждые 150 очков, набранные за матчи, превращаются в 1 кристалл. Накопленные очки сохраняются — играй, и со временем кристаллы появятся.
                  </div>
                </div>
              </div>
            </section>
          </>
        )}

        {tab === "skins" && (
          <section className="setup-sec">
            <div className="sec-cap">Скины клеток (за 🪙 монеты)</div>
            <div className="shop-list">
              {SKINS.map((s) => (
                <SkinCard
                  key={s.id}
                  def={s}
                  owned={player.unlocked.includes(s.id)}
                  equipped={player.equipped === s.id}
                  canBuy={wallet.coins >= s.price}
                  onBuy={() => onBuySkin(s)}
                  onEquip={() => onEquipSkin(s.id)}
                />
              ))}
            </div>
          </section>
        )}
      </div>
    </div>
  );
}

function PowerupCard({
  def,
  owned,
  canBuy,
  onBuy,
}: {
  def: PowerupDef;
  owned: number;
  canBuy: boolean;
  onBuy: () => void;
}) {
  return (
    <div className="shop-card">
      <div className="powerup-preview">
        <span className="powerup-icon-big">{def.icon}</span>
        <span className="powerup-owned">×{owned}</span>
      </div>
      <div className="shop-text">
        <div className="shop-title">{def.name}</div>
        <div className="shop-desc">{def.description}</div>
        <div className="shop-desc" style={{ opacity: 0.7 }}>{def.hint}</div>
      </div>
      <div className="shop-action">
        <button
          className="resume-btn primary"
          disabled={!canBuy}
          onClick={onBuy}
          title={canBuy ? "Купить за кристаллы" : "Не хватает кристаллов"}
        >
          💎 {def.price}
        </button>
      </div>
    </div>
  );
}

function SkinCard({
  def,
  owned,
  equipped,
  canBuy,
  onBuy,
  onEquip,
}: {
  def: SkinDef;
  owned: boolean;
  equipped: boolean;
  canBuy: boolean;
  onBuy: () => void;
  onEquip: () => void;
}) {
  return (
    <div className={`shop-card ${equipped ? "equipped" : ""}`}>
      <div className="shop-preview">
        <div className={`cell filled owner0 ${def.cssClass}`} />
        <div className={`cell filled owner1 ${def.cssClass}`} />
      </div>
      <div className="shop-text">
        <div className="shop-title">
          {def.icon} {def.name}
        </div>
        <div className="shop-desc">{def.description}</div>
      </div>
      <div className="shop-action">
        {equipped ? (
          <span className="shop-status equipped">в использовании</span>
        ) : owned ? (
          <button className="resume-btn primary" onClick={onEquip}>
            Применить
          </button>
        ) : (
          <button
            className="resume-btn primary"
            disabled={!canBuy}
            onClick={onBuy}
            title={canBuy ? "" : "Не хватает монет"}
          >
            🪙 {def.price}
          </button>
        )}
      </div>
    </div>
  );
}
