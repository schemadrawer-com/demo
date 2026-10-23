-- Every pet gets a nickname - but the table is misspelt. Flyway refuses the migration, the check
-- fails, and the comment on the pull request says what Flyway said.
ALTER TABLE pet ADD COLUMN nickname TEXT;
