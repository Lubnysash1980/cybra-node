# @cybra — CYBRA Node Index

Глобальний індекс усіх модулів CYBRA.
Автоматично оновлюється через `cybra_final_build.sh`.

## Структура

- `index.json` — машинночитаний індекс модулів
- `index.txt` — людський формат
- `modules/` — посилання на модулі
- `hashes/` — dual-backend hashes

## Принципи

1. Жоден модуль не виконує auto-money дій.
2. Ліцензія 1% з кожного контракту → `0x66434c5501242ccC71b5a39C765892921624B66c`.
3. Всі snapshots — frozen.
4. Все верифікується через dual-backend SHA-256.
