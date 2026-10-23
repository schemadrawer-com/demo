-- The rules the data has to meet become the database's business: keys, constraints, and what is
-- computed rather than typed in.

-- Every pet and every owner has a name; a pet's kind may be unknown until its first visit.
ALTER TABLE pets ALTER COLUMN name SET NOT NULL;
ALTER TABLE owners ALTER COLUMN last_name SET NOT NULL;
ALTER TABLE pets ALTER COLUMN type_id DROP NOT NULL;

-- A microchip identifies a pet; a licence number has a shape; a visit does not cost less than nothing.
ALTER TABLE pets ADD COLUMN microchip_number VARCHAR(15);
ALTER TABLE pets ADD CONSTRAINT uq_pets_microchip_number UNIQUE (microchip_number);
ALTER TABLE vets ADD CONSTRAINT ck_vets_license_number CHECK (license_number ~ '^[A-Z]{2}-[0-9]{6}$');
ALTER TABLE visits ADD CONSTRAINT ck_visits_price CHECK (price >= 0);

-- A family shares a telephone. A pet born before 2000 is a typo - a check constraint cannot be
-- altered, so the old one goes and a new one comes.
ALTER TABLE owners DROP CONSTRAINT uq_owners_telephone;
ALTER TABLE pets DROP CONSTRAINT ck_pets_birth_date;
ALTER TABLE pets ADD CONSTRAINT ck_pets_birth_date CHECK (birth_date > DATE '2000-01-01');

-- Keys: the pair that was merely unique is the key of vet_specialties; a schedule is keyed by vet
-- and day rather than by a number, and points at its vet.
ALTER TABLE vet_specialties DROP CONSTRAINT vet_specialties_vet_id_specialty_id_key;
ALTER TABLE vet_specialties ADD CONSTRAINT pk_vet_specialties PRIMARY KEY (vet_id, specialty_id);
ALTER TABLE vet_schedules DROP CONSTRAINT vet_schedules_pkey;
ALTER TABLE vet_schedules DROP CONSTRAINT uq_vet_schedules_vet_id_day;
ALTER TABLE vet_schedules ADD CONSTRAINT pk_vet_schedules PRIMARY KEY (vet_id, day);
ALTER TABLE vet_schedules ADD CONSTRAINT fk_vet_schedules_vet FOREIGN KEY (vet_id) REFERENCES vets (id);

-- A visit may name a vet who has since left, and been deleted.
ALTER TABLE visits DROP CONSTRAINT visits_vet_id_fkey;

-- Computed rather than typed in: a schedule's minutes, and a total that knows about discounts.
-- Owners spell their full name as they like.
ALTER TABLE vet_schedules DROP COLUMN minutes;
ALTER TABLE vet_schedules ADD COLUMN minutes INT NOT NULL GENERATED ALWAYS AS (EXTRACT(EPOCH FROM ends_at - starts_at)::INT / 60) STORED;
ALTER TABLE billing.invoices ADD COLUMN discount NUMERIC(10, 2) NOT NULL DEFAULT 0;
ALTER TABLE billing.invoices DROP COLUMN total;
ALTER TABLE billing.invoices ADD COLUMN total NUMERIC(10, 2) GENERATED ALWAYS AS (amount + tax - discount) STORED;
ALTER TABLE owners ALTER COLUMN full_name DROP EXPRESSION;

-- Two specialties of one name, however spelt, are one: a unique index over the lower-cased name
-- replaces the plain one. An owner may have two pets of one name after all.
DROP INDEX idx_specialties_name;
CREATE UNIQUE INDEX idx_specialties_name_unique ON specialties (lower(name));
DROP INDEX unique_owner_pet_name;
