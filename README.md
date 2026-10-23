# SchemaDrawer demo

The pet clinic of [spring-petclinic](https://github.com/spring-projects/spring-petclinic), its
schema kept in [Flyway](https://flywaydb.org) migrations for PostgreSQL 18, and the
[SchemaDrawer action](https://github.com/schemadrawer-com/action) commenting on every pull request
that changes them: what the pull request changes in the schema, how risky each change is, and the
diagram of it, with what the pull request adds in green and what it removes in red.

## The schema

| Migration | What it brings |
|---|---|
| `V1__petclinic.sql` | The clinic's tables: vets, specialties, types, owners, pets, visits. |
| `V2__add_owner_phone.sql`, `V3__add_visit_notes.sql` | A column each. |
| `V4__clinic_back_office.sql` | The back office: a schema for billing and one for the audit trail, types, sequences, views and materialized views, functions, procedures, triggers, generated columns, unique and check constraints. |

## The scenarios

Each directory under [`scenarios/`](scenarios) is a pull request waiting to be opened: the files it
adds, and in `PULL_REQUEST.md` its title and description. The scenarios are independent of each
other - each touches its own part of the schema - so they can be open side by side and be merged
in any order.

| Scenario | The pull request | What the comment shows |
|---|---|---|
| `clinics` | Vets and visits belong to a clinic | 🟢 Additions only: a table, columns, foreign keys, indexes, a view, a function. |
| `spring-cleaning` | Spring cleaning: drop what the application no longer uses | 🔴 A schema, a table and columns dropped, a column's type changed, a column renamed - which reads as one dropped and one added. 🟠 Triggers, functions, a procedure, a sequence, an index and an extension dropped, and a view changed by the rename. |
| `data-rules` | Let the database enforce the rules of the data | 🟠 A primary key added and one changed, unique and check constraints and unique indexes added and dropped, an index and a foreign key dropped, columns made `NOT NULL`, made generated, made not generated, given a new expression. 🟢 A column made nullable, columns and a foreign key added. |
| `reports` | Reports and automation | 🟢 A schema, an extension, a type, a sequence, views, a materialized view, functions, a procedure, a column and an index added. 🟠 The same kinds changed, most of them dropped as well; a trigger added, one changed and one dropped. |
| `no-schema-change` | Greet the user | Nothing: the migrations are not touched, so nothing is drawn and no comment is posted. |
| `broken-migration` | A nickname for every pet | The migration fails on a misspelt table name: the check fails, and the comment carries Flyway's message. |

To open one:

```bash
scripts/open-scenario.sh clinics
```

The script branches off `origin/main`, adds the scenario's files, pushes the branch and opens the
pull request with [`gh`](https://cli.github.com) - or, without it, prints the address to open it
at. By hand, the same is:

```bash
git fetch origin && git switch -c clinics origin/main
cp scenarios/clinics/migrations/* migrations/
git add migrations && git commit -m "Vets and visits belong to a clinic" && git push -u origin clinics
```

## The workflow

[`.github/workflows/build.yml`](.github/workflows/build.yml) builds the application with Maven
and, on a pull request, runs the action beside it:

```yaml
      - uses: schemadrawer-com/action@v3
        with:
          sql-directory: migrations
          migration-type: FLYWAY
          database-type: POSTGRESQL
          database-version: '18'
```

The job needs `pull-requests: write` to comment and `id-token: write` for the token GitHub signs
for the run, which goes along with the upload. No secret is needed.
