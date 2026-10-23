-- Reports and automation: a schema for reporting with its views, a function and a procedure that
-- refreshes them; the views the application shows, revised; and what the database does on its own.

CREATE SCHEMA reporting;

-- Owners are searched by a part of their name.
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_owners_last_name_trgm ON owners USING gin (last_name gin_trgm_ops);

-- Types: a pet has a sex, a visit may be missed, and the address type was never used.
CREATE TYPE pet_sex AS ENUM ('female', 'male');
ALTER TABLE pets ADD COLUMN sex pet_sex;
ALTER TYPE visit_status ADD VALUE 'no_show';
DROP TYPE postal_address;

-- Sequences: reports are numbered; invoice numbers leave room between them; a visit's number is its id now.
CREATE SEQUENCE reporting.report_number_seq START WITH 1 INCREMENT BY 1;
ALTER SEQUENCE billing.invoice_number_seq INCREMENT BY 10;
DROP SEQUENCE visit_number_seq;

-- Views: an owner's pets with their age; the vets' specialties as a report rather than a view;
-- unpaid invoices as a plain view, which needs no refreshing; visits per vet with how long they
-- take; the revenue by month.
CREATE OR REPLACE VIEW v_owner_pets AS
    SELECT o.id AS owner_id, o.full_name, p.id AS pet_id, p.name AS pet_name, t.name AS pet_type,
           pet_age_in_years(p.birth_date) AS pet_age
    FROM owners o
    JOIN pets p ON p.owner_id = o.id
    JOIN types t ON t.id = p.type_id;

DROP VIEW v_vet_specialties;
CREATE MATERIALIZED VIEW reporting.mv_vet_specialties AS
    SELECT v.id AS vet_id, v.first_name, v.last_name, string_agg(s.name, ', ' ORDER BY s.name) AS specialties
    FROM vets v
    LEFT JOIN vet_specialties vs ON vs.vet_id = v.id
    LEFT JOIN specialties s ON s.id = vs.specialty_id
    GROUP BY v.id;

DROP MATERIALIZED VIEW billing.mv_unpaid_invoices;
CREATE VIEW billing.v_unpaid_invoices AS
    SELECT id, number, visit_id, amount, issued_on
    FROM billing.invoices
    WHERE NOT paid;

DROP MATERIALIZED VIEW mv_visits_per_vet;
CREATE MATERIALIZED VIEW mv_visits_per_vet AS
    SELECT vet_id, count(*) AS visits, sum(price) AS revenue, avg(duration_minutes) AS average_minutes
    FROM visits
    GROUP BY vet_id;

CREATE VIEW reporting.v_revenue_per_month AS
    SELECT date_trunc('month', visit_date)::DATE AS month, count(*) AS visits, sum(price) AS revenue
    FROM visits
    WHERE status = 'completed'
    GROUP BY 1;

-- Functions and procedures: a pet's age counts birthdays; the revenue between two dates; every
-- report refreshed at once; archiving no longer leaves cancelled visits alone.
CREATE OR REPLACE FUNCTION pet_age_in_years(birth_date DATE) RETURNS INT LANGUAGE SQL STABLE AS $$
    SELECT EXTRACT(YEAR FROM age(CURRENT_DATE, birth_date))::INT
$$;

CREATE FUNCTION reporting.revenue_between(since DATE, until DATE) RETURNS NUMERIC LANGUAGE SQL STABLE AS $$
    SELECT coalesce(sum(price), 0)
    FROM visits
    WHERE visit_date BETWEEN since AND until AND status = 'completed'
$$;

CREATE PROCEDURE reporting.refresh_reports() LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW mv_visits_per_vet;
    REFRESH MATERIALIZED VIEW reporting.mv_vet_specialties;
END
$$;

CREATE OR REPLACE PROCEDURE archive_visits(before DATE) LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM visits WHERE visit_date < before AND status IN ('completed', 'cancelled');
END
$$;

-- Triggers: a completed visit stays completed; owners are stamped when inserted as well; the
-- application sets the price of a visit now.
CREATE FUNCTION check_visit_status() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = 'completed' AND NEW.status <> 'completed' THEN
        RAISE EXCEPTION 'A completed visit stays completed';
    END IF;
    RETURN NEW;
END
$$;
CREATE TRIGGER trg_visits_status BEFORE UPDATE OF status ON visits
    FOR EACH ROW EXECUTE FUNCTION check_visit_status();

DROP TRIGGER trg_owners_touch ON owners;
CREATE TRIGGER trg_owners_touch BEFORE INSERT OR UPDATE ON owners
    FOR EACH ROW EXECUTE FUNCTION touch_owner();

DROP TRIGGER trg_visits_default_price ON visits;
DROP FUNCTION default_visit_price();
