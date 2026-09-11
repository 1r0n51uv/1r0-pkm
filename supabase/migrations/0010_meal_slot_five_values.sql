-- ADR-0029: 5 slot pasto (colazione, spuntino mattina, pranzo, spuntino
-- pomeriggio, cena) al posto dei 4 storici. Il valore 'snack' resta nel tipo
-- (nessun DROP possibile su un enum value in uso) ma non viene più scritto
-- dal client: le righe esistenti restano valide, quelle nuove usano gli slot
-- distinti mattina/pomeriggio.
alter type meal_slot add value if not exists 'morning_snack';
alter type meal_slot add value if not exists 'afternoon_snack';
