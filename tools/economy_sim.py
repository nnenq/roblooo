#!/usr/bin/env python3
"""Economy simulator for Greedy Slimes.

Models a player doing runs (grab a slime -> hold it while it evolves -> carry it
home), placing slimes on pedestals and buying upgrades. Reports how many hours of
active play each milestone takes for different spending profiles.

The constants below are the design source of truth for the economy until they are
ported to Luau configs. Run:  python3 tools/economy_sim.py
"""

from __future__ import annotations

import argparse
import math
import random
import statistics
from dataclasses import dataclass, field

# --- Slimes -----------------------------------------------------------------

TIERS = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
BASE_INCOME = [1, 3, 10, 35, 120, 450, 2000]  # coins/s per tier
HOLD_TIME = [0, 6, 14, 25, 40, 60]  # cumulative hold seconds to reach tier (Secret via overheat)
SPEED_PENALTY = [0, 0.05, 0.10, 0.16, 0.23, 0.31, 0.40]
VISIBILITY = [0, 0, 0, 0.5, 1.0, 1.5, 2.0]  # how much other players hunt you
SECRET = 6
MYTHIC = 5

OVERHEAT_INTERVAL = 3  # s between overheat rolls once Mythic
OVERHEAT_SECRET = 0.04
OVERHEAT_POP = 0.08
OVERHEAT_MAX_ROLLS = 8

MUTATIONS = [(0.05, 2), (0.02, 3), (0.005, 6), (0.001, 15)]  # (chance, multiplier)
SELL_SECONDS = 20  # selling a slime pays this many seconds of its income

# --- World ------------------------------------------------------------------


@dataclass(frozen=True)
class Zone:
    name: str
    dist: float  # studs from base, one way
    start_tier: int
    max_tier: int  # slimes from this zone stop evolving here (Mythic -> overheat to Secret)
    mult: float
    speed_lvl: int  # speed upgrade level needed to enter
    hazard: float  # hunter + tide hazard per second while carrying Rare+
    rebirth: int = 0


ZONES = [
    Zone("Jelly Meadow", 50, 0, 2, 1, 0, 0.004),
    Zone("Crystal Caves", 110, 1, 4, 1.5, 12, 0.008),
    Zone("Cloud Volcano", 190, 2, 6, 2.5, 30, 0.012),
    Zone("Glitch Zone", 300, 3, 6, 4, 42, 0.016, rebirth=1),
]
PVP_HAZARD = 0.006  # per second per visibility unit (moderately full server)
SEARCH_TIME = 4
DEPOSIT_TIME = 2

# --- Upgrades ---------------------------------------------------------------

BASE_WALK = 16
WALK_PER_LVL = 0.8
SPEED_MAX = 60


def speed_cost(lvl: int) -> float:
    return 1500 * 1.29**lvl


SLOT_START = 4
SLOT_MAX = 24


def slot_cost(slots: int) -> float:
    return 300 * 1.6 ** (slots - SLOT_START)


GRIP_PER_LVL = 0.03
GRIP_MAX = 10


def grip_cost(lvl: int) -> float:
    return 2000 * 2.2**lvl


REBIRTH_COST = [120_000_000, 900_000_000, 4_000_000_000]
REBIRTH_BONUS = 0.5  # additive income multiplier per rebirth

OFFLINE_RATE = 0.5

# --- Spending profiles ------------------------------------------------------


@dataclass(frozen=True)
class Profile:
    key: str
    label: str
    robux: str
    money_bonus: float = 0.0  # additive: VIP +0.5, 2x Money +1.0, Club +0.25
    walk_mult: float = 1.0  # Speed Boots (does not count toward zone gates)
    extra_slots: int = 0
    luck: float = 1.0
    grip_bonus: float = 0.0
    starter_pack: bool = False
    offline_cap_h: float = 2.0
    ads_boost: float = 0.0  # average extra income from rewarded ads
    hourly_coin_packs: float = 0.0  # "1 hour of income" packs bought per hour


