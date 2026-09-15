# **Extension design: Run 2 of the school finance reform study**

## **1. Purpose and relation to Run 1**

Run 1 is the registered study: reform effects on high school achievement gaps in EDFacts data for school years 2009–10 through 2020–21, registered on OSF and run under a frozen tag. Its pre-registered power calculation classified it as a bounds analysis, and its results are reported as such. This document fixes, before any new outcome file is opened, an extension that adds data the public federal files do not carry. Everything in the Run 1 design (v18) stands unless this document says otherwise; section numbers below refer to this document, and references to "Run 1 Section n" are to v18.

Run 2 is not blinded. The real event table has been in the repository since the Run 1 unblinding, so a permuted table would protect nothing. The protection here is this document, registered on OSF before any Run 2 outcome file is downloaded, together with a second freeze tag before the run. Run 1's results are known to the author and are described in Run 1's report; this document was written after them, and the dissertation reports Run 1 first and Run 2 as the extension.

## **2. What is added**

- **SEDA grades 3–8 outcomes.** The Stanford Education Data Archive, release 2025.2, gives administrative-district means by subgroup for grades 3 through 8 in mathematics and reading/language arts for school years ending 2009 through 2019 and 2022 through 2025. It gives every reform cohort in the event table a post-reform period and removes the suppression problem of the EDFacts files.
- **High school outcomes for 2021–22 through 2024–25 from state report cards.** Thirty-seven states publish a statewide district-level file or export with Black, Hispanic, and White proficiency rates on the high school assessment for all four years; two publish it for three; the rest publish nothing usable. These extend the Run 1 high school panel and give the reforms of 2020 and later a post-period on the study's own outcome.
- **A continuous-treatment estimator.** Reform is measured as the district's per-pupil state-plus-local revenue rather than as a state-year event, with the de Chaisemartin and D'Haultfœuille dynamic estimator for non-binary, non-absorbing treatments.

One addition considered in the Run 2 guide is dropped: state-level EDFacts achievement files exist only for 2021–22, with no assessment file of any kind for 2022–23, so a state-level series would add one year at the state level and nothing to the district analysis.

## **3. Fixed definitions**

| Term | Definition | Source |
|------------------|--------------------------------------------------------------------|------------------|
| Treatment | Unchanged from Run 1 Section 3: the same event files, the same three event sets (full, published list plus final supreme court rulings, court only), the same treatment years. No event coding is revisited. | Run 1 event tables |
| SEDA window | School years ending 2009 through 2019 and 2022 through 2025. 2020 and 2021 do not exist in SEDA. The panel is unbalanced by construction and enters the estimators that way. | SEDA 2025.2 documentation |
| High school window | Run 1's 2010 through 2021 panel extended with report-card years 2022 through 2025 for the states in Section 4. 2020 stays excluded. | Run 1 Section 3; Section 4 below |
| SEDA gaps | (b) district-year Black minus White and (c) district-year Hispanic minus White differences in SEDA cohort-standardized (CS) means, pooled over grades 3–8 and averaged over the two subjects; (a) the state-year enrollment-weighted difference in all-students CS means between the top and bottom 2009 SAIPE child-poverty quintiles. CS units are national standard deviations, so no probit transform is applied. | Section 6 |
| High school report-card gaps | The Run 1 gaps (a), (b), (c) computed from state-published proficiency shares with the Run 1 probit method V, on the state's high school test as reported for federal accountability. | Section 6 |
| Continuous treatment | District per-pupil state-plus-local revenue from F-33, deflated with CPI-U to 2025 dollars, in thousands, under Run 1's revenue floor (enrollment of at least 30 and revenue of at most 100,000 per pupil). | Section 7 |
| Estimators, inference, reporting | Unchanged from Run 1 Sections 7, 8, and 13 except as Sections 7 and 8 below add. | Run 1 |

## **4. Data sources**

| Source | Use | Terms |
|------------------------------------|----------------------------------|----------------------------------|
| SEDA 2025.2: `seda_admindist_long_cs_2025.2.csv`, the administrative-district codebook, and the documentation PDF, from the Stanford Digital Repository (DOI 10.25740/np279jm6134) | SEDA outcomes | Data use agreement accepted by the author at edopportunity.org before download. The agreement forbids publishing the files in full or in part: the files and the district-level derived files are not deposited on OSF; the manifest records their URLs and checksums; the README says a reader must obtain them under the same agreement. |
| State education agency high school report-card files or exports for school years ending 2022–2025, one file per state-year, listed in `docs/recon_run2_hs.csv` | High school outcomes 2022–2025 | Public files. Deposited on OSF with the manifest. |
| F-33, CCD, SAIPE through 2024, and CPI-U, already archived in Run 1 stage 2 | Covariates, weights, revenue, deflation | Already deposited. F-33 fiscal year 2025 is added if published on the download date. |

**States covered by the high school extension.** Coverage follows the reconnaissance verdicts in `docs/recon_run2_hs.csv`, fixed here.

