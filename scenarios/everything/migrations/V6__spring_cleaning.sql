-- Out with what the application no longer uses: the audit trail, which the practice's system of
-- record keeps now; the columns the forms stopped filling in; what nobody calls. One column is
-- renamed and one made shorter - to the database a renamed column is one dropped and one added,
-- and a view that shows it changes with it.

-- The audit trail, with its triggers, its function, its sequence and its schema.
DROP TRIGGER trg_pets_audit ON pets;
DROP TRIGGER trg_visits_audit ON visits;
DROP FUNCTION audit.log_change();
DROP TABLE audit.events;
DROP SEQUENCE audit.event_number_seq;
DROP SCHEMA audit;

-- The forms no longer ask for an address; the telephone has been kept twice since release 2.
ALTER TABLE owners DROP COLUMN address;
ALTER TABLE owners DROP COLUMN phone;
ALTER TABLE owners ALTER COLUMN telephone TYPE VARCHAR(20);

-- A visit has a reason, not a description.
ALTER TABLE visits RENAME COLUMN description TO reason;

-- Pets are looked up by owner, never by name; nobody calls these; nothing is encrypted in the database.
DROP INDEX idx_pets_name;
DROP FUNCTION visits_of(INT);
DROP PROCEDURE billing.mark_paid(INT);
DROP EXTENSION pgcrypto;