PROFILES = [
    Profile("f2p", "F2P (без доната)", "0"),
    Profile("f2p_ads", "F2P + реклама за награду", "0", ads_boost=0.25),
    Profile("starter", "Стартовый набор", "49", starter_pack=True),
    Profile("vip", "Стартовый + VIP", "348", money_bonus=0.5, starter_pack=True, offline_cap_h=6),
    Profile(
        "core",
        "Стартовый + VIP + x2 Монеты",
        "697",
        money_bonus=1.5,
        starter_pack=True,
        offline_cap_h=6,
    ),
    Profile(
        "whale",
        "Кит: все пассы + паки монет",
        "~1 400 + ~200/ч",
        money_bonus=1.5,
        walk_mult=1.3,
        extra_slots=6,
        luck=2.0,
        starter_pack=True,
        offline_cap_h=6,
        hourly_coin_packs=2,
    ),
]

MILESTONES = [
    ("zone2", "Зона 2 (пещеры)"),
    ("zone3", "Зона 3 (вулкан)"),
    ("legendary", "Первый Legendary"),
    ("mythic", "Первый Mythic"),
    ("secret", "Первый Secret"),
    ("rebirth1", "Ребёрт 1"),
    ("rebirth2", "Ребёрт 2"),
    ("rebirth3", "Ребёрт 3"),
]


# --- Simulation -------------------------------------------------------------