- Included for all four years (37): AL, AZ, CA, CO, CT, DE, GA, ID, IL, IN, KS, KY, MA, MI, MN, MO, NC, ND, NE, NH, NJ, NM, NV, NY, OH, OR, PA, RI, SC, SD, TN, TX, UT, VT, WA, WI, WY. Seventeen of these (AL, CA, CO, CT, DE, GA, KS, MA, MI, MO, NC, NV, NY, OR, RI, TX, WA) were confirmed from the file description; the other twenty were judged probable without a file being opened.
- Included for the years available: DC (2022–2024), LA (2022, 2023, 2025).
- Conditionally included: AR 2022, IA 2022–2025, VA 2024–2025, and DC 2025. Each is downloaded after registration and enters if the file carries district-by-race rows; otherwise the state-year is recorded as unavailable with the reason.
- Not covered (no district-level subgroup file, or a single district): AK, FL, HI, MD, ME, MS, MT, OK, WV.

A probable state whose downloaded file turns out to lack district-by-race rows is treated the same way as a conditional one: excluded with the reason logged. No state is added beyond this list.

**Rule for matching the Run 1 measure.** For each state the report-card grade, test, and test group are chosen to match what the state reported to EDFacts as its high school result in Run 1 (the grade or course and the test named in `data/reference/test_replacement.csv`), and the proficiency definition is the one the state uses for federal accountability that year. Where a state's export pools regular and alternate assessments the pooled figure is used, since EDFacts pools them. Wyoming's grade is the grade EDFacts reported; South Dakota's test group is regular plus alternate. Where the accountability proficiency definition changes without a change of test, the change is recorded as a cut-score change, not a replacement.

## **5. Sample rules**

**SEDA.** Run 1 rules 1 (regular districts, CCD types 1 and 2), 2 (stable identifier, no boundary change), 6 (treatment timing), and 7 (SAIPE 2009 rate) apply, matched on the 7-digit NCES identifier that SEDA uses. Rules 3 and 4 do not apply: SEDA publishes an estimate only where at least 20 unique students contribute, drops estimates with participation below 94 percent from 2012–13 on, and removes estimates with standard errors above 1, so its own screens replace the 30-student floor, the midpoint rule, and the participation rule. A district-year-subject enters when the all-students mean and both subgroup means of the gap are present. Rule 5 (test replacement) does not apply: SEDA links every state test to a common scale.

**High school report cards.** Run 1 rules 1 through 7 apply as written. The 30-student floor applies to the tested count where the state reports it and to the state's own minimum group size where it does not. The midpoint rule applies to any range a state publishes; suppression symbols are read from the harmonization table. The participation rule applies where the state reports participation and is recorded as not applicable where it does not. The test-replacement flag is extended under Section 9.

## **6. Outcome construction**

**SEDA.** For each district-year-subject the grade 3–8 subgroup means are pooled into one mean with weights equal to the inverse squared standard errors, and the pooled standard error is the inverse square root of the summed weights. Gaps (b) and (c) are the Black minus White and Hispanic minus White pooled means; gap (a) is the state-year enrollment-weighted (2009–10 CCD membership, fixed) difference in all-students pooled means between the top and bottom 2009 SAIPE quintiles, formed as in Run 1 Section 6. Subjects are averaged within unit-year, both required. SEDA's own gap columns are not used because their sign is the reverse of the study's convention. A source indicator marks the 2022–2025 years, which SEDA builds from public suppressed state data rather than restricted-use counts.

**High school report cards.** Proficiency shares by subgroup and tested counts are read through one loader per state-year from the harmonization table, converted to V through the Run 1 function, and appended to the Run 1 panel with a column naming the source (EDFacts or report card).

## **7. Estimation**

The Callaway–Sant'Anna primary estimator, the four secondary estimators on the unbalanced panel, the covariates, the weighting, the event sets, and the overall post-reform average are as in Run 1 Section 7 and its decision log. Two things are added.

**Continuous treatment.** `DIDmultiplegtDYN` (version 2.4.0) with the treatment defined in Section 3, `continuous` set to a first-order polynomial in the baseline treatment, state clusters, the Run 1 covariates, effects estimated for event times 0 through +8 and placebos for −1 through −5, run on the extended high school gaps, the SEDA gaps, and the Run 1 graduation gaps. Standard errors are the package's analytical clustered errors; the package's own caveat that these can be liberal with a continuous treatment is reported beside every estimate, and its bootstrap is not used because it failed with the continuous option on the study machine. The `polars` dependency is pinned to the build recorded in the lockfile. These results are the extension's exploratory estimator and are reported after the event-based results.

**Extended high school panel.** The Run 1 models rerun on the 2010–2025 panel with a source indicator as an additional control in the regression-based estimators; the Callaway–Sant'Anna models take it as a baseline covariate through the district's first source year.

## **8. Inference**

As Run 1 Section 8: the wild cluster bootstrap on the influence function with 9,999 Webb-weight replications, Romano–Wolf on the shared draws, HonestDiD bound sets at M̄ in {0, 0.5, 1, 1.5, 2} with the widened grid and the consecutive-block rule, and randomization inference with 10,000 reassignments on the primary models of each outcome family and 1,000 on the variants. No power ceiling applies to Run 2; a placebo-based minimum detectable effect for the SEDA design is computed after the run and reported for information only.

