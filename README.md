# Dig an Egg — питомцы

3D-питомцы для Roblox-игры Dig an Egg в стиле Pet Simulator 99 и Adopt Me!: пухлые чиби, большие глаза,
редкость видна по свечению и эффектам.

| Питомец | Планета | Папка |
|---|---|---|
| Кротик-Росток | 🌱 Зелёная | [`pets/KrotikRostok`](pets/KrotikRostok/README.md) |

`tools/pet-builder` — генератор: одно описание питомца → `.glb`, `.obj`, Luau-модуль и рендеры.
Для рендеров нужен Node с `three@0.160.0` и `playwright`; сама модель собирается одним Python-скриптом
(нужен только `numpy`).
