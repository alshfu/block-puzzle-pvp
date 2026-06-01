import { SKINS, type SkinDef, type SkinId } from "../shop/skins";
import type { PlayerSkins } from "../storage/skins";

interface Props {
  coins: number;
  player: PlayerSkins;
  onBuy: (skin: SkinDef) => void;
  onEquip: (id: SkinId) => void;
  onBack: () => void;
}

export function ShopScreen({ coins, player, onBuy, onEquip, onBack }: Props) {
  return (
    <div className="screen setup-screen">
      <div className="setup-head">
        <button className="back-link" onClick={onBack}>
          ←
        </button>
        <div className="setup-title">Магазин</div>
        <span className="coin-chip read-only" title="Монеты">
          <span className="coin-icon">🪙</span>
          <span className="coin-amount">{coins}</span>
        </span>
      </div>

      <div className="setup-body">
        <section className="setup-sec">
          <div className="sec-cap">Скины клеток</div>
          <div className="shop-list">
            {SKINS.map((s) => (
              <SkinCard
                key={s.id}
                def={s}
                owned={player.unlocked.includes(s.id)}
                equipped={player.equipped === s.id}
                canBuy={coins >= s.price}
                onBuy={() => onBuy(s)}
                onEquip={() => onEquip(s.id)}
              />
            ))}
          </div>
        </section>

        <section className="setup-sec">
          <div className="sec-cap">Как заработать</div>
          <div className="ach-card">
            <div className="ach-ico">🎯</div>
            <div className="ach-text">
              <div className="ach-title">Играй и выполняй дейли</div>
              <div className="ach-desc">
                +N монет за каждые 8 очков, +10 за победу, +N за ежедневные задания.
              </div>
            </div>
          </div>
        </section>
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
