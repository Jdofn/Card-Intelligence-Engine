# Third-party notices

This project integrates the following upstream Ruby libraries and metadata references.

## credit_card_bins

- Project: https://github.com/hugolantaume/credit_card_bins
- Copyright: Copyright (c) 2014 Hugo Lantaume
- License: MIT
- Used as a runtime dependency; upstream source/data are not vendored in this repository.

## credit-card-finder

- Project: https://github.com/serverscom/credit-card-finder
- Copyright: Copyright (c) 2018 Sergei Alekseenko
- License: MIT
- Its local-first / remote-fallback strategy pattern informed the architecture. This repository uses a fresh implementation rather than copying its source files.

## Historical BIN reference Gist

- Source: https://gist.github.com/mahmoudimus/4bdf559c943d4c69640a748e1b94aa3d
- File: `bin_db.sql`
- Published: 2020-06-30
- License: No explicit reuse license is declared on the Gist.
- Integration: fetched at runtime as an optional, last-resort metadata reference; the SQL dump is not vendored or redistributed. Results are labeled with the source and dataset date because entries may be obsolete or inaccurate.

The MIT license permits reuse subject to retaining the copyright and permission notices when distributing copies or substantial portions. See each MIT project's LICENSE file for the complete text.
