# Данные пилота

Схема продукта не меняется. Используются ERPNext Sales Order → Work Order →
Job Card и Stock Entry; Material Request → Purchase Order → Purchase Receipt;
Sales Order → Delivery Note. Аудит — Comment, повтор — Idempotency Record.
Все имена создаваемых документов получаются из insert/API, не жёстко заданы.
Остатки читаются из Bin и подтверждаются Stock Ledger Entry.