@dataclass
class Player:
    profile: Profile
    rng: random.Random
    coins: float = 0.0
    speed_lvl: int = 0
    slots: int = SLOT_START
    grip_lvl: int = 0
    rebirths: int = 0
    pedestals: list[tuple[float, int]] = field(default_factory=list)  # (income/s, tier)
    t: float = 0.0
    boost_until: float = 0.0
    milestones: dict[str, float] = field(default_factory=dict)

    # derived ---------------------------------------------------------------
    def income_mult(self) -> float:
        m = 1 + self.profile.money_bonus + REBIRTH_BONUS * self.rebirths + self.profile.ads_boost
        if self.t < self.boost_until:
            m *= 2
        return m

    def income_rate(self) -> float:
        return sum(inc for inc, _ in self.pedestals) * self.income_mult()

    def walk(self) -> float:
        return (BASE_WALK + WALK_PER_LVL * self.speed_lvl) * self.profile.walk_mult

    def grip(self) -> float:
        return min(0.6, GRIP_PER_LVL * self.grip_lvl + self.profile.grip_bonus)

    def max_slots(self) -> int:
        return self.slots + self.profile.extra_slots

    def zones(self) -> list[Zone]:
        return [z for z in ZONES if self.speed_lvl >= z.speed_lvl and self.rebirths >= z.rebirth]

    def mark(self, key: str) -> None:
        self.milestones.setdefault(key, self.t)

    # time ------------------------------------------------------------------
    def advance(self, dt: float) -> None:
        self.coins += self.income_rate() * dt
        self.t += dt

    # runs ------------------------------------------------------------------
    def carry_plan(self, zone: Zone, target: int) -> tuple[float, float]:
        """Return (carry seconds until Mythic/target reached and home, survival probability)."""
        top = min(target, MYTHIC)
        hold_needed = HOLD_TIME[top] - HOLD_TIME[zone.start_tier]
        walk_home = zone.dist / (self.walk() * (1 - SPEED_PENALTY[top]))
        carry = max(hold_needed, walk_home)
        exposure = 0.0
        for tier in range(zone.start_tier, top):
            exposure += self.hazard(zone, tier) * (HOLD_TIME[tier + 1] - HOLD_TIME[tier])
        exposure += self.hazard(zone, top) * (carry - hold_needed)
        return carry, math.exp(-exposure * (1 - self.grip()))

    def hazard(self, zone: Zone, tier: int) -> float:
        hunters = zone.hazard if tier >= 2 else 0.0
        return hunters + PVP_HAZARD * VISIBILITY[tier]

    def slime_value(self, zone: Zone, tier: int) -> float:
        return BASE_INCOME[tier] * zone.mult

    def marginal(self, value: float) -> float:
        if len(self.pedestals) < self.max_slots():
            return value
        worst = min(inc for inc, _ in self.pedestals)
        return max(0.0, value - worst) + min(value, worst) * SELL_SECONDS / 600

    def choose_run(self) -> tuple[Zone, int]:
        best, best_rate = (ZONES[0], 0), -1.0
        out_speed = self.walk()
        for zone in self.zones():
            for target in range(zone.start_tier, zone.max_tier + 1):
                carry, p = self.carry_plan(zone, target)
                value = self.slime_value(zone, min(target, MYTHIC))
                if target == SECRET:
                    p_secret, extra = overheat_odds(self.hazard(zone, MYTHIC) * (1 - self.grip()))
                    carry += extra
                    value = (
                        p_secret * self.slime_value(zone, SECRET)
                        + (1 - p_secret) * 0.3 * value  # mythic kept if rolls run out, else popped
                    )
                run_time = zone.dist / out_speed + SEARCH_TIME + carry + DEPOSIT_TIME
                rate = p * self.marginal(value) / run_time
                if rate > best_rate:
                    best, best_rate = (zone, target), rate
        return best

    def do_run(self) -> None:
        zone, target = self.choose_run()
        carry, p = self.carry_plan(zone, target)
        run_time = zone.dist / self.walk() + SEARCH_TIME + carry + DEPOSIT_TIME
        if self.rng.random() >= p:
            self.advance(run_time * 0.75)
            return
        tier = min(target, MYTHIC)
        if target == SECRET:
            haz = self.hazard(zone, MYTHIC) * (1 - self.grip())
            for _ in range(OVERHEAT_MAX_ROLLS):
                run_time += OVERHEAT_INTERVAL
                if self.rng.random() < 1 - math.exp(-haz * OVERHEAT_INTERVAL):
                    self.advance(run_time)
                    return
                roll = self.rng.random()
                if roll < OVERHEAT_SECRET:
                    tier = SECRET
                    break
                if roll < OVERHEAT_SECRET + OVERHEAT_POP:
                    self.advance(run_time)
                    return
        self.advance(run_time)
        self.deliver(self.slime_value(zone, tier) * self.roll_mutation(), tier)

    def roll_mutation(self) -> float:
        roll = self.rng.random()
        acc = 0.0
        for chance, mult in reversed(MUTATIONS):
            acc += chance * self.profile.luck
            if roll < acc:
                return mult
        return 1.0

    def deliver(self, value: float, tier: int) -> None:
        for key, need in (("legendary", 4), ("mythic", 5), ("secret", 6)):
            if tier >= need:
                self.mark(key)
        if len(self.pedestals) < self.max_slots():
            self.pedestals.append((value, tier))
            return
        worst_i = min(range(len(self.pedestals)), key=lambda i: self.pedestals[i][0])
        worst = self.pedestals[worst_i][0]
        if value > worst:
            self.coins += worst * SELL_SECONDS
            self.pedestals[worst_i] = (value, tier)
        else:
            self.coins += value * SELL_SECONDS

    # spending --------------------------------------------------------------
    def can_rebirth(self) -> bool:
        return self.rebirths < len(REBIRTH_COST) and any(
            tier >= MYTHIC for _, tier in self.pedestals
        )

    def saving_for_rebirth(self) -> bool:
        if not self.can_rebirth():
            return False
        return REBIRTH_COST[self.rebirths] <= self.income_rate() * 1200  # within 20 min

    def try_rebirth(self) -> None:
        if self.can_rebirth() and self.coins >= REBIRTH_COST[self.rebirths]:
            self.rebirths += 1
            self.mark(f"rebirth{self.rebirths}")
            self.coins = 0
            self.speed_lvl = 0
            self.slots = SLOT_START
            self.grip_lvl = 0
            self.pedestals = []

    def buy_upgrades(self) -> None:
        if self.saving_for_rebirth():
            return
        while True:
            options = []
            if self.speed_lvl < SPEED_MAX:
                options.append((speed_cost(self.speed_lvl), "speed"))
            if self.slots < SLOT_MAX:
                options.append((slot_cost(self.slots), "slot"))
            if self.grip_lvl < GRIP_MAX and self.speed_lvl >= ZONES[1].speed_lvl:
                options.append((grip_cost(self.grip_lvl), "grip"))
            if not options:
                return
            cost, kind = min(options)
            if cost > self.coins:
                return
            self.coins -= cost
            if kind == "speed":
                self.speed_lvl += 1
            elif kind == "slot":
                self.slots += 1
            else:
                self.grip_lvl += 1
            for i, zone in enumerate(ZONES[1:3], start=2):
                if self.speed_lvl >= zone.speed_lvl:
                    self.mark(f"zone{i}")