## **9. Test-replacement flags for 2022 through 2025**

The Run 1 rules apply (Run 1 Section 5 rule 5). Applied to the changes the reconnaissance found, before any file is opened:

| State | Year (end) | Change | Coding |
|--------|--------|------------------------------------------|----------------|
| AZ | 2022 | ACT Aspire grade 9 and ACT grade 11 replaced AzM2 | 1, both subjects |
| IN | 2022 | SAT grade 11 replaced ISTEP+ grade 10 | 1, both subjects |
| KY | 2022 | KSA replaced K-PREP | 1, both subjects |
| ME | 2022 | NWEA MAP Growth adopted | not covered |
| AK, FL | 2022, 2023 | AK STAR; FAST and B.E.S.T. | not covered |
| VT | 2023 | VTCAP replaced Smarter Balanced | 1, both subjects |
| TX | 2023 | STAAR redesign with reset scales | 1, both subjects |
| CO, CT, DE, MI, RI, WV | 2024 | Digital SAT on the College Board's linked scale | 0: a delivery change on a maintained scale |
| GA | 2024 | Algebra: Concepts and Connections replaced the Algebra I end-of-course test | 1, math |
| TN | 2024 | Math end-of-course tests rebuilt to new standards with reset scores | 1, math |
| WI | 2024 | New cut scores and level names on the same ACT | 0 |
| DC | 2024 | PARCC renamed DC CAPE, same blueprints | 0 |
| NY | 2024 | Next Generation Algebra I Regents from June 2024 | 1, math, on the first year the reported result comes from it |
| VA | 2025 | New SOL mathematics and reading tests | 1, both subjects, consistent with VA 2019 and 2021 |
| KS | 2025 | Revised KAP assessments | 1, both subjects, if the revision is a rebuild; the reference-table session confirms from the KSDE description |
| ND | 2025 | ND A+ Summative, new vendor and item bank | 1, both subjects |
| AR | 2024 | ATLAS replaced ACT Aspire | conditional state; 1 if included |

Any change the reference-table session finds that is not in this table is coded under the Run 1 rules and logged.

## **10. Robustness checks specific to Run 2**

- SEDA span split: the SEDA models rerun on 2009–2019 alone and on 2022–2025 alone, because the two spans come from different source data.
- High school source split: the extended panel rerun on EDFacts years alone (which reproduces Run 1) and with the report-card years, so the contribution of the extension is visible.
- Coverage split: the extended panel rerun on the seventeen confirmed states only.
- The Run 1 robustness set (exact-only and 5-point samples, balanced panel, weighted, narrower event sets, anticipation, cohort drop) applies to the high school panel; for SEDA the suppression samples do not exist and the rest apply.

## **11. Threats added by the extension**

| Threat | Handling |
|--------------------------------|--------------------------------------------------|
| SEDA's 2022–2025 estimates come from different source data than 2009–2019 | Source indicator; span split in Section 10 |
| Report-card files differ in proficiency definitions, suppression, and grade across states | Harmonization table with one row per state-year, deposited; the EDFacts-matching rule in Section 4; coverage split |
| Report-card years lack participation data in most states | Recorded as not applicable; no participation screen for those cells |
| SEDA 2009–2019 estimates carry added noise | Their published standard errors include it; the estimators weight by units, not precision |
| Run 2 is not blinded | Registration of this document before any Run 2 outcome file is opened; freeze tag before the run; deviations log after it |
| The continuous estimator's analytical errors may be liberal | Reported with the caveat; results labeled exploratory |

## **12. Reporting**

Run 1 Section 13 applies to each Run 2 outcome family: the honest-DiD bound sets first, then the event-study plots with cohort counts, the bootstrap and randomization p-values, the estimator agreement table, the weighted comparison, the narrower event sets, the Run 2 splits in Section 10, and the continuous-treatment estimates with their caveat. The dissertation reports Run 1 as the registered study and Run 2 as the registered extension, in that order, and does not describe any Run 2 result as statistically significant.

## **13. Registration and records**

This document is registered on OSF through the preregistration form's own fields before any Run 2 outcome file is downloaded; the form text is self-contained. The OSF deposits for Run 2 hold the report-card data, the manifest, the checksums, and the outputs. This document, the Run 2 decision log (`docs/decision_log_run2.md`, closed at registration), and the Run 2 deviations log (`docs/deviations_run2.md`, opened at registration) stay in the public repository and are not uploaded to OSF. The code is frozen at the tag `freeze-run2` before the run.

## **14. Limitations**

- SEDA measures grades 3–8, not the high school outcome the study is about; its results speak to the reforms' effect on the grades that feed high school.
- The high school extension covers 39 states and four years, on state tests that differ across states; within-state gaps are comparable across years within a state, not across states.
- The extension was designed after Run 1's results were known. Its registration fixes the plan but cannot restore a blind.
- The continuous-treatment estimator carries a different identifying assumption from the event-based design and an inference caveat of its own.
