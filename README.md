# Greedy Slimes 🫧 (рабочее название)

Игра для Roblox. **Хватай слайма: пока держишь, он растёт и становится всё реже. Но чем он круче, тем ты медленнее, тем ярче светишься и тем больше игроков за тобой гонится. Донеси его до базы, или потеряешь всё.**

Визуально это узнаваемый стиль хитов вроде Steal An Egg и Steal a Brainrot. Идея своя: push-your-luck («домой или ещё секунду?»), где внимание врагов ускоряет рост награды, плюс общий для сервера Прилив каждые 2,5 минуты.

## Открыть игру в Roblox Studio

Скачай [`place/GreedySlimes.rbxl`](place/GreedySlimes.rbxl) и открой его в Studio. Внутри весь остров: 4 зоны, 8 плотов, 65 слаймов, Слаймоеды, ворота, вулкан с Коронным гнездом, Глитч-остров и демо Прилива (нажми Play).

![Остров](docs/img/preview-overview.png)

С чего начать по шагам (группа, публикация, подключение Claude к Studio): [docs/09-start-guide.md](docs/09-start-guide.md).

## Документы

| Файл | О чём |
|------|-------|
| [docs/01-research.md](docs/01-research.md) | Анализ рынка Roblox на октябрь 2026: что в топе, почему растёт и почему падает |
| [docs/02-game-design.md](docs/02-game-design.md) | Диздок: цикл, механика «Жадности», угрозы, база, прогрессия, психология, монетизация, стиль |
| [docs/03-roadmap.md](docs/03-roadmap.md) | Этапы, оценка токенов, MVP, метрики, чек-лист запуска, риски |
| [docs/04-setup.md](docs/04-setup.md) | Что установить: Roblox Studio MCP, Claude Code, VS Code-расширения, Rokit/Rojo |
| [docs/05-monetization.md](docs/05-monetization.md) | Донат: что продают хиты, наш прайс, время прохождения с донатом и без, честные правила |
| [docs/06-visual-style.md](docs/06-visual-style.md) | Визуальный стиль: палитра, шрифты, UI, фишки, 3D-сцена, иконка |
| [docs/07-languages-devices.md](docs/07-languages-devices.md) | Языки (4 вручную + 14 автоперевод) и адаптация под телефоны, планшеты, ПК |
| [docs/08-world-3d.md](docs/08-world-3d.md) | 3D-остров: кольца, азарт (Слаймоеды, ворота, Золотое и Коронное гнёзда), 16 слаймов, скины |
| [docs/09-start-guide.md](docs/09-start-guide.md) | Пошагово: аккаунт, группа, Studio, публикация, правила 2026 для детской аудитории, деньги |
| [tools/economy_sim.py](tools/economy_sim.py) | Симулятор экономики: `python3 tools/economy_sim.py` |
| [tools/build_place.luau](tools/build_place.luau) | Сборка `.rbxl` из кода (`lune run tools/build_place.luau`) |

Макет интерфейса (игра, магазин, гайд по стилю): [Greedy Slimes — UI](https://claude.ai/artifact/GeurF4AuuNSLLjr784ZqKZ).

## Статус

- [x] Этап 0 — исследование и план
- [x] Этап 0.5 — донат, баланс экономики (симулятор), визуальный стиль и макет UI
- [ ] Этап 1 — каркас Rojo + ядро логики
- [~] Этап 2 — 3D-остров собран кодом в `place/GreedySlimes.rbxl`; доводка в Studio через MCP
- [ ] Этап 3 — UI, FTUE, монетизация, сохранения
- [ ] Этап 4 — контент v0.2
- [ ] Этап 5 — запуск
