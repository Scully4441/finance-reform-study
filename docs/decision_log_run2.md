# Author decisions before the Run 2 registration

Decisions the author made before the Run 2 OSF registration is filed that change
or add to a rule in docs/design_extension.md. Section numbers refer to that
document. The log is closed when the registration is filed
(docs/design_extension.md, Section 13); departures from the registered extension
after filing go in docs/deviations_run2.md. Run 1's logs are docs/decision_log.md
and docs/deviations.md.

| Date | Section | Decision | Rationale |
|---|---|---|---|
| 2026-09-01 | 4 | The author accepted the SEDA data use agreement at edopportunity.org on 2026-09-01, before any SEDA file was downloaded. It covers SEDA 2025.2, deposited in the Stanford Digital Repository under DOI 10.25740/np279jm6134, and the three files Section 4 names: `seda_admindist_long_cs_2025.2.csv`, `seda_codebook_admindist_2025.2.xlsx` and `SEDA_documentation_2025.2.pdf`. Under the agreement the files are not deposited on OSF, in full or in part, and neither are the district-level files derived from them: `data/raw/seda/` is on the never-deposited list in data/manifest/README.md, which records the URLs and checksums and tells a reader to obtain the files under the same agreement. | Section 4 makes acceptance of the agreement a condition of the download and forbids publishing the files in full or in part. The date records that acceptance came first, and the manifest and README carry what a reader needs to obtain the same files without the study redistributing them. |