def overheat_odds(haz: float) -> tuple[float, float]:
    """Probability of reaching Secret during overheat, and expected extra seconds."""
    survive = math.exp(-haz * OVERHEAT_INTERVAL)
    p_secret, alive, extra = 0.0, 1.0, 0.0
    for _ in range(OVERHEAT_MAX_ROLLS):
        extra += alive * OVERHEAT_INTERVAL
        alive *= survive
        p_secret += alive * OVERHEAT_SECRET
        alive *= 1 - OVERHEAT_SECRET - OVERHEAT_POP
    return p_secret, extra


def simulate(profile: Profile, seed: int, hours_per_day: float, max_hours: float) -> Player:
    p = Player(profile, random.Random(seed))
    p.pedestals.append((BASE_INCOME[1], 1))  # free Uncommon from the tutorial
    if profile.starter_pack:
        p.pedestals.append((BASE_INCOME[3], 3))  # Epic slime
        p.boost_until = 3600
    next_day = hours_per_day * 3600
    next_pack = 1800
    while p.t < max_hours * 3600 and "rebirth3" not in p.milestones:
        p.buy_upgrades()
        p.try_rebirth()
        p.do_run()
        if profile.hourly_coin_packs and p.t >= next_pack:
            p.coins += p.income_rate() * 3600  # "1 hour of income" pack
            next_pack += 3600 / profile.hourly_coin_packs
        if hours_per_day and p.t >= next_day:
            p.coins += p.income_rate() * OFFLINE_RATE * min(profile.offline_cap_h, 24 - hours_per_day) * 3600
            next_day += hours_per_day * 3600
    return p


def fmt_hours(seconds: float | None) -> str:
    if seconds is None:
        return "—"
    minutes = seconds / 60
    if minutes < 60:
        return f"{minutes:.0f} мин"
    return f"{minutes / 60:.1f} ч"


def run(runs: int, hours_per_day: float, max_hours: float) -> dict[str, dict[str, float | None]]:
    table: dict[str, dict[str, float | None]] = {}
    for profile in PROFILES:
        results = [simulate(profile, seed, hours_per_day, max_hours) for seed in range(runs)]
        row: dict[str, float | None] = {}
        for key, _ in MILESTONES:
            times = [r.milestones[key] for r in results if key in r.milestones]
            row[key] = statistics.median(times) if len(times) * 2 >= runs else None
        table[profile.key] = row
    return table


def print_table(table: dict[str, dict[str, float | None]], title: str, days: float = 0) -> None:
    print(f"\n### {title}\n")
    header = "| Этап | " + " | ".join(p.label for p in PROFILES) + " |"
    print(header)
    print("|" + "---|" * (len(PROFILES) + 1))
    for key, label in MILESTONES:
        cells = []
        for p in PROFILES:
            sec = table[p.key][key]
            if days and sec is not None:
                cells.append(f"день {math.ceil(sec / 3600 / days)}")
            else:
                cells.append(fmt_hours(sec))
        print(f"| {label} | " + " | ".join(cells) + " |")
    print("| Цена, R$ | " + " | ".join(p.robux for p in PROFILES) + " |")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=200)
    parser.add_argument("--max-hours", type=float, default=60)
    args = parser.parse_args()

    marathon = run(args.runs, hours_per_day=0, max_hours=args.max_hours)
    print_table(marathon, "Часы активной игры подряд (без офлайн-дохода), медиана")

    daily = run(args.runs, hours_per_day=1, max_hours=args.max_hours)
    print_table(daily, "На какой день при игре 1 ч/день (с офлайн-доходом), медиана", days=1)


if __name__ == "__main__":
    main()
