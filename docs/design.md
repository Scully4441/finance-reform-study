# Study Design: The Effect of School Finance Reforms on Achievement Disparities in U.S. Secondary Schools

Dylan Scully, Ed.D. dissertation, Murray State University (chair: Dr. Teresa Clark).
Pre-analysis plan for the registered study. Committee-approved proposal, November 2026.

This document fixes every definition, sample rule, estimator, inference procedure and
reporting rule of the study before the relevant data are opened. It is registered on
OSF with the preregistration and kept unchanged in the public repository. Decisions
made before the registration is filed that add to or change a rule here are recorded
in `docs/decision_log.md`. Departures after filing are recorded in
`docs/deviations.md`.

## Conventions and abbreviations

School years are indexed by their end year: 2009-10 is 2010. Every year in this
document is an end year unless it is written as a school year (2009-10) or a calendar
date. Fixed pre-treatment values are taken from end year 2010. States are two-letter
postal codes.

- CCD: the Common Core of Data, the federal directory and enrollment survey of public
  schools and local education agencies, published by NCES.
- CEP: the Community Eligibility Provision of the National School Lunch Program.
- EDFacts: the federal system through which states report school and district
  assessment and graduation results; its public files are published by the U.S.
  Department of Education (ED).
- F-33: the Census Bureau's Annual Survey of School System Finances.
- LEA: local education agency (school district). LEAID: the seven-digit NCES district
  identifier, held as text.
- LRS: Lafortune, Rothstein and Schanzenbach (2018), whose online appendix lists
  school finance reform events from 1990 through 2011 (the published list).
- NCES: the National Center for Education Statistics.
- SAIPE: the Census Bureau's Small Area Income and Poverty Estimates. SAIPE estimates
  are labelled by income year; income year 2009 is paired with end year 2010.
- SEA: state education agency.
- SEDA: the Stanford Education Data Archive, district-level achievement estimates for
  grades 3 through 8 on a common scale.
- ESEA, ESSA: the Elementary and Secondary Education Act and the Every Student Succeeds
  Act.

## 1. Research question, hypotheses and estimand

### 1.1 Question

To what degree do school finance reform efforts affect achievement disparities in
secondary U.S. schools?

The question asks about degree. The study therefore produces an effect size in
interpretable units and a path over time rather than a yes-or-no verdict. The answer
is stated for each disparity measure as an interval in standard deviation units and
as an interval per $1,000 of per-pupil revenue.

### 1.2 Hypotheses

Five hypotheses are registered:

- H1. A reform narrows the between-district achievement gap by child-poverty quintile (gap a).
- H2. A reform narrows the within-district Black–White gap (gap b).
- H3. A reform narrows the within-district Hispanic–White gap (gap c).
- H4. The effect grows with years since reform.
- H5. The effect per $1,000 of reform-induced per-pupil revenue is positive.

H1 through H4 are evaluated by the sensitivity bound sets and the confidence
intervals of the estimates. H5 is evaluated by the confidence interval of the
dose-scaled estimate. None is evaluated by a significance test, and no result is
reported as a significance claim. The rules are fixed in Section 12. A point estimate
is described as robust only when the agreement criterion of Section 12.2 holds.

### 1.3 Estimand

The estimand is the average effect of a state school finance reform on within-state
achievement gaps, estimated for each year since reform from event time 0 through +8.
The effect is expressed in standard deviation units of the test as defined in Section
6.1. A dose-scaled version expresses the same effect per $1,000 of reform-induced
change in per-pupil state-plus-local revenue (Section 9).

Reform effects may build over several years as funding passes through budgets and
staffing. The estimand therefore covers the effect in each year after reform as well
as one overall post-reform average, the equal-weight mean of the estimated
event-time effects from 0 through +8. The number of cohorts and treated states behind
each event time is reported beside the average, because the later event times rest
on fewer states.

### 1.4 Outcome families

The study has three outcome families. Each is estimated, tested and reported
separately under the same rules.

| Family | Role | Gaps | Grades | End years | Treated-unit floor |
|---|---|---|---|---|---|
| High school achievement | Primary | (a), (b), (c) | High school assessment | 2010-2019, 2021-2025 | Gaps (b), (c) |
| Graduation | Secondary | Black–White, Hispanic–White | Four-year cohort | 2011-2021 | None |
| SEDA grades 3-8 | Supplementary | (a), (b), (c) | 3 through 8 | 2009-2019, 2022-2025 | Gaps (b), (c) |

The high school family is one panel. End years 2010 through 2021 come from the federal
EDFacts files and end years 2022 through 2025 from state report-card files, with a
column naming the source. End year 2020 is absent because most states waived
assessment in 2019-20. The federal years alone form a registered robustness split
(Section 11), not a separate family. The treated-unit floor (Section 5.4) applies to
every Callaway–Sant'Anna model of gaps (b) and (c) in the high school and SEDA
families, their variants and splits included.

### 1.5 Scope

The study estimates the size and time path of the average effect. It does not compare
reform types. It does not estimate mechanisms. It does not estimate effects on levels
of achievement except where a level is an input to a gap.

## 2. Logic of the design

The achievement gap a reforming state would have had without its reform is not
observed. The design uses states that did not reform, or had not yet reformed, as the
comparison.

Difference-in-differences compares the change in a gap in reforming states with the
change in the same gap over the same years in states without a reform. Subtracting
the second change from the first removes anything that affected all states alike,
such as national test trends, recessions and federal policy. The remaining difference
is attributed to the reform under the parallel-trends assumption: absent the reform,
gaps in reforming and non-reforming states would have moved in parallel. The
assumption cannot be proven. Parallel movement before reform makes it more plausible,
and the sensitivity bound sets of Section 8.5 show how far the conclusion moves when
post-reform trends are allowed to depart from parallel.

States reform in different years. A conventional two-way fixed effects regression
uses already-reformed states as controls for later-reforming states, and when effects
grow over time it can produce estimates with the wrong sign. The study uses
estimators built for staggered timing and reports two-way fixed effects only as a
comparison row.

An event study places each reforming state on a common clock with the reform year as
year 0 and estimates the effect separately for each year before and after reform.
Coefficients before year 0 should be near zero if parallel trends hold. Coefficients
after year 0 trace the effect over time.

The public LEA-level federal achievement files end at 2021. Reforms coded after 2020
have no post-reform year in those files. The study therefore adds high school results
for 2022 through 2025 from state report-card files and grades 3-8 results from SEDA
through 2025, so that every reform cohort has a measured post-reform period in at
least one family, and adds a continuous-treatment estimator built on district revenue
(Section 7.6). All of these parts are fixed here and registered before any file they
use is downloaded.

## 3. Fixed definitions

Every definition below is fixed in writing before the outcome data are opened. Each
decision is turned into a rule that code applies identically to every case.

| Term | Operational definition |
|---|---|
| Secondary school | Grades 9-12 as tested by the high school assessment that the state reports for federal accountability. |
| School finance reform | For 1990 through 2011, an event on the LRS list. After December 31, 2011, two written rules apply. Court rule: a ruling that held the state's K-12 finance system or its formula for state operating aid unconstitutional and that became final because it was not appealed or was affirmed on appeal. A ruling later vacated, reversed or disavowed by the issuing court does not count. Statute rule: a statute that enacted a new primary formula for distributing state operating aid to districts and repealed or superseded the formula in force. A formula counts as new when its architecture changes, not when components or weights within the existing architecture are revised. Parameter amendments and supplemental programs do not count. A statute that applies a new formula only to funding above a locked-in base does not supersede the formula in force. |
| Coding conventions | A holding that a provision of the state operating-aid formula is unconstitutional counts under the court rule. A lower-court ruling affirmed on appeal is coded at the date of the lower-court ruling; a lower-court ruling not appealed is final at its own date. A statute that phases districts toward a new formula computing each district's whole allocation counts under the statute rule; a statute that keeps a permanent locked-in base does not. A ruling that enforces a parameter of the existing formula, or voids a formula resolution for defects in its adoption without holding the distribution of operating aid unconstitutional, does not count. |
| Candidate sources | Rulings: the Education Law Center SchoolFunding.info case database. Statutes: the finance records of the Education Commission of the States and the National Conference of State Legislatures, with the statute text and official legislative summaries. Each post-2011 candidate is coded from the ruling or statute text before any outcome file is downloaded. |
| Event types | Each event is a court event or a legislative event. |
| Reform year | The school year to which a ruling or enactment is assigned, as an end year. An event dated July through December of calendar year Y falls in the school year ending Y+1 and is coded Y+1. A spring event, dated January through June of calendar year Y, falls in the school year ending Y and is assigned to the following school year, so it is also coded Y+1. Every event in calendar year Y is therefore coded Y+1. The year on the LRS list is the calendar year of the ruling or enactment and is coded the same way. |
| Treatment year of a state | The earliest reform year of the state in the event set within the analysis window (end year 2010 or later). Later events of the same state do not change it. |
| Event sets | Full set (primary): every event under the rules above. Narrow set r1: the LRS list plus final state supreme court rulings after 2011. Narrow set r2: court events only, from the LRS list and after 2011. Each set gives its own event table. |
| Treatment groups | Treated: a reform year in end years 2010 through 2025. Excluded: any reform year in end years 2005 through 2009, the five years before the first high school window year. Never treated: neither. The test is applied to the events of each event set, so a state can be excluded in one set and treated or never treated in another. One set of groups per event table is used by every outcome family. A state whose treatment year falls after the last year of a window is never treated within that window. |
| Event time | The number of school years from the treatment year to the outcome year. The year before reform (event time -1) is the reference period. Event times -5 through +8 are estimated. |
| Achievement disparity | Three gaps (Section 6): (a) between-district gap by 2009 SAIPE child-poverty quintile, (b) within-district Black–White gap, (c) within-district Hispanic–White gap. All are oriented so that a positive effect means the gap narrowed. |
| Analysis windows | High school: 2010-2019 and 2021-2025. Graduation: 2011-2021, 2020 included. SEDA: 2009-2019 and 2022-2025. |
| Dollars | All revenue is in 2025 dollars, the last window year. |

### 3.1 Why the reform list is borrowed through 2011 and rule-bound after

Deciding what counts as a reform is the largest point of discretion in this
literature. Legislatures adjust funding formulas nearly every year. A list published
by peer-reviewed research moves that judgment outside the study and into the
documented record. After 2011 no such list exists, so events are coded under two
written rules. The court rule turns on a checkable fact, whether the ruling became
final. The statute rule turns on whether a new primary formula was enacted. Parameter
changes are left out because deciding which of them are large enough would require
the judgment of magnitude the design avoids.

Post-2011 parameter reforms are therefore coded as untreated. That misclassification
can only push the estimate toward zero, because a reformed state coded as untreated
carries any real reform effect into the comparison group. The design accepts a
possibly understated effect in exchange for a treatment variable fixed before the
data are seen. The two narrow event sets bound the effect of the post-2011 coding.

### 3.2 Event coding and treated states

Every post-2011 candidate was coded from the ruling or statute text before any
outcome file was downloaded. The coding table (`post2011_candidates_considered`, 175
candidates) lists each candidate with its state, rule, date, coded end year, source,
decision and reason. It is deposited with the registration, together with the event
files for the LRS list, the post-2011 court events and the post-2011 statute events.
The reform years are therefore public. Section 15.3 explains what the blinding
protects.

Nine states are treated in the primary event set within the study windows.

| State | Coded year | Instrument | Reform |
|---|---|---|---|
| Washington | 2011 | Court ruling (LRS list) | McCleary v. State, King County Superior Court ruling of February 2010; affirmed by the Washington Supreme Court on January 5, 2012 |
| Indiana | 2012 | Statute (LRS list) | House Bill 1001 (P.L. 229), enacted 2011 |
| South Dakota | 2017 | Statute | Senate Bill 131 (2016), state aid formula built from target teacher ratios and target compensation, signed March 2016 |
| New Mexico | 2019 | Court ruling | Martinez v. State and Yazzie v. State, First Judicial District Court, Decision and Order of July 20, 2018; not appealed |
| Nevada | 2020 | Statute | Senate Bill 543 (2019), Pupil-Centered Funding Plan, approved June 14, 2019 |
| Ohio | 2022 | Statute | House Bill 110 (134th General Assembly), Fair School Funding Plan, enacted June 30, 2021 |
| Tennessee | 2023 | Statute | Tennessee Investment in Student Achievement Act, Public Chapter 966 of 2022, signed May 2, 2022 |
| Pennsylvania | 2024 | Court ruling | William Penn School District v. Pennsylvania Department of Education, Commonwealth Court, decided February 7, 2023; not appealed |
| Mississippi | 2025 | Statute | House Bill 4130 (2024), Mississippi Student Funding Formula, approved May 8, 2024 |

Three statutes were coded and fail the statute rule: the Illinois Evidence-Based
Funding for Student Success Act (2017), because each district keeps a Base Funding
Minimum and the new formula applies only to new state funds above that locked base;
Maryland's Blueprint for Maryland's Future (House Bill 1300, 2020, and its 2021
revisions), because it amends the per-pupil amounts, weights and wealth measures of
the existing foundation and categorical formulas within the same architecture; and
Colorado House Bill 24-1448, because it keeps the total-program foundation
architecture and the formula in force continues to set each district's total program
through 2029-30.

The narrow event sets and the excluded states are:

| Event set | Treated (coded year) | Excluded |
|---|---|---|
| Full (primary) | WA 2011, IN 2012, SD 2017, NM 2019, NV 2020, OH 2022, TN 2023, PA 2024, MS 2025 | AR, CA, ID, KS, MO, MT, NC, ND, NH, NJ, NY |
| r1: LRS list plus final state supreme court rulings after 2011 | WA 2011, IN 2012 | AR, CA, ID, KS, MO, MT, NC, ND, NH, NJ, NY |
| r2: court events only | WA 2011, NH 2017, NM 2019, PA 2024 | AR, ID, KS, MT, NC, NY |

New Hampshire's status differs across the sets. In the full set and in r1, which
both contain every event on the LRS list, New Hampshire is excluded by Senate Bill
539, a statute on the LRS list for calendar year 2008 and coded 2009. In r2 only court
events count. New Hampshire's court events on the LRS list are coded 1994, 1998, 2000
and 2003, outside 2005-2009, so it is not excluded. Its earliest in-window court
event is the Superior Court ruling in City of Dover v. State of September 2, 2016,
which held a provision of the adequacy aid formula unconstitutional and was not
appealed; it is coded 2017 and is New Hampshire's treatment year in r2. Its later
court event, the Contoocook Valley School District v. State order of November 2023
(coded 2024), does not change the treatment year.

Five treated states of the primary set (Washington, Indiana, South Dakota, New Mexico
and Nevada) have a post-reform year in the federal high school files. Every cohort
has a post-reform period in the SEDA family. Every cohort has a post-reform period in
the high school family where the state has report-card files for 2022 through 2025.

### 3.3 Why two forms of disparity

Achievement disparity has two common meanings in this literature: the gap between
poor and affluent districts, and the gap between student groups inside the same
district. Finance reforms mainly move money between districts, so the first form is
the most direct target. The second form shows whether the money reaches the students
within districts who are behind. Income-targeted formulas may leave racial gaps
unchanged. All three gaps are registered so that the study cannot choose among them
after seeing results.

## 4. Data sources

All sources are free and public except SEDA, which is free under a data use
agreement.

| Data | Use | Location |
|---|---|---|
| EDFacts state assessment files, LEA level, by subgroup, high school grade band, mathematics and reading/language arts, 2010-2021 | High school outcomes, federal years | ED's EDFacts data files and ED Data Library (eddataexpress.ed.gov) |
| EDFacts assessment participation files, LEA level, 2013-2021 | Rule 4 | as above |
| EDFacts adjusted cohort graduation rate files, LEA level, by subgroup, 2011-2021 | Graduation family | as above |
| CCD LEA universe and directory files; school universe and membership files; school characteristics files | Rules 1 and 2, covariates, weights, CEP status, Lee bounds | nces.ed.gov/ccd |
| CCD school universe files for 2007, 2008 and 2009 | Grade 9 membership for the Lee bounds | nces.ed.gov/ccd |
| SAIPE school district estimates, income year 2009 | Poverty quintiles and poverty covariate | census.gov/programs-surveys/saipe |
| F-33, fiscal years 2010-2024 | Revenue, dose scaling, continuous treatment | census.gov/programs-surveys/school-finances |
| CPI-U, U.S. city average, all items, not seasonally adjusted, series CUUR0000SA0 | Deflation | Bureau of Labor Statistics, bls.gov |
| LRS online appendix | Reform list through 2011 | American Economic Journal: Applied Economics, aeaweb.org |
| Education Law Center SchoolFunding.info; state statutes and legislative summaries; ECS and NCSL finance records | Post-2011 events | schoolfunding.info; legislature sites; ecs.org; ncsl.org |
| USDA CEP participation lists; state phase-in table | CEP indicator before 2014 | fns.usda.gov |
| SEA assessment histories, ESEA accountability workbooks, ESSA plans, ESEA flexibility requests | Test-replacement table | SEA sites; ed.gov |
| SEDA release 2025.2: administrative-district long file on the cohort-standardized scale, its codebook and its documentation | SEDA family | Stanford Digital Repository, DOI 10.25740/np279jm6134 |
| SEA report-card files, 2022-2025 | High school outcomes, report-card years | SEA sites and reporting tools |

### 4.1 Federal files and fixed substitutions

According to ED's release listings, the newest school year with LEA-level EDFacts
achievement files for both mathematics and reading/language arts is 2020-21; the
2021-22 release carries an LEA reading/language arts file only, and no assessment
file is listed for 2022-23 or later. A unit-year needs both subjects (Section 6.2),
so the federal years end at 2021. LEA-level graduation files are listed through
2020-21; later releases are state-level only and cannot form a within-district gap,
so the graduation window ends at 2021. The listings are checked again before
registration, with no outcome file for a year after 2013 downloaded or opened, and
the date of the check is entered in the registration.

The following rules fix the files read:

- For end year 2019 the legacy ED file names are not served. The manifest lists both
  ED's ED Data Library release of that year and the Education Data Center EDFacts
  archive copy (eddatacenter.org/edfacts) of ED's legacy long-layout files. The copy
  read is the one that covers all 50 states and DC; where both do, ED's release is
  read. The other copy is archived as a record.
- The loaders read both layouts that ED documents for these files, the legacy wide
  files and the ED Data Library long files. The range and suppression rules of Section
  5 apply unchanged to both.
- F-33 is read from the comma-delimited text release of each fiscal year. If the text
  release of a fiscal year holds fewer unit records than the spreadsheet release of the
  same year, the spreadsheet release is read for that year and the substitution is
  logged. F-33 fiscal year 2025 is not added, whether or not it is published by the
  stage 2 download date. Fiscal year equals end year.
- CCD files: the combined LEA and school universe files through 2014, the newest
  release of each year; from 2015 the LEA Directory, school Membership and school
  Characteristics files, the newest release of each year. CCD directories are archived
  for 2010 through 2024. No directory is archived for 2009 or 2025.
- The CCD school universe files for 2007, 2008 and 2009 supply grade 9 membership
  three years before the early window years. A fixed-width release is read at the
  byte positions of its published record layout.
- The CPI series is obtained by script, or through a browser where the BLS site
  refuses scripted requests (method 3 of Section 15.6), and checksummed either way.

### 4.2 SEDA release

The study uses SEDA release 2025.2, deposited in the Stanford Digital Repository
under DOI 10.25740/np279jm6134 (PURL purl.stanford.edu/np279jm6134). The district
unit is the administrative district, identified by its NCES LEAID. The release's
description on edopportunity.org gives district estimates for 2009 through 2025 (end
years 2009-2019 and 2022-2025, with none for 2020 or 2021); the abstract on the
repository page mentions estimates from 2019 to 2025. The years present are confirmed
from the codebook at download. If the long file does not hold end years 2009 through
2019, the SEDA family uses release 2025.1 (DOI 10.25740/hm970gr1371), whose deposit
describes estimates from 2009 to 2025, under the same rules, and the substitution is
logged.

The three files used, as named in the deposit's public file list, are fetched from
`https://stacks.stanford.edu/file/np279jm6134/<file>`:

| File | Bytes |
|---|---|
| `seda_admindist_long_cs_2025.2.csv` | 1,026,013,873 |
| `seda_codebook_admindist_2025.2.xlsx` | 94,655 |
| `SEDA_documentation_2025.2.pdf` | 1,080,259 |

The PURL resolves to the newest version of the deposit. The manifest records the
deposit version, each file's address and its SHA-256 checksum at download, which fix
the files used.

The author accepts the SEDA data use agreement at edopportunity.org before any SEDA
file is downloaded. The agreement prohibits commercial use, re-identification and
publication of the files in full or in part. The SEDA files and every district-level
file derived from them are never deposited (Section 15.7).

### 4.3 Report-card files

High school results for 2022 through 2025 come from SEA report-card files for the
states that publish district-level proficiency by race for the high school
assessment. Coverage is fixed in the table below from a review of the published
files of every state, completed before registration and before any data file was
opened.

A state is listed as covered for a year when its published documentation shows a
district-level file with Black, Hispanic and White rows for the high school
assessment for that year. A state is listed as conditional when a file or export
exists but those rows cannot be confirmed without opening it; inclusion then depends
on the downloaded file carrying them. A state that publishes no district-level
subgroup file for the high school assessment is not covered. No state-year is added
beyond the table, except that a state whose public file lacks district-by-race rows
may supply such a file on request (method 4 of Section 15.6); a file obtained that
way enters under the same rules and is logged.

Coverage exclusions found after download are logged in the deviations log with the
reason. A state-year is excluded when the file carries no race subgroup; when the
file crosses race only with a second group (for example sex, English learner status
or disability) with no race-alone rows; when results are reported only for an agency
type that rule 1 excludes (supervisory union results are not mapped onto member
districts, which would repeat one value across several units); when no file for the
year crosses race with the tested grade or course; or when race appears only at the
state level. A covered or conditional state whose downloaded file fails any of these
tests is excluded with the reason logged.

#### Report-card coverage table

The review was completed on 2026-11-18 from the state agencies' published pages
(landing and index pages, record layouts, data dictionaries, business rules,
technical guides and assessment histories), with Web Archive copies where a page no
longer resolved. No data file was downloaded or opened, and data addresses were
checked without downloading. Documentation spreadsheets were opened only where the
index labelled them as a layout or dictionary, and only sheet names and field
descriptions were read. A description that names only "student groups" without
naming race gave a conditional listing.

The full state-year table (204 rows: 51 jurisdictions by 2022-2025, with the landing
page, file or tool, format, access, high school test, tested counts, minimum group
size, participation, proficient levels, suppression symbols and notes) is deposited
with the registration. Every state has the same status in all four years:

| Status | Count | States |
|---|---|---|
| Covered | 18 | AL, AR, CA, CT, DE, IL, KS, MA, MO, NV, NJ, NY, NC, OR, RI, TX, WA, WY |
| Conditional | 31 | AK, AZ, CO, DC, FL, GA, ID, IN, IA, KY, LA, ME, MD, MI, MN, MS, MT, NE, NH, NM, ND, OH, PA, SC, SD, TN, UT, VT, VA, WV, WI |
| Not covered | 2 | HI (one statewide district), OK (no district file of grade 11 results by race) |

Access codes: Script, a fixed address fetched by the download script; Script (UA), a
fixed address that answers only to a browser user agent; Script (unconfirmed), a
fixed address whose answer to a scripted request is confirmed at download; Tool, an
interactive reporting tool export (method 2 of Section 15.6); Browser, a site that
refuses scripted requests (method 3); District files, one file per district at fixed
addresses.

| State | Status | Access | High school test, 2022-2025 |
|---|---|---|---|
| AL | Covered | Script | ACT with Writing, grade 11 |
| AK | Conditional | District files | AK STAR grade 9 |
| AZ | Conditional | Browser | ACT Aspire grade 9 and ACT grade 11 |
| AR | Covered | Tool | ACT Aspire grades 9-10 (2022-2023); ATLAS ELA grades 9-10, EOC Algebra I and Geometry (2024-2025) |
| CA | Covered | Script (unconfirmed) | Smarter Balanced grade 11 |
| CO | Conditional | Script | PSAT 8/9 grade 9, PSAT 10 grade 10, SAT grade 11 |
| CT | Covered | Tool | SAT School Day grade 11 |
| DE | Covered | Script | SAT School Day grade 11 |
| DC | Conditional | Browser | PARCC high school courses (2022-2023); DC CAPE, same design (2024-2025) |
| FL | Conditional | Tool | FSA ELA grade 10 and EOCs (2022); FAST ELA Reading grade 10 and B.E.S.T. EOCs (2023-2025) |
| GA | Conditional | Script | Milestones EOC American Literature; Algebra I/Coordinate Algebra (2022-2023), Algebra: Concepts and Connections (2024-2025) |
| HI | Not covered | Script | Smarter Balanced grade 11 |
| ID | Conditional | Tool | ISAT grade 10 (2022); ISAT grade 11 (2023-2025) |
| IL | Covered | Script | SAT grade 11 (2022-2024); ACT with Writing grade 11 (2025) |
| IN | Conditional | Script | Indiana SAT School Day grade 11 |
| IA | Conditional | Script | ISASP grades 9-11 |
| KS | Covered | Script | KAP grade 10 |
| KY | Conditional | Script (UA) | Kentucky Summative Assessment grade 10 |
| LA | Conditional | Script | LEAP 2025 EOCs: Algebra I, Geometry, English I, English II |
| ME | Conditional | Tool | NWEA MAP Growth grade 11 (2022); Maine Through Year Assessment grade 10 (2023-2025) |
| MD | Conditional | Browser | MCAP Algebra I and English 10 |
| MA | Covered | Script | Next-generation MCAS grade 10 |
| MI | Conditional | Tool | SAT grade 11 |
| MN | Conditional | Browser | MCA-III reading grade 10, mathematics grade 11 |
| MS | Conditional | Script (UA) | MAAP Algebra I and English II |
| MO | Covered | Script | MAP EOC Algebra I and English II |
| MT | Conditional | Tool | ACT with Writing grade 11 |
| NE | Conditional | Script (unconfirmed) | ACT with Writing grade 11 |
| NV | Covered | Tool | ACT with Writing grade 11 |
| NH | Conditional | Browser | SAT grade 11 |
| NJ | Covered | Script | NJSLA ELA grade 9 and NJSLA Algebra I EOC |
| NM | Conditional | Script | SAT School Day grade 11 |
| NY | Covered | Script | Regents Algebra I and ELA (Total Cohort results) |
| NC | Covered | Script | EOC English II and NC Math 1 |
| ND | Conditional | Script | NDSA grade 10 or ACT grade 11 (2022-2024); ND A+ grade 10 (2025) |
| OH | Conditional | Browser | Ohio's State Tests EOC: Algebra I or Integrated Math I, Geometry or Integrated Math II, ELA II |
| OK | Not covered | Script | CCRA grade 11: ACT or SAT (2022-2023), ACT (2024-2025) |
| OR | Covered | Script | Smarter Balanced grade 11 |
| PA | Conditional | Script | Keystone Algebra I and Literature |
| RI | Covered | Tool | SAT School Day grade 11 |
| SC | Conditional | Script | EOCEP Algebra 1 and English 2 |
| SD | Conditional | Script | SD ELA and mathematics assessments (Smarter Balanced based) grade 11 |
| TN | Conditional | Script | TCAP EOC mathematics courses, English I and II |
| TX | Covered | Tool | STAAR EOC Algebra I, English I, English II |
| UT | Conditional | Script | Utah Aspire Plus grades 9-10 |
| VT | Conditional | Script (UA) | Smarter Balanced grade 9 (2022); VTCAP grade 9 (2023-2025) |
| VA | Conditional | Browser | SOL EOC Reading; EOC Algebra I, Geometry, Algebra II |
| WA | Covered | Script | Smarter Balanced grade 10 |
| WV | Conditional | Script (Tool in 2024) | SAT School Day grade 11 |
| WI | Conditional | Script | ACT grade 11 |
| WY | Covered | Tool | WY-TOPP grades 9-10 |

No state in the table requires a data request for the files reviewed. The test named
is the one the review found behind each state's reported high school result. The
harmonization table applies the matching rule of Section 4.4 to choose the grade,
course and test group actually read.

### 4.4 Matching rule for report-card results

For each state the report-card grade, course, test and test group are chosen to
match what the state reported to EDFacts as its high school result in 2021, as named
in the test-replacement table (Section 6.6). The proficiency definition is the one
the state uses for federal accountability in that year. Where the state's export
pools regular and alternate assessments, the pooled figure is used, as EDFacts pools
them. Where the accountability proficiency definition changes without a change of
test, the change is a cut-score change and is not flagged (rule 5).

The choices are recorded in the harmonization table, a reference table with one row
per report-card state-year that records where each needed value sits in the state's
file and how it is read (Section 6.3).

Where the state's current export cannot meet the matching rule and an earlier
published state file can, the earlier file is used, from an archived copy (Wayback
Machine) where it is no longer live. The archived address and capture date are
recorded in the manifest row.

## 5. Sample construction rules

All inclusion decisions are rules applied by code. The rules are fixed in this
document before any outcome file is opened and are registered before any file for a
year after 2013 is downloaded.

1. Unit. Regular public school districts: CCD agency type 1 or 2 (`TYPE` through
   2014, `LEA_TYPE` from 2015). Charter-only agencies, state-operated agencies,
   supervisory unions, regional service agencies, federal agencies and `LEA_TYPE` 9
   (specialized district, from 2020) are excluded, because their finance and
   enrollment are not comparable with those of regular districts. Agency type must
   be 1 or 2 in every tested year.

2. Stability. A district is retained only if its CCD identifier is present and
   operational in every tested year and it has no boundary or consolidation flag in
   any tested year. The boundary code is `BOUND` through 2014 and `UPDATED_STATUS`
   from 2015, read under the same codes as NCES documents them: 1 no change, 2
   closed, 3 new, 4 added, 5 significant change in boundaries or instructional
   responsibility, 6 temporarily closed, 7 future, 8 reopened. A district is present
   in a year when it is listed with a code other than 2, 6 or 7. A code 5 or 8 in any
   tested year excludes it.

3. Cell size and suppression. A cell is one district, year, subject and subgroup. A
   cell is used if the tested count is exact and at least 30 and the proficiency
   share is reported as an exact value or as a range no wider than 10 percentage
   points. A range enters at its midpoint. Width and midpoint come from the printed
   endpoints, with one-sided labels closed at 0 and 100: `20-29` has width 9 and
   midpoint 24.5; `90-94` width 4 and midpoint 92; `GE90` width 10 and midpoint 95;
   `GE95` width 5 and midpoint 97.5; `LE5` width 5 and midpoint 2.5; an exact value
   width 0. Wider ranges and suppressed values are missing and are not imputed. This
   rule defines the primary suppression sample. Two robustness samples are
   registered: exact values only, and ranges of 5 points or less. The three samples
   are nested.

4. Participation. A district-year-subject is used only if reported participation is
   at least 95 percent for each subgroup in the gap. The test applies to the exact
   value where one is reported and to the band midpoint where participation is
   banded, with the printed-endpoint convention of rule 3: `GE90` (midpoint 95),
   `GE95` (97.5) and `GE99` (99.5) pass; `90-94` (92), `80-89` and lower bands fail;
   a cell with no participation value fails. A band whose lower end is below 95 and
   whose upper end is at or above 95 straddles the threshold; in the exact-only
   sample such a band fails for that district-year-subject and each case is logged.
   Participation files begin with 2013, so the rule applies in full from 2013 and
   2010-2012 are retained without it. A robustness sample starts at 2013.

5. Test replacement. A state-year-subject is flagged when the state replaced its high
   school assessment in that subject in that year: a different test, the same-named
   test rebuilt for new standards on a new scale, or a change in the instrument
   behind the reported result. A change of the tested grade is a change in the
   instrument behind the reported result and is flagged, as is a pooled result
   replaced by one of its components (for example an augmented SAT replaced by the
   SAT alone). A new cut score on an unchanged test is not flagged. The flag goes on
   the first school year in which the reported high school result for the subject
   comes from the new instrument. A year that mixes old and new results is flagged.
   The state-year flag used as a control is 1 if either subject is flagged, since a
   unit-year outcome averages the two subjects. The table and its sources are
   described in Section 6.6.

6. Treatment timing. States are grouped as treated, never treated or excluded under
   Section 3. Excluded states leave every panel because their pre-reform period
   cannot be observed and an earlier reform may still be operating. Cohorts that
   reform early in the window are retained with few pre-reform years, and the number
   of cohorts behind each event-time coefficient is reported. A robustness version
   drops cohorts with fewer than three pre-reform window years. The sample step reads
   each state's group only; treatment years do not enter the sample file.

7. Poverty measure. A district that passes rules 1 and 2 but has no SAIPE 2009
   child-poverty rate (absent from the SAIPE file, or no children aged 5-17) is
   dropped for all three gaps, before rule 6. The 2009 rate defines the fixed
   poverty quintiles and is a pre-treatment covariate in the covariate-adjusted
   models. The dropped LEAIDs are listed in an output file.

The 30-student floor is stricter than the federal suppression threshold. A
proficiency rate based on 10 students carries sampling error of about 0.3 SD, larger
than any effect the study could detect. The floor tilts the retained sample toward
larger districts.

ED's documentation of its public assessment files describes how percent proficient is
banded by tested count: groups of 1-5 are suppressed, 6-15 receive a 50-point split,
16-30 receive 20-point bands, 31-60 receive 10-point bands, 61-300 receive 5-point
bands, and larger groups receive whole numbers. Under rule 3 a federal cell of 16 to
30 tested students is published as a 20-point band, which the 10-point rule never
admits. In the federal files the effective minimum is therefore 31 tested students,
and the floor of 30 never binds on its own. This is a known property of the rule.
For the same reason the participation rule's effective threshold depends on group
size: participation is banded more coarsely for smaller groups, so a group of 31-60
tested students passes on `GE90`, while larger groups face the literal 95.

### 5.1 Tested years for rules 1 and 2, by family

Rules 1 and 2 are tested in every window year of a family for which a CCD directory
is archived.

- High school family: tested in 2010-2019 and 2021-2024. The 2020 directory does not
  enter, since 2020 is outside the window. End year 2025 has no archived directory: a
  district's 2025 row is kept when the district passes rules 1 and 2 in every tested
  year and is dropped otherwise.
- Graduation family: tested in 2011-2021, the window years, 2020 included.
- SEDA family: tested in 2010-2019 and 2022-2024 on the LEAID that SEDA uses. End
  years 2009 and 2025 have no archived directory: their rows are kept when the
  district passes rules 1 and 2 in every tested year and are dropped when it fails
  either rule in any tested year.

### 5.2 Rules by family

High school family, federal years (2010-2021). Rules 1 through 7 apply as written.

High school family, report-card years (2022-2025). Rules 1 through 7 apply, with these
readings for files that do not print what the federal files print:

- Where a state prints no tested count, the 30-student requirement defaults to the
  minimum group size the state uses for public reporting, and a published rate is
  taken to meet that size. The minimum group size and its source are recorded for
  each state-year in the harmonization table.
- Where a state prints tested counts only as bands (for example `30 - 35`), the
  requirement is tested on the lower bound of the band.
- A suppression symbol that the state defines as a count under 10 is read as a count
  band from 0 to 9 and fails the requirement, even where a rate is printed.
- The rule is applied cell by cell: a cell whose count is suppressed while its rate is
  printed uses the minimum group size, unless the symbol states a count under 10.
- The range rule of rule 3 applies to any range a state publishes. Where every
  performance level is published as a range, the proficiency share runs from the sum
  of the lower endpoints of the proficient levels to the sum of their upper
  endpoints; width and midpoint are taken from those endpoints, and the share enters
  at the midpoint when the width is 10 points or less.
- The participation rule applies where the state prints a participation rate by group
  and is recorded as not applicable elsewhere. Where the file prints the complement
  (a not-tested percentage), the rate is 100 minus it. A printed value is read as a
  range with the midpoint convention. A participation column masked in more than half
  of the district-subject-group rows that carry a printed proficiency rate is treated
  as not printed. Where participation is printed, a cell with no printed value fails.
- Rule 5 applies through the test-replacement table for 2022-2025 (Section 6.6).
  Where the instrument behind the report-card result differs from the instrument
  behind the state's EDFacts result in 2021, the first report-card year is flagged in
  that subject as a source change.

Graduation family. Rules 1, 2, 6 and 7 apply, with rules 1 and 2 tested as in Section
5.1. Rule 3 applies to the cohort count and the graduation rate, with the same range
rules and robustness samples. Rules 4 and 5 have no graduation counterpart. Rule 6
uses each event table's groups unchanged, with cohorts coded over 2011-2021, so a
state whose treatment year is 2010 or 2011 has no graduation pre-reform year and is
left out.

SEDA family. Rules 1, 2, 6 and 7 apply on the LEAID, tested as in Section 5.1. Rules 3
and 4 do not apply because, as the SEDA documentation describes, SEDA screens its
estimates before publication: it publishes an estimate only where at least 20 unique
students contribute, drops estimates with low participation, and removes imprecise
estimates. Rule 5 does not apply because SEDA links every state test to a common
scale. A district-year-subject enters when the all-students mean and both subgroup
means of the gap are present.

### 5.3 Panels

The unbalanced panel, in which a unit enters with the outcome in any window year, is
primary. A balanced panel, in which a unit needs a usable gap in every window year of
its family, is a registered robustness check. In the high school family the balanced
panel spans the federal and the report-card years, so only states with report-card
coverage in every year can contribute. A balanced SEDA panel cannot be formed, since
every SEDA district lacks 2020 and 2021; the SEDA family has no balanced-panel check.

The number of states behind gap (a), and the number of districts and states behind
gaps (b) and (c) and the two graduation gaps, are reported for the primary panel, the
balanced panel and each suppression sample once the rules are applied. The number of
state-years contributed to gap (a) and district-years contributed to gaps (b) and (c)
by each report-card year is reported for each year.

### 5.4 Treated-unit floor

A treated-unit floor applies to the Callaway–Sant'Anna models of gaps (b) and (c) in
the high school and SEDA families. It does not apply to the graduation family or to
gap (a), which has no covariates.

A cohort with fewer than 20 treated units at its base period is excluded from every
covariate-adjusted Callaway–Sant'Anna model of that gap and event set. The base
period is the last window year before the cohort year with data, which is did's
universal base period. Treated units are counted in the primary model's panel of the
gap and event set (primary suppression sample, unbalanced panel, unweighted). The
exclusion covers the models under both weightings and both panel rules, every
robustness variant and split in which the cohort is a treated cohort, and the Lee and
dose-scaling refits, which reproduce those panels. Where a shortened window makes the
cohort a not-yet-treated control, it stays. The excluded cohort's states leave the
model as rule 6 removes a state.

Each excluded cohort is fitted separately without covariates on its gap's primary
panel with every cohort present. Its group-time effects and did's group aggregate are
reported in an appendix with its treated-unit counts. Every cohort's count is
reported, with the cohorts removed and the number of cohorts behind each primary
model. The regression-based secondary estimators are not affected by the floor.

The reason for the floor is the propensity-score model of the doubly robust
estimator. For each cohort and year the estimator fits that model on the treated and
comparison units of the comparison, with an intercept and the four covariates. With
few treated units the model approaches separation, the fitted probabilities and the
weights built from them become unstable, and the adjusted contrast rests on covariate
values far from those of the treated units.

## 6. Outcome construction

### 6.1 The measurement problem and V

Published files report the share of tested students scoring at or above a
proficiency cut. A percentage-proficient figure is not comparable across states,
because each state uses its own test and cut, or across years within a state, because
states replace tests and move cuts.

The study converts proficiency shares into standard deviation units with the
single-cut probit transformation of Ho and Reardon (2012). If achievement within a
group is normally distributed, the share above a cut locates the cut relative to the
group mean, and the inverse normal function Φ⁻¹ converts the share into that
position. For two groups with proficiency shares p_A and p_B on the same test and cut,

V = Φ⁻¹(p_A) − Φ⁻¹(p_B).

The cut cancels out of the difference. Under the maintained assumption that both
groups' scores are normal with a common variance, V is the difference between the
two group means divided by that common within-group standard deviation, the pooled
within-group standard deviation of Ho and Reardon (2012). That is the unit of gaps
(b) and (c). The files report a single cut, so the assumption is maintained rather
than tested, and it is listed as a limitation.

Computation rules: percentages are divided by 100 before conversion; a share of 0 or
1 is clamped to [1/(2n), 1 − 1/(2n)], where n is the cell's tested count, or, in
report-card cells with no exact count, the count the floor was applied to (the
minimum group size or the lower bound of the band); a district's probit score Φ⁻¹(p)
uses the same clamp, so V equals the difference of the two groups' scores.
Delta-method standard errors from binomial sampling in each share are computed for
description only. They do not include the error from entering a range at its
midpoint, and in report-card cells they are left blank unless both counts of the gap
are exact.

### 6.2 High school achievement gaps

Gap (a), the between-district poverty gap. Within each state, the quintile set is
the districts that pass rules 1 and 2, have a SAIPE 2009 rate (children 5-17 in
poverty over children 5-17), and have a 2010 CCD grade span (`GSLO` to `GSHI`)
reaching grade 12. The districts are ranked by the rate, ties broken by LEAID, and
assigned quintile q = ceiling(5r/n), where r is the rank and n the number of districts
in the set; quintile 1 is the lowest poverty. The assignment is fixed in every year,
so districts cannot move between quintiles in response to a reform.

For each state-year-subject, gap (a) is the mean district probit score of quintile 5
minus that of quintile 1, each mean weighted by the district's total 2010 CCD
membership (`MEMBER`), fixed across years, over the districts with a usable
all-students cell that year under rules 3 and 4. A district's probit score Φ⁻¹(p) is
the position of its mean relative to the cut in units of that district's own score
distribution. Gap (a) is therefore a difference between enrollment-weighted means of
scores each measured relative to its own district's distribution, not a difference
in a common unit; it reads as a common-unit gap only where the districts' standard
deviations are similar. This is listed as a limitation. A district without a valid
2010 membership (missing, a reserve code, or 0) is left out of gap (a) and stays in
gaps (b) and (c). A state-year with no usable district in quintile 1 or quintile 5
has no gap (a) row. Gap (a) does not use school-reported free-lunch status and is
unaffected by CEP.

Gaps (b) and (c), the within-district racial gaps. For each district-year-subject,
gap (b) is V = Φ⁻¹(p_Black) − Φ⁻¹(p_White) and gap (c) is V = Φ⁻¹(p_Hispanic) −
Φ⁻¹(p_White). A gap uses a district-year-subject only when both of its subgroups pass
rule 3 in the sample and, from 2013, rule 4.

Orientation. Gap (a) is the highest-poverty quintile minus the lowest, and gaps (b)
and (c) are the minority group minus White. All three are usually negative, and a
positive effect means the gap narrowed. This is the reverse of Reardon's sign
convention.

Subjects. Mathematics and reading/language arts are computed separately. The outcome
in estimation is the mean of the two subjects' values in a unit-year (district-year
for gaps (b) and (c), state-year for gap (a)). Both subjects are required; a
unit-year with one subject is missing.

The three gaps form one family for the multiplicity adjustment (Section 8.4).

### 6.3 High school report-card years

Proficiency shares and tested counts are read through one loader per state-year
driven by the harmonization table, converted to V by the functions of Section 6.1,
and appended to the high school panel with a column naming the source (`edfacts` or
`report_card`).

Each harmonization row records the file, sheet and column names for the district
identifier, subgroup, subject, tested count and proficiency rate; the subgroup codes
for Black, Hispanic and White; the all-students row used for gap (a); the proficiency
levels counted as proficient under the state's federal-accountability definition for
the year; the suppression symbols and how each is read; the minimum group size where
no count is printed; the participation column where one exists; and the high school
grade, course and test group. The table is deposited.

Report-card districts are matched to LEAIDs through a crosswalk built from the CCD
LEA directories for 2022-2024: the state's district code against CCD `ST_LEAID`, and,
for states whose files print names only, a unique match of the normalized name within
the state. Ambiguous and unmatched names get no LEAID. Every name match carries a
dated author check before use.

Where the state's high school result in a subject is formed from more than one
component (for example several end-of-course tests, or a test given in more than one
grade), the components whose tested count and rate are both printed are pooled with
the counts. A single printed component is used alone. With none printed, the cell is
missing. A component whose count is printed but whose rate is suppressed counts as
suppressed.

Gap (a) uses the all-students row named in the harmonization table, with the
quintiles, membership weights and formation of Section 6.2. A state whose files print
no all-students row has no report-card gap (a).

Spreadsheets are read with `readxl`, binary workbooks (`.xlsb`) with `readxlsb` in row
ranges where a sheet is large. Microsoft Access databases are exported to CSV by a
script run in the project container with mdbtools. The CSV copies are archived beside
the source files as their own manifest rows with checksums and the export command. No
hand-saved copy of any file enters the analysis.

No source indicator enters any model (Section 7.1). The source column serves the
source split (Section 11).

### 6.4 Graduation gaps

The secondary family is the within-district Black–White and Hispanic–White gaps in
the four-year adjusted cohort graduation rate, 2011-2021, from the EDFacts LEA files.
The gap is V computed from the two groups' graduation rates exactly as for
proficiency shares, with the 30-student floor on the cohort count and the range rules
and robustness samples of rule 3. Rate labels in the long-layout files are mapped to
the range notation of rule 3 according to ED's file documentation; a label outside
the mapping stops the step and is logged. Rows that carry no LEA identifier are
dropped. There is one outcome per district-year and no subject mean. There is no
poverty-quintile graduation gap.

A graduation rate is not a cut on a test scale. The graduation gap is a gap in a
binary outcome expressed in probit units, not a scale-invariant achievement measure.
It has no power calculation, since no graduation file is opened before registration.

### 6.5 SEDA gaps

SEDA administrative-district means are already on a common standardized scale, so no
probit conversion is applied. The study uses the cohort-standardized (CS) scale,
which SEDA's documentation defines in standard deviations of a national
grade-subject distribution for fixed reference cohorts.

The long file is expected to hold one row per district, subject, grade and year,
with the mean, its standard error and the tested count for all students and for the
Black, Hispanic and White subgroups as columns. Column names are taken from the
codebook when it is downloaded at stage 2. Any difference from this expected layout,
and the mapping used, is logged in the deviations log. Where SEDA publishes its own
gap columns they are not used, because SEDA's sign convention is the reverse of the
study's. Where SEDA publishes two standard errors for a mean, one with and one
without linking error, the one without linking error is used, which the SEDA
documentation describes as the one for comparisons within a state.

Gaps (b) and (c) are formed within each district-year-subject from the grade 3-8
means of the gap's two groups. For each grade k at which both groups have a mean, the
grade weight is w_k = 1 / (se_A,k² + se_W,k²), the inverse of the sum of the two
groups' squared standard errors at that grade. The same weights pool both groups, so
the gap is Σ_k w_k (m_A,k − m_W,k) / Σ_k w_k, where A is the Black or Hispanic group
and W the White group, and its standard error is one over the square root of Σ_k w_k.
Using common weights keeps the grade mix the same for both groups.

Gap (a) uses the SEDA quintile set: within each state, the districts that pass rules
1 and 2 over the SEDA tested years, have a SAIPE 2009 rate, and have a 2010 CCD grade
span that includes at least one grade from 3 to 8; ungraded or missing span ends do
not qualify. Quintiles are assigned as in Section 6.2. Each district's all-students
grade means are pooled with weights w_k = 1 / se_all,k². Gap (a) is the 2010
membership-weighted mean of the pooled all-students means in quintile 5 minus
quintile 1, with the rules of Section 6.2 for missing membership and empty quintiles.

Subjects are averaged within unit-year, both required. The 2022-2025 years are
marked, because SEDA builds them from public suppressed state data rather than
restricted-use counts. The mark serves the span split; no model takes it, since it is
a function of the year alone.

### 6.6 Test-replacement table

`data/reference/test_replacement.csv` has one row per state and end year, 50 states
and DC, 2010 through 2025. Columns: `state`, `sy_end`, `replaced_math`,
`replaced_rla`, `replaced` (1 if either subject is 1), `assessment_math`,
`assessment_rla` (the regular high school test behind that year's reported result),
`source`, `evidence` (`documented` or `inferred`), `notes`, `author_check`.

Coding rules:

- Rule 5 governs every row. Only the regular assessment is coded; alternate-assessment
  changes go in `notes`.
- Sources, in order: the SEA's assessment history page (Wayback Machine copies
  allowed, cited with archived address and capture date); the ESEA flexibility
  request, ESEA accountability workbook or ESSA plan. Where a state has no single
  history page, SEA-published program overviews, technical reports and press releases
  count as the SEA source. The EDFacts lists of significantly changed assessments are
  pointers only and cannot code a row. A replacement is coded only when confirmed
  from two sources other than those lists.
- `documented`: a cited source states which test was used that year or documents the
  change in that year. `inferred`: coded 0 because no change was documented. A 1 is
  never inferred.
- `MIXED:` begins the note of a year that mixes old and new results. `CHECK:` marks a
  documented change whose year is ambiguous; no row carrying `CHECK:` is used until
  the author resolves it.
- End year 2020 has a row for every state coded 0 with the test then in force marked
  "(not administered)". Where a documented change fell in 2019-20, the 1 goes on the
  first year whose reported result can come from the new test, 2021.
- Every row coded 1 carries a dated author confirmation that the source was opened and
  the coding checked against the rule. The author checks every row before it is used.

The 2022-2025 rows are coded before any report-card file is opened, for every state,
including states the report-card years do not cover. Any change found later that the
table below does not list is coded under the same rules and logged.

#### Test-replacement flags for 2022 through 2025

The 2022-2025 rows (408: 51 jurisdictions, four years, two subjects) were coded in
the review of 2026-11-18 from state agency sources, without opening any data file,
and were re-verified on 2026-11-19. The flags are those in
`data/reference/test_replacement.csv`. Thirty-six state-year-subject rows carry a flag
of 1:

| State | End year | Subject | Change | Coverage |
|---|---|---|---|---|
| AK | 2022 | Both | AK STAR grade 9 replaced PEAKS | Conditional |
| AZ | 2022 | Both | ACT Aspire grade 9 and ACT grade 11 replaced AzM2 | Conditional |
| IN | 2022 | Both | SAT grade 11 replaced ISTEP+ grade 10 | Conditional |
| KY | 2022 | Both | Kentucky Summative Assessment replaced K-PREP | Conditional |
| NJ | 2022 | Both | NJSLA ELA reported for grade 9 only (change of tested grade); a single Algebra I measure as the high school mathematics result | Covered |
| FL | 2023 | Both | FAST ELA Reading and B.E.S.T. EOCs replaced FSA (mathematics MIXED: fall 2022 FSA EOCs in the same year) | Conditional |
| ID | 2023 | Both | Grade 11 ISAT replaced grade 10 ISAT as the high school test (change of tested grade; MIXED: banked grade 10 scores count) | Conditional |
| ME | 2023 | Both | Maine Through Year Assessment replaced MAP Growth; tested grade moved to grade 10 | Conditional |
| TX | 2023 | Both | STAAR redesign | Covered |
| VT | 2023 | Both | VTCAP replaced Smarter Balanced grade 9 | Conditional |
| AR | 2024 | Both | ATLAS replaced ACT Aspire | Covered |
| GA | 2024 | Math | Algebra: Concepts and Connections replaced Algebra I and Coordinate Algebra | Conditional |
| NY | 2024 | Math | Next Generation Algebra I Regents from June 2024 (MIXED) | Covered |
| OK | 2024 | Both | Grade 11 test moved from district choice of ACT or SAT to the ACT | Not covered |
| TN | 2024 | Math | Updated mathematics EOC tests first given in 2023-24, followed by a new standard setting | Conditional |
| IL | 2025 | Both | ACT replaced the SAT | Covered |
| KS | 2025 | Both | Redesigned KAP on a new scale | Covered |
| ND | 2025 | Both | ND A+ Summative Assessment replaced NDSA | Conditional |
| NY | 2025 | Math | Total Cohort result combines Common Core and Next Generation Algebra I scores (MIXED) | Covered |
| UT | 2025 | ELA | English subtest removed from Utah Aspire Plus | Conditional |
| VA | 2025 | Math | SOL mathematics tests on the 2023 standards from spring 2025 (MIXED) | Conditional |

Codings of note at 0: the 2024 move to the digital SAT (a delivery change on a
maintained scale); DC CAPE in 2024 (a change of name and governance with the PARCC
design and scale kept); Virginia 2025 reading, since the first administration of an
EOC Reading test on the 2024 English standards is not documented within the window;
New York reading in every year, since the Next Generation ELA Regents begins in June
2026; Maryland 2022, because the flag for the MCAP program falls on 2021 (a shortened
MCAP was given for the 2020-21 school year, in early fall 2021, and 2021-22 was the
first full administration of the same program), and under rule 5 the flag goes on the
first year whose reported result comes from the new test; District of Columbia 2022,
since no source from the Office of the State Superintendent of Education states a
replacement and that office reports spring 2022 as PARCC; and Rhode Island 2022.

Other items of the review are fixed as follows. Idaho 2023 is 1 in both subjects: the
move from the grade 10 to the grade 11 ISAT is a change of tested grade and so a
change in the instrument behind the reported result, as for New Jersey 2022. Rule 5
flags a change of tested grade in every year from 2010 through 2025. New York 2025
mathematics is 1 as a mixed year. Virginia 2025 reading is 0. The Tennessee 2024
mathematics row records what changed beyond the cut scores as its sources document
it.

The full test-replacement table for 2010 through 2025 was re-verified row by row under
the rules above on 2026-11-19. Rows for which only one source documents a change, or for
which the sources do not settle the year, are coded 0 under the two-source rule, with
the single source recorded in the notes. The table is deposited with the registration.

### 6.7 Community Eligibility Provision indicator

CEP is a time-varying control in the regression-based secondary estimators only.
For 2010-2013 the CCD has no CEP field, and the indicator is state availability from
`data/reference/cep_phase_in.csv` (the first school year districts in the state could
participate, from a USDA or FRAC source): 1 from that year on. For 2014-2024 a school
is under CEP when its CCD National School Lunch Program status field carries the
community eligibility value, and the district-year indicator is 1 when any school in
the district is under CEP. For 2025 no Characteristics file is archived, and each
district carries its 2024 value, flagged `cep_carried` = 1. For gap (a), a state-year
outcome, the control is the share of that state-year's gap (a) districts under CEP:
quintile 1 or 5 districts with a valid 2010 membership, retained under the event set,
with a usable all-students outcome in both subjects that year.

## 7. Identification and estimation

### 7.1 Primary estimator

The primary estimator is the group-time average treatment effect of Callaway and
Sant'Anna (2021), fitted with `did::att_gt` and aggregated with `did::aggte`, with
these settings:

- comparison group: not-yet-treated and never-treated states
  (`control_group = "notyettreated"`);
- estimation: doubly robust (`est_method = "dr"`), which combines an outcome
  regression with a propensity model and is consistent when either is correct;
- base period: universal (`base_period = "universal"`); the reference period is the
  last window year before the cohort year with data, event time -1 where it exists;
- clustering: state (`clustervars = "state"`);
- panel: `allow_unbalanced_panel = TRUE` for the primary models; the balanced panel is
  the robustness model, and every model is fitted under both rules;
- aggregation: dynamic, event times -5 through +8 (`min_e = -5`, `max_e = 8`,
  `na.rm = TRUE`); the overall post-reform average is the equal-weight mean of the
  estimated event times 0 through +8.

Event time is measured in school years. Because 2020 (high school) and 2020-2021
(SEDA) are absent, some cohorts have event times with no estimate, and the event-time
coefficients rest on different cohorts. The number of cohorts, treated states and
units behind each coefficient is reported.

Covariates. Gaps (b) and (c) are estimated with four pre-treatment district
covariates: the log of 2010 CCD total membership; the SAIPE 2009 child-poverty rate;
and the Black and Hispanic shares of 2010 CCD school membership, summed within the
district over schools reporting valid race and total counts, all grades. A district
without a valid value for any of them is left out of the gap (b) and (c) models. The
same four covariates are used in every family. Gap (a) is estimated without
covariates (`xformla = ~1`), so the estimator reduces to unconditional
difference-in-differences with not-yet-treated controls; gap (a) is a state-year
outcome and the covariates are district characteristics.

Time-varying controls. `did` conditions only on baseline covariates. The
test-replacement flag and CEP enter the regression-based secondary estimators only.
No source indicator enters any model of the high school family. The source of a row
is a function of the year alone, since every 2022-2025 row is a report-card row and
every earlier row a federal row. A fixed unit covariate marking the source of a
unit's first year would be constant within every comparison that reaches back before
2022 and would separate treatment in the comparisons inside 2022-2025, so the doubly
robust adjustment could not be formed. In the regression-based estimators the year
effects absorb a year-varying source indicator.

No post-treatment variable enters any model. Controlling for something the reform
may have changed would absorb part of the effect.

### 7.2 Weighting

Gaps (b) and (c) are estimated unweighted in the primary models. Each district-year
counts once, so the estimand is the effect in the average district. A registered
robustness version weights each district through did's `weightsname`, with a weight
fixed across years:

- high school family: the number of students in the gap's two groups (Black and
  White, or Hispanic and White) tested in 2010, averaged over mathematics and
  reading/language arts;
- graduation family: the 2011 cohort count in the gap's two groups;
- SEDA family: SEDA's tested count of the gap's two groups in 2010, summed over the
  grades 3-8 that report it and averaged over the two subjects (both required and
  positive).

A district without the weight's base-year row is left out of the weighted models
only, and the number left out is reported. Gap (a) uses the fixed 2010 membership
weight inside the quintile means and does not involve this choice. A difference
between the weighted and unweighted estimates would suggest that the effect varies
with district size.

### 7.3 Secondary estimators

Four secondary estimators are registered so that the result does not depend on the
weighting and comparison-group choices of one estimator. Each runs on all three event
sets. For the district gaps each runs on the unbalanced panel of the primary model;
the balanced-panel versions are reported in an appendix.

Sun and Abraham (2021): the interaction-weighted estimator, fitted with `fixest`
(`sunab`), state clusters.

Borusyak, Jaravel and Spiess (2024): the imputation estimator, fitted with
`didimputation`. It fits the untreated trend on untreated observations and predicts
the counterfactual for each treated observation. The event-time and overall weights
are built over the treated observations whose unit has at least one untreated
observation. Treated units with none have no unit effect to impute; their number is
recorded.

Synthetic difference-in-differences (Arkhangelsky et al., 2021), fitted with
`synthdid` at the state level, cohort by cohort. Gaps (b) and (c) are first averaged
to state-year, unweighted over the districts in the primary panel; gap (a) is already
state-year. `synthdid` needs a balanced state-by-year matrix, so the states with a
mean in every window year of the family enter and the rest are left out and counted.
Each cohort's states are compared with the states never treated within the window. A
cohort needs at least two pre-reform years. Standard errors come from 200 placebo
replications among the control states; where there are not more control states than
treated states, no standard error is computed and the status is recorded.

Stacked regression with a five-year clean-control window, fitted with `fixest`. Each
cohort's sub-experiment covers event times -5 to +5 within the window years. Clean
controls are states untreated through the cohort year plus five: never treated within
the window, or a later cohort treated more than five years later. The regression
applies the corrective sample weights of Wing, Freedman and Hollingsworth (2024),
with sub-experiment-by-unit and sub-experiment-by-year fixed effects in place of the
treatment-group and event-time indicators of their specification, and state
clusters.

Controls in the regression-based estimators (Sun–Abraham, imputation, stacked, two-way
fixed effects). High school family: the state-year test-replacement flag and CEP
(district-year for gaps (b) and (c), the CEP share for gap (a)); for gaps (b) and (c)
also the four covariates, each interacted with year (with sub-experiment-by-year in
the stacked regression), which is the regression form of the conditional
parallel-trends assumption. Graduation family: CEP and, for both gaps, the four
covariates by year, with no test-replacement flag, which has no bearing on a
graduation rate. SEDA family: CEP and, for gaps (b) and (c), the four covariates by
year; gap (a) takes the CEP share; no test-replacement flag, since rule 5 does not
apply. `synthdid` takes no controls.

The overall averages in the agreement table differ in which event times they cover
and how they weight cohorts. The primary estimator, Sun–Abraham and the imputation
estimator report the equal-weight mean of their estimated event times 0 through +8.
The stacked regression reports the equal-weight mean of event times 0 through +5,
because its sub-experiments end at +5; it has no estimate at +6 to +8. `synthdid`
estimates each event time by pooling the cohorts' effect paths weighted by their
number of treated states, and its overall average is the equal-weight mean of those
event-time estimates from 0 through +8; its own pooled average, which weights each
cohort by treated states times post-reform years, is reported beside it and is not
used in the agreement table. The estimators also differ in comparison group and, for
`synthdid`, in the states that enter. The agreement table therefore compares overall
post-reform averages that are close in definition but not identical. Standard errors
come from each estimator's covariance of its event-time estimates (custom weights in
`didimputation`, the placebo replications in `synthdid`). Two-way fixed effects with a
single post-reform indicator and the same controls is reported as a comparison row
only.

### 7.4 Anticipation

Districts may change behavior before a reform takes effect, because litigation and
legislative debate signal what is coming. The anticipation check dates each reform
one year before the coded reform year, through did's `anticipation = 1`, which makes
event time -2 the reference period. Event time -1 is then estimated and reported as
its own coefficient, the overall average stays the mean of event times 0 through +8,
and the bound sets take -2 as the reference with -1 as a post-reference period of
zero weight.

### 7.5 Implementation

All estimators are run in R in the environment of Section 15.10. The wild cluster
bootstrap and the Romano–Wolf step-down are computed on the `did` influence function
(Section 8) rather than through `fwildclusterboot` and `wildrwolf`, whose functions
take regression objects that the primary estimate is not. Neither package is used.

### 7.6 Continuous-treatment estimator

The study adds the dynamic estimator of de Chaisemartin and D'Haultfœuille (2026) for
non-binary and non-absorbing treatments as an exploratory estimator, fitted with
`DIDmultiplegtDYN` 2.4.0 (`did_multiplegt_dyn()`).

The treatment is district per-pupil state-plus-local revenue (Section 9) in 2025
dollars, missing under the revenue floor, rounded down to the nearest $1,000 (the
bin). A sensitivity run uses $2,000 bins. For gap (a) the treatment is the state-year
revenue gap of Section 9, binned the same way, over a district set fixed across
fiscal years 2010-2024 (the gap (a) quintile districts of the family, retained under
the primary event set, with 2010 membership above 0 and a revenue value under the
floor; a state-year needs a district in both quintiles). The state is then the unit
and the cluster.

A unit's baseline bin is its bin in the first window year with a treatment value. A
unit switches in the first year its bin differs from its baseline bin. Units whose
bin has not changed are the stayers. The binned value enters as a discrete treatment
(the `continuous` option is not set): each switcher is compared only with stayers of
the same baseline bin, and switchers with no such stayer are dropped and counted.

F-33 covers fiscal years 2010-2024, so 2025 and SEDA's 2009 have no treatment. The
windows are high school 2010-2019 and 2021-2024; SEDA 2010-2019 and 2022-2024;
graduation 2011-2021. Periods are calendar school years: missing outcome years (2020
in high school, 2020-2021 in SEDA) enter as rows carrying the treatment and no
outcome, so that effect l is l years after the first switch.

Nine effects and five placebos are estimated. The package's `Effect_l` is reported at
study event time l - 1, so `Effect_1` to `Effect_9` are event times 0 through +8. The
package's `Placebo_l`, which it numbers -1 to -5, compares year F - 1 - l with the
reference year F - 1, so `Placebo_1` to `Placebo_5` are study event times -2 to -6
relative to the reference year -1. Both labels are reported.

The sample is the primary suppression sample, unweighted, with the primary event
set's retained units (rules 1, 2, 6 and 7), one run per gap and family rather than
one per event set, and no covariates. The number of switchers and stayers is reported
at each effect and placebo, counted under the package's sample rules for a discrete
treatment (stayers of the switcher's own baseline bin; a bin whose units all share one
switch date, and a bin-year in which every unit has switched, are dropped). Stayers
are the distinct not-yet-switched units used in any year of the effect. An effect or
placebo is marked not estimable when fewer than 20 stayers enter it or its stayers lie
in fewer than 3 states. Inference uses the package's analytical standard errors
clustered by state, with the package's caveat on analytical errors reported beside the
results.

The estimator runs on the high school, SEDA and graduation gaps. Its results are
reported after all event-based results and are labelled exploratory.

## 8. Inference

### 8.1 Clustering

Districts within a state share the same reform and the same test, so their errors are
correlated. All inference is clustered at the state level.

### 8.2 Wild cluster bootstrap

Only a few states reform within the window, and with few clusters the usual clustered
standard errors are too small. A wild cluster bootstrap with Webb weights and 9,999
replications is the primary inference method.

The primary estimate is an average of doubly robust group-time effects, not a
regression coefficient, so the bootstrap is applied to the estimator's influence
function. For an estimate θ (the overall post-reform average or one event-time
estimate), let ψ_i be the value of `did`'s influence function for unit i, scaled so
that θ̂ − θ is approximately (1/n) Σ_i ψ_i over the n units of the model. For each
state c, S_c = Σ_{i in c} ψ_i. Then

- the clustered standard error is s = √(Σ_c S_c²) / n;
- replication b draws an independent Webb weight v_cb for every state from the
  six-point distribution {±√1.5, ±1, ±√0.5} with equal probabilities, and sets
  θ*_b = (1/n) Σ_c v_cb S_c, a draw centred on zero;
- the bootstrap t-statistic is t*_b = θ*_b / s, with s held at its sample value;
- the critical value c is the 0.95 quantile of |t*_b| over the 9,999 replications
  (R's quantile type 7);
- the 95 percent bootstrap interval is θ ± c·s, a symmetric percentile-t interval;
- the bootstrap p-value is (1 + #{b : |t*_b| ≥ |θ|/s}) / (9,999 + 1).

This is the multiplier bootstrap that `did` itself provides, with Webb weights in
place of the Rademacher weights `did` 2.5.1 draws (through BMisc 1.4.10). It is
applied to the overall post-reform average and to every event-time estimate; the
event-time intervals are pointwise.

Where fewer than five treated states contribute to a model's overall post-reform
average, the randomization p-value of Section 8.3 is reported beside the bootstrap
interval and the report marks the model, because the bootstrap's accuracy with so few
treated clusters is uncertain.

### 8.3 Randomization inference

Reform years are reassigned across states and the estimator is rerun on each
reassignment. An assignment gives the observed cohort years to states drawn from all
states in the model's fitted panel (never treated within the window, or treated
within it), keeping the number of states per cohort year. The treated-unit floor is
not reapplied to placebo cohorts: placebo assignments are drawn among the states of
the fitted panel, which already excludes the states the floor removed. This gives the
distribution of the estimate when reforms are randomly timed and placed.

The number of reassignments is R = 10,000 for the primary model of each gap in each
family (primary event set, unweighted, unbalanced panel, primary suppression sample)
and R = 1,000 for every other model. With N states in the panel and m_k states in
cohort year k, the number of distinct assignments is M = N! / (∏_k m_k! · (N − Σ_k
m_k)!). Where M is at most R, every assignment is enumerated once, the observed one
included, and the p-value is the share of the M assignments whose estimate is at
least as far from zero as the observed one. Otherwise R distinct assignments are drawn
at random, each assignment at most once, and the two-sided p-value is

p = (1 + #{r : |θ*_r| ≥ |θ| − τ}) / (R + 1), with τ = 10⁻⁹ · max(1, |θ|).

The absolute tolerance τ counts a placebo estimate that reproduces the observed one up
to floating-point error as at least as extreme. The same tolerance applies under
enumeration.

### 8.4 Multiplicity

Each of H1, H2 and H3 concerns one gap and is evaluated at the unadjusted 95 percent
level, since the bound sets and intervals of Section 12 are 95 percent sets. The
Romano–Wolf step-down p-values are reported as the family-wise view of the three gaps
and do not change any verdict.

The step-down is computed on the same 9,999 bootstrap draws. One set of state-level
Webb weights is drawn per event set and shared by every model in it, so the draws
carry the dependence among the gaps, which are measured on overlapping districts in
the same states. The step-down orders the hypotheses by |t|, takes the maximum
bootstrap statistic over the hypotheses not yet rejected, and makes the adjusted
p-values monotone. The family is the three gaps (a), (b) and (c) within an outcome
family, event set and panel rule. The primary family takes the unweighted model of
each gap; a second family takes the weighted models of gaps (b) and (c) with gap (a)
unweighted. The graduation family's adjustment is over its two gaps. The growth
contrasts of the three gaps (Section 12.3) form their own family on the same draws.
Because the draws are shared, the unadjusted p-value in the Romano–Wolf table equals
the bootstrap p-value.

### 8.5 Sensitivity bound sets

The relative-magnitudes bounds of Rambachan and Roth (2023) give the range of
post-reform effects consistent with the data when post-reform departures from
parallel trends may be up to M̄ times the largest observed pre-reform departure. They
are computed with `HonestDiD` for M̄ in {0, 0.5, 1, 1.5, 2}, at the 95 percent level.
The bound set at M̄ = 1, which allows post-reform departures as large as the largest
pre-reform departure, is the headline result of each gap; elsewhere in this document
it is called the bound set at M̄ = 1.

The bounded quantity is the overall post-reform average: `l_vec` puts equal weight on
every estimated post-reform event time 0 through +8. The event-time estimates enter
with the reference period dropped, with their state-clustered covariance from the same
influence function. Beside the bounds the report gives the unadjusted confidence set,
HonestDiD's confidence set for the same quantity under exact parallel trends.

Search grid. Each M̄ starts on HonestDiD's default grid (±20 standard errors of the
bounded average, 1,000 points). While a bound lies within half a step of an edge, the
grid is widened on that side by its current width with the step unchanged, up to six
times. A bound set still at an edge after six widenings is given a status and no
bound. Each reported set carries its grid limits and point count, so no reported bound
set touches a grid edge.

Consecutive-block rule. HonestDiD reads the event-time estimates as consecutive
periods. Where the estimated event times are not consecutive around the reference
period, the bound sets are computed on the largest consecutive block of estimated
event times that contains the reference period and event time 0, with the post-reform
average taken over the block's post-reform event times with equal weights. The block
is named beside each bound set, and the missing event times of each such model are
listed with the reason (no cohort; no unit-year at that event time; cells present but
not estimable).

A model with no estimated pre-reform event time other than the reference, or whose
block does not reach event time 0, has no bound set and is reported with that status.
In the anticipation variant the reference is -2, with -1 a post-reference period of
zero weight.

### 8.6 Seeds

Every stochastic step derives its seed from one master integer, 130, by name, so
results do not depend on the order in which steps run. `seed_for(step)` starts at
h = 130 and, for each byte b of the step name, sets h = (31h + b) mod (2³¹ − 1). No
other literal seed is set in the analysis code. The step names are built from the
script, the family or outcome, the procedure and the model key:

| Procedure | Step name |
|---|---|
| Power simulation (step 8) | `power` |
| Callaway–Sant'Anna fits, federal years (step 5) | `05_primary <model key>`; graduation: `05_primary graduation <model key>` |
| `synthdid` placebo replications (step 6) | `06_secondary synthdid <gap> <event set>[ unbalanced]`; graduation: `06_secondary graduation synthdid ...` |
| Webb draws (step 7) | `07_inference bootstrap <event set>`; graduation: `07_inference graduation bootstrap <event set>` |
| Randomization reassignments (step 7) | `07_inference randomization <model key>`, with `<step name> workers` as the stream used when reassignments are evaluated in parallel |
| Full run (step 13) | `13_run_all <family> <procedure> <model key>`: `07_inference bootstrap`, `07_inference randomization`, `variants`, `variants randomization`, `05_primary thin cohorts` (and its ` group` aggregate), `06_secondary synthdid`, `dose`, and the Lee steps `lee share`, `lee primary`, `lee trim` |

Each run log lists the step names used. The blinding permutation (Section 15.3) uses
a separate seed that the author holds outside the repository; it must differ from
130.

## 9. Dose scaling

Reforms differ in the amount of revenue they move. Dose scaling expresses the effect
per $1,000 of revenue.

Revenue. District per-pupil state-plus-local revenue from F-33, (TSTREV + TLOCREV) /
V33. F-33 amounts are in thousands of dollars, so the ratio is in thousands per pupil.
Revenue is deflated to 2025 dollars with the CPI-U all-items index averaged over July
through June of each school year. A month missing from the published series is filled
with the mean of the two adjacent months, and every school year used must be complete.
A district-year with fall enrollment (V33) below 30, or with revenue above $100,000 per
pupil in 2025 dollars, is excluded before the revenue outcome is formed, and the
exclusions are counted.

Revenue outcome by gap. Gaps (b) and (c) and the graduation gaps: district revenue
per pupil. Gap (a), in every family: within each state-year, the 2010
membership-weighted mean revenue per pupil of quintile 5 districts minus that of
quintile 1 districts, over the districts that can enter gap (a) (retained under the
event set, valid 2010 membership) and have a revenue value under the floor.

Window. Both stages use end years 2010 through 2024, the years with F-33 revenue: the
first stage, the same Callaway–Sant'Anna model as the gap's unweighted unbalanced
primary model (not-yet-treated controls, doubly robust, the model's covariates and
treated-unit floor) with revenue as the outcome; and the reduced form, the gap's
primary model refitted on the same years. Both overall averages are taken over the
same event times, those estimated in both models.

Dose-scaled effect. The ratio of the reduced form's overall post-reform average to
the first stage's overall post-reform average, computed for every gap, family and
event set. Its 95 percent interval is the percentile interval (2.5 and 97.5 percent,
quantile type 7) of the ratio (θ_y + θ*_y,b) / (θ_r + θ*_r,b) over the 9,999 Webb
draws of Section 8.2, the same draws perturbing both stages. The first stage's own
interval is the percentile interval of θ_r + θ*_r,b over the same draws. When that
interval includes zero, the ratio's confidence set is unbounded and is reported as
unbounded. Revenue values are not trimmed beyond the floor.

The scaling requires an exclusion restriction: the reform affects gaps only through
revenue and not through other channels, such as accountability rules passed with it.
That is stated as an assumption. The reduced-form estimate of the full window remains
the primary answer to the research question.

## 10. Lee bounds

In high school some students leave before the tested grade. A reform that changes
dropout differently for the two groups of a gap would change the tested population
and the gap without any change in learning. A trimming bracket in the spirit of Lee
(2009), computed at the district-year level, addresses the threat for high school gaps
(b) and (c) on the primary model (primary event set, unweighted, unbalanced panel,
primary suppression sample). It is not a sharp bound in Lee's sense, because trimming
applies to district-year outcomes rather than to students. No bracket is computed for
gap (a), the graduation gaps (where dropout is part of the outcome) or SEDA.

Tested share. For each group g of the gap, the tested share in year t is the group's
tested count in year t (mean of the two subjects) divided by the group's CCD grade 9
membership in year t − 3, summed from the school membership files to the district.
The three-year lag is an approximation for the high school band: the EDFacts high
school files do not identify the tested grade in every state, so grade 9 membership
three years earlier stands for the cohort tested in year t whatever the tested grade.
The CCD files of 2007-2009 supply the membership for the early window years. Only
exact tested counts enter. Where the group count is not exact, the all-students count
and all-students grade 9 membership stand in if exact; otherwise the district-year has
no share. A band's lower bound or a minimum group size is a floor, not a count, and
does not enter.

Membership. A school's grade 9 all-students count is summed where reported. A
district's race count is unavailable when any school with grade 9 students lacks that
race's count. Where a membership file reports race by sex and a race-by-sex cell is
blank, the cell counts as zero only when the school's reported cells sum to its grade
9 total; otherwise the district's race count is unavailable.

Differential selection. For each group g, q_T(g) is the treated post-reform tested
share and q_C(g) = q_T(g) − ATT(g) its counterfactual, where ATT(g) is the effect on
the share from the same Callaway–Sant'Anna design. q_T(g) is aggregated as `did`
aggregates the overall effect: within each estimated event time 0 through +8, cohort
cell means weighted by the cohort's unit count, then the equal-weight mean over event
times. With p(g) = 1 − q_C(g) / q_T(g), the trimming fraction is
f = |p(minority) − p(White)|, bounded to [0, 1].

Trimming. The treated post-reform district-years of the primary panel number T. The
k = round(f · T) district-years with the highest outcomes are dropped and the primary
model is refitted; then the k with the lowest outcomes are dropped and the model is
refitted. Rounding is to the nearest whole number, with halves rounded to the even
number (R's `round`). The two estimates are the bracket.

## 11. Robustness checks

Each check is registered here, before the relevant data are opened. Each variant
changes one rule of the primary specification (unbalanced panel, primary suppression
sample, reference period -1, full window) and leaves every other rule unchanged. Each
is run with the Callaway–Sant'Anna estimator on all three event sets and both
weightings, with the treated-unit floor where Section 5.4 applies. For each variant the
bootstrap and the Romano–Wolf adjustment use 9,999 draws, the bound sets are computed
at every M̄, and randomization inference uses 1,000 reassignments. A shortened window
codes cohorts over the kept years: a state whose treatment year precedes the first
kept year has no pre-reform period and is left out.

Sample and measurement:

- Five-point ranges: a share enters only if exact or a range of 5 points or less (high
  school, graduation).
- Exact values: a share enters only if exact (high school, graduation).
- 2013 start: 2010-2012 dropped, so rule 4 applies in every remaining year (high school
  only; the fixed 2010 weights are kept; report-card years test participation where the
  state prints it).
- Balanced panel: the balanced Callaway–Sant'Anna models of Section 5.3 (high school,
  graduation).
- Weighting: the weighted models of Section 7.2 (all families).

Treatment definition and timing:

- Narrow event sets r1 and r2 in place of the full set (all families).
- Cohort drop: cohorts with fewer than three pre-reform window years removed, their
  states removed from the panel (all families).
- Anticipation: `anticipation = 1` (Section 7.4) (all families).

Sources and coverage:

- High school source split: the high school models on the federal years 2010-2021
  alone.
- Coverage split: the whole high school panel, federal years included, limited to the
  18 states listed as covered in every report-card year (AL, AR, CA, CT, DE, IL, KS,
  MA, MO, NV, NJ, NY, NC, OR, RI, TX, WA, WY); comparison states come only from those
  states. Two treated states of the primary set (Washington and Nevada) are among them,
  so the split is reported with its cohort counts.
- SEDA span split: the SEDA models on 2009-2019 alone and on 2022-2025 alone, because
  the two spans come from different source data.

Other estimators and appendices: the four secondary estimators on all three event
sets, compared with the primary estimator in the agreement table, with their
balanced-panel versions in an appendix; the thin-cohort appendix (Section 5.4); the
Lee bracket; the dose-scaled estimate with its first stage; and the $2,000-bin run of
the continuous-treatment estimator.

## 12. Evaluation of the hypotheses

### 12.1 Where the hypotheses are evaluated

The hypotheses are evaluated on the high school achievement family, the primary
outcome of the study, on the primary model of each gap: primary event set, unweighted,
unbalanced panel, primary suppression sample, with the treated-unit floor. The same
rules are applied to the graduation family (gaps (b) and (c): H2, H3, and H4 and H5
for those two gaps) and the SEDA family and reported beside the high school verdicts,
labelled as evidence on those outcomes. They do not change the high school verdicts.
Every hypothesis receives one verdict per gap, and the summary states the verdict for
each gap without combining gaps.

### 12.2 Agreement criterion

A point estimate is described as robust only when both parts of the criterion hold:

1. Estimators. Each of the four secondary estimators (Sun–Abraham, imputation,
   synthetic difference-in-differences, stacked regression) gives an overall
   post-reform average that has the same sign as the primary estimate and lies inside
   the primary estimate's 95 percent bootstrap interval. Two-way fixed effects is a
   comparison row and is not part of the criterion.
2. Variants. The primary-event-set estimate under each registered sample and
   weighting variant that exists for the family (five-point ranges, exact values, 2013
   start, balanced panel, weighted) has the same sign as the primary estimate and lies
   inside its 95 percent bootstrap interval.

A secondary estimator or variant that cannot be estimated is reported with its status
and does not count for or against the criterion. When fewer than three of the four
secondary estimators can be estimated, the criterion is not evaluable, and the
estimate is reported without a robustness description. The narrow event sets and the
timing checks are reported but are not part of the criterion.

### 12.3 Rules

H1, H2 and H3 concern the overall post-reform average of gaps (a), (b) and (c)
respectively. The verdicts are:

- not evaluable: the model has no bound set (Section 8.5);
- criterion not evaluable: fewer than three of the four secondary estimators can be
  estimated; the bound sets are reported and no robustness description is made;
- supported: the bound set at M̄ = 1 lies wholly above zero and the agreement criterion
  holds;
- contradicted: the bound set at M̄ = 1 lies wholly below zero (the gap widened) and
  the agreement criterion holds;
- not supported: any other case; the estimate is reported as a quantity in the
  direction it points, with its interval, and not as a finding.

For each gap the report also gives the bound set at M̄ = 0 and the largest M̄ in the
grid at which the bound set excludes zero, so a reader can see how much departure
from parallel trends the sign of the estimate tolerates. Where the consecutive-block
rule applies, the verdict refers to the block's post-reform average and says so.

H4 concerns the growth of the effect with event time. For each gap the growth contrast
is

G = mean(β₄, ..., β₈) − mean(β₀, ..., β₃),

the equal-weight mean of the estimated event-time effects +4 through +8 minus that of
0 through +3, over the event times estimated in each window. G is a linear combination
of the event-time estimates. It receives a 95 percent bootstrap interval from the same
influence-function draws (Section 8.2), a Romano–Wolf adjusted p-value across the
three gaps (Section 8.4), and relative-magnitudes bound sets at every M̄ with `l_vec`
set to the contrast weights (−1/n₀ on each estimated event time of 0 to +3 and +1/n₁
on each of +4 to +8, where n₀ and n₁ are the numbers estimated in each window). The
same contrast is formed from each secondary estimator's event-time estimates; the
stacked regression's late window is +4 and +5 only. The verdicts are:

- not evaluable: no estimated event time in one of the two windows, or no bound set
  for G;
- criterion not evaluable: fewer than three of the four secondary estimators give a
  contrast;
- supported: the bound set of G at M̄ = 1 lies wholly above zero, the point estimate of
  the gap's overall post-reform average is positive, and G is positive in each
  secondary estimator that gives a contrast;
- not supported: any other case, with G reported as a quantity.

The two windows rest on different cohorts, because only cohorts reforming by 2021
reach event time +4 in the high school window. The cohorts and treated states behind
each window are reported with G.

H5 concerns the dose-scaled effect of Section 9 and is evaluated by its 95 percent
interval, not by a bound set. The verdicts are:

- not evaluable: the first stage's interval does not lie wholly above zero, so the
  reform is not shown to have raised revenue and the ratio's confidence set is
  unbounded or does not describe reform-induced revenue; the first stage is reported;
- supported: the first stage's interval lies wholly above zero and the dose-scaled
  interval lies wholly above zero;
- not supported: the first stage's interval lies wholly above zero and the dose-scaled
  interval includes zero or lies below it; the estimate is reported as a quantity.

The continuous-treatment estimates are exploratory. They are reported beside the H5
verdict and do not change it.

## 13. Threats to validity and remedies

| Threat | Remedy |
|---|---|
| Researcher discretion in coding reforms | LRS list through 2011; written finality and formula-replacement rules after 2011, applied from the ruling or statute text before outcome data are downloaded; coding table deposited; two narrow event sets |
| Analytic choices responding to results | Registration before download; development and rehearsal on permuted event tables; code freeze before any estimate on the real assignment; one run; dated logs |
| Assessment changes coinciding with reforms | Scale-invariant outcome; test-replacement flag as a control in the regression-based estimators; source change flagged at the first report-card year |
| Non-normal latent distributions bias V | No remedy in the design; equal-variance normality is a maintained assumption and a stated limitation |
| Differential dropout alters the tested high school population | Grade 9 membership three years earlier by group; trimming bracket on gaps (b) and (c) |
| FRL classification breaks (CEP) | Poverty gap built on SAIPE, not free-lunch status; CEP as a control in the regression-based estimators |
| Composition change through migration | Poverty quintiles and all weights and covariates fixed at 2009 and 2010 values |
| Few treated clusters | Wild cluster bootstrap with Webb weights on the influence function; randomization inference; models with fewer than five treated states marked, with the randomization p-value beside the interval |
| Few pre-reform years for early cohorts | Cohort count reported for each coefficient; cohort-drop check |
| Late event times resting on few states | Cohorts and treated states reported beside every event time and the overall average |
| Negative weights under staggered adoption | Estimators built for staggered timing; two-way fixed effects as a comparison row only |
| Thin cohorts in covariate-adjusted models | Treated-unit floor of 20; excluded cohorts estimated without covariates in an appendix; coefficients on a single treated state marked |
| A few large districts dominating district estimates | Unweighted primary estimate for gaps (b) and (c); tested-count weighted version |
| Suppressed cells not missing at random | Ranges of 10 points or less at the midpoint; exact-only and five-point samples |
| Participation not observed in early years or some states | Rule 4 from 2013; 2013-start check; recorded as not applicable where a state prints no rate |
| Federal achievement files end at 2021 | Report-card years 2022-2025 for covered states; SEDA grades 3-8 through 2025; source, coverage and span splits |
| Report-card files differ in definitions, suppression and grade | Harmonization table, one row per state-year, deposited; matching rule against the 2021 EDFacts result; coverage split |
| SEDA 2022-2025 built from different source data | Span split |
| Parallel trends cannot be verified | Relative-magnitudes bound sets as the primary result; event-study pre-reform coefficients |
| Revenue scaling assumes an exclusion restriction | Stated as an assumption; reduced form remains the answer |
| Continuous estimator rests on a different assumption | Labelled exploratory; reported after the event-based results with switcher and stayer counts |
| Data revision | Archived files with SHA-256 checksums verified on every run; OSF and Zenodo deposits |

## 14. Power

Statistical power is the probability that a study detects an effect of a given size
when the effect is real. Power depends on the sample after suppression, which cannot
be known from documentation alone.

Before any outcome file for a year after 2013 is downloaded, power is computed by
simulation on the 2010-2013 federal high school files, which are downloaded first for
this purpose (stage 1, Section 15.5). The simulation uses the three high school gaps,
primary event set, unweighted, each on its own unbalanced primary panel over
2010-2013.

Each placebo draw assigns five placebo-treated states, the number of treated states in
the primary set with a post-reform year in the federal files (Washington, Indiana,
South Dakota, New Mexico, Nevada), with cohort years drawn uniformly from 2011 through
2013. Placebo states are drawn by the assignment rule of Section 8.3 from every state
in the model's panel. The real treated states stay in the panel as comparison units
and may be drawn as placebo states, as in the main design's randomization inference.
The treated-unit floor is not applied, since its effect depends on which states are
treated, which the placebo draws do not reproduce. There are 2,000 draws per gap, with
the seed `power`.

The minimum detectable effect is the exact inversion of the placebo distribution. The
critical value is the 0.95 quantile (type 7) of the absolute placebo estimates. The
minimum detectable effect is the smallest positive shift d such that at least 80
percent of the shifted placebo estimates, θ*_r + d, are at least as large in absolute
value as the critical value. Adding a constant to the treated post-reform outcomes
shifts every doubly robust group-time effect, and so their average, by that constant,
so the shifted draws are the distribution of the estimate under that alternative, with
no normality assumption. The normal approximation, (z₀.₉₇₅ + z₀.₈₀) times the standard
deviation of the placebo estimates, is reported beside it.

The ceiling is 0.10 SD. If the minimum detectable effect of any of the three gaps
exceeds 0.10 SD, the study is registered as underpowered and is described in the
registration and the report as a bounds analysis: every registered estimate and test
is computed and reported, the bound sets lead the presentation, and conclusions are
stated as ranges rather than as significance claims. The classification changes only
that description; the verdict rules of Section 12 and the reporting order of Section
16 are the same either way.

The minimum detectable effects of the three gaps and the resulting classification are
entered here and in the registration.

The simulation was run on November 19, 2026 with 2,000 placebo runs per gap on the
stage 1 panels (gap (a): 38 states; gap (b): 1,509 districts in 40 states; gap (c):
1,589 districts in 38 states). The minimum detectable effects at 80 percent power and
a 5 percent two-sided test, from the exact inversion of the placebo distribution, are
0.200 SD for gap (a), 0.190 SD for gap (b) and 0.166 SD for gap (c); the normal
approximation gives 0.208, 0.203 and 0.170. All three exceed the 0.10 SD ceiling, so
the study is registered as underpowered and is described as a bounds analysis. The
outputs of the simulation are in `outputs/08_power/` and are attached to the
registration.

The graduation and SEDA families are registered without a power calculation, because
no file of either is opened before registration.

## 15. Pre-registration, blinding, code freeze, staging and reproducibility

### 15.1 Pre-registration

The study is registered through the OSF Preregistration form as a standalone
registration after the power simulation and before any outcome file for a year after
2013 is downloaded. OSF stopped creating projects on November 16, 2026, so the
registration is not attached to a project. The stage 1 data files with their checksum
file and a copy of the manifest, this document, the event coding files and the
decision log are attached to the registration at submission.

The form records the hypotheses, definitions and sample rules; the estimators and
inference procedures; the master seed (130); the R and package versions; the code
license (MIT); the end year of each window; the post-2011 event coding table; and the
decision log. The outcome definitions and data sources of the SEDA family and the
report-card years, the report-card coverage rules and table, the test-replacement
flags for 2022 through 2025, the specification of the continuous-treatment estimator,
and the source, span and coverage splits are recorded in the fields of the form. The
form text is self-contained.

### 15.2 Logs

The decision log (`docs/decision_log.md`) records each author decision made before
filing that changes or adds to a rule in this document or departs from the proposal,
with the date, section, decision and rationale. It closes when the registration is
filed.

The deviations log (`docs/deviations.md`) records each departure from the registered
plan after filing, with the date, section, description and reason. Deviations are
expected to be of four types: rules stated in words here turned into exact code; data
sources substituted where a planned file is unavailable; code corrections found
during the rehearsal; and post-freeze corrections (Section 15.4). Coverage exclusions
found after download (Section 4.3) are logged there.

### 15.3 Blinding

The real reform years are public: they are listed in Section 3.2 and deposited with
the registration. The blinding therefore does not hide the reform years from anyone.
It means that no estimate on the real assignment of reform years is computed until the
code is frozen. Every step is developed and rehearsed on permuted event tables, so
analytic choices are made without seeing an estimate of the real effect.

Step 1 builds the event tables from the event files (the LRS list, the post-2011
court events and the post-2011 statute events, with columns `state, event_year,
event_type, source, notes`; `event_type` is court or legislative; `source` is LRS,
ELC-SC for a final state supreme court ruling, ELC-LC for a final ruling of a lower
court, or STAT for the statute rule). Post-2011 events must carry an end year of 2013
or later.

Step 1 writes the real tables (full, r1, r2) to the private folder (Section 15.8)
only, and writes to the repository a version of each in which the treatment years are
permuted among that set's treated states with the private seed. The set of treated
states, and so every state's group, stays real. A permutation identical to the real
table is rejected and the seeded stream drawn again. A set with fewer than two
distinct treatment years cannot be permuted and is written as is, with a note in the
log. Set r1 has two treated states with different years, so only one arrangement
differs from the real one, and its permuted table is the two years swapped; set r2 has
four treated states and 23 arrangements that differ from the real one. The protection
for r1 is therefore weak, which is listed as a limitation.

`data/reference/blinding_status.txt` reads `PERMUTED` until the real years are
restored. No step prints or summarizes treatment years while the status is
`PERMUTED`; counts by group are allowed. The sample and outcome steps read each
state's group only, which the permutation does not change. The estimation steps read
the permuted years. All outcome families, including the SEDA family and the
report-card years, are built into their panels and estimated on the permuted tables.

### 15.4 Rehearsal and code freeze

Each analysis step is built, tested and then rehearsed on the permuted tables at the
full replication counts: steps 3 through 7 and 9 through 11 on every family, every
robustness variant and split, the Lee bracket, the dose scaling and the report
builder. Corrections found in the rehearsal are logged in the deviations log before
the freeze. Results of the rehearsal are not interpreted. Public documents containing
published achievement results that were seen while the reference tables were compiled
are disclosed in the decision log and in Section 17.

The code is then frozen with the tagged commit `freeze` in the repository history.
Step 12 restores the real reform years with a script the author runs from the private
folder; it writes the real event tables to `data/reference/` and sets the blinding
status to `REAL`. The frozen code is then run once on the real tables (step 13).

Any code change after the freeze is logged as a post-freeze correction with the date
and the diagnosis behind the change. No post-freeze correction may alter an
estimation rule for any model that can be estimated before the correction.

### 15.5 Manifest and staging

Every file used is listed in `data/manifest/download_manifest.csv` with the dataset
name, school year, source address, file name, acquisition method, notes, SHA-256
checksum and download time. The download script (step 2) reads the manifest, fetches
each file with an address, and verifies every checksum on every run. A row with no
address whose file is present in the archive is checksummed and verified like any
other.

`data/stage.txt` controls which manifest rows may be downloaded. It reads 1 until the
registration is filed.

- Stage 1: the 2010-2013 federal assessment files (participation from 2013) and their
  documentation; the CCD files for 2007 through 2013; the SAIPE 2009 estimates; F-33
  fiscal years 2010-2013; and the reference inputs.
- Stage 2, set after the registration is confirmed: the full-window federal assessment
  and participation files; the graduation files; the CCD and F-33 files through 2024,
  including the CCD school characteristics files; the CPI series; the SEDA files; and
  the report-card files, one manifest row per report-card state-year.

While the stage is 1, no federal outcome file for a year after 2013, no graduation
file, no SEDA file and no report-card file is downloaded, opened or inspected. The
download script enforces the gate.

### 15.6 Acquisition methods

Each file is obtained in one of four ways, and the manifest records the way used:

1. Fixed address: fetched by the download script.
2. Interactive reporting tool: exported through a browser following documented steps
   recorded in the manifest notes, saved under the study naming convention and
   checksummed.
3. Site refusing scripted requests: downloaded through a browser and moved into the
   archive. The download script verifies the checksum but cannot fetch the file.
4. On request: supplied by a state through its data request process, for example
   where a state's public file lacks district-by-race rows; archived and checksummed
   as in method 3, with the request recorded in the notes.

The manifest README states that a reader working from an empty archive must fetch the
files of methods 2 to 4 by hand from the address or steps recorded in each row; the
recorded checksums fix the bytes.

Each report-card file is opened after download only far enough to confirm the
presence of district rows with the Black, Hispanic and White groups for the high
school test. No result is read at the confirmation step.

### 15.7 Archiving and deposits

Each file is archived with its checksum at the time of download. The stage 1 files are
attached to the OSF registration (Section 15.1). OSF no longer hosts data deposits, so
the remaining public files are deposited on Zenodo in two records, each with its own
DOI: the stage 2 federal files (including both copies of the 2019 assessment files and
the early CCD files) and the state report-card files. Each record holds a checksum
file and a copy of the manifest. Report-card files obtained through a browser or a
reporting tool are deposited with their checksums. The analysis outputs are deposited
in a third Zenodo record. The repository is archived on Zenodo at the freeze tag and
at the final release, each archive with its own DOI. Every Zenodo DOI is linked from
the OSF registration, and each Zenodo record links back to the registration.

The SEDA files and every district-level file derived from SEDA are never deposited, in
full or in part, because the data use agreement prohibits redistribution. Model objects
and randomization draws that hold district-level SEDA values stay in the working
archive under `data/derived`; every output file of the repository and the deposits carries estimates and
counts only. The manifest records the SEDA file addresses and checksums, and the
repository README states the terms under which a reader obtains the files from the
Stanford Digital Repository.

### 15.8 Data storage and security

All data are published aggregates with no personal identifiers. On the author's
workstation, data are held in two places:

- the working archive: the `data/raw` and `data/derived` folders of the repository's
  working copy, which are excluded from version control (`.gitignore`) and never
  pushed. `data/raw` holds every downloaded file; `data/derived` holds the derived
  files, the model objects and the randomization draws;
- a private folder outside the working copy, which holds the event files, the real
  event tables and the blinding seed. It is read only when the event tables
  are built (step 1) and when the real reform years are restored (step 12), so that no
  analysis step reads the real assignment before the freeze.

The public copies are those of Section 15.7. The SEDA files are stored only in the
working archive and are excluded from every deposit. The public repository holds code,
reference tables and documentation only; no data file is committed or pushed. Repository history is public, so
each change to code, reference tables, logs and reports is dated and attributable. The
checksums recorded in the manifest are verified on every run, so any alteration of an
archived file is apparent. No data are held on portable media or in shared cloud
folders.

### 15.9 Process

The process is a sequence of R scripts. Each run writes a log with a run identifier,
settings and timings, and each script writes to its own output folder.

- Steps 0-2 prepare the inputs. Step 0 installs the packages from the lockfile. Step 1
  builds the event tables (Section 15.3). Step 2 downloads and verifies the manifest
  rows allowed by the stage gate.
- Steps 3-4 build the analysis data. Step 3 applies the sample rules and writes the
  district-year sample file with the cell statuses, participation flags, poverty
  quintiles, CEP indicator and the retained flags for the three event sets. Step 4
  computes the federal high school and graduation gaps.
- Steps 5-8 estimate. Step 5 fits the primary Callaway–Sant'Anna models for each
  family, gap, event set, panel rule and weighting. Step 6 fits the secondary
  estimators. Step 7 computes the wild cluster bootstrap, the randomization inference,
  the Romano–Wolf adjustment and the bound sets. Step 8 runs the power simulation and
  is locked to stage 1.
- Steps 9-11 add what the federal files do not carry. Step 9 builds the SEDA outcomes.
  Step 10 appends the report-card outcomes to the high school panel. Step 11 runs the
  continuous-treatment estimator.
- Steps 12-13 complete the run. Step 12 restores the real reform years after the code
  freeze. Step 13 runs steps 3 through 7 and 9 through 11 on the full windows with every
  robustness variant and split, the Lee bracket, the dose scaling and the report
  builder, which assembles the registered tables and figures from the saved model
  outputs.

### 15.10 Analytic environment and reproducibility

All analysis code is written in R and kept in a version-controlled Git repository
(https://github.com/Scully4441/finance-reform-study), released under the MIT license.
The license covers the code only and grants no access to data. The repository holds
the process scripts, shared functions, reference tables, download manifest, this
document, the decision log, the deviations log and the reports.

A renv lockfile pins R 4.6.1 and every package version. The versions recorded at
filing are:

| Package | Version | Source |
|---|---|---|
| did | 2.5.1 | CRAN |
| BMisc | 1.4.10 | CRAN (dependency of did) |
| fixest | 0.14.2 | CRAN |
| didimputation | 0.5.1 | CRAN |
| synthdid | 0.0.9 | GitHub synth-inference/synthdid, commit 70c1ce3eac58e28c30b67435ca377bb48baa9b8a |
| HonestDiD | 0.2.8 | CRAN |
| DIDmultiplegtDYN | 2.4.0 | CRAN |
| polars | 1.9000.9000.9000 | rpolars.r-universe.dev, build at commit 08ba07909a0b4968eaa3d77103c9585849a6f35d |
| readxl | 1.5.0.1 | CRAN |
| readxlsb | 0.1.61 | GitHub velofrog/readxlsb, commit 644ef7aefd4b1342d6754db7bab3dc9310137da7 |
| data.table | 1.18.6.1 | CRAN |
| future | 1.75.0 | CRAN |
| furrr | 0.4.0 | CRAN |
| renv | 1.2.4 | CRAN |
| testthat | 3.3.2 | CRAN |

`fwildclusterboot` and `wildrwolf` are not used (Section 7.5). `polars` is not on CRAN
and its r-universe version number does not change between builds, so it is pinned by
commit, with the repository recorded in the lockfile. Package versions are also
written to `outputs/package_versions.csv` by step 0.

A Dockerfile builds a container from `rocker/r-ver:4.6.1` and restores the lockfile.
The container holds the code and the lockfile only; data are mounted at run time. The
README gives the build and run commands and the system requirements. The workstation
runs Windows 11 with a 14-core processor and 32 GB of memory. Every design decision,
sample rule and analytic choice is made by the author and recorded in the logs.

A test suite written with `testthat` checks the reference tables (row counts, coding
rules, source-label formats, author checks), the manifest and stage gate, the sample
rules on synthetic panels, the outcome functions, the model outputs, the report and
the container. Tests check rules of the design, not properties of particular files.
The suite is run before every commit.

## 16. Reporting

### 16.1 Order

The order of the report is fixed here so that the form of the presentation cannot
respond to the results. The families are reported in this order: high school
achievement gaps (primary), graduation gaps (secondary), SEDA gaps (supplementary).
The continuous-treatment estimates of all families come last. Within each family the
gaps are reported in the order (a), (b), (c).

For each gap:

1. The five bound sets, one for each M̄ (0, 0.5, 1, 1.5, 2), with the bound set at
   M̄ = 1 marked, the unadjusted confidence set, the largest M̄ at which the set
   excludes zero, and the event-time block where the block rule applies. The bound
   sets come first in either power classification; where the study is registered as a
   bounds analysis (Section 14), they are its primary result.
2. The event study: the estimate at each event time from -5 through +8 in a plot and a
   table, each with its bootstrap interval and the number of cohorts, treated states
   and units behind it. A coefficient resting on a single treated state carries a
   marker.
3. The overall post-reform average with the bootstrap interval, the bootstrap p-value,
   the randomization p-value, the Romano–Wolf adjusted p-value, and the number of
   cohorts and treated states behind each event time it averages. A model with fewer
   than five treated states carries the marker of Section 8.2.
4. The growth contrast G of Section 12.3 with its interval, adjusted p-value, bound
   sets and the cohorts behind each window.
5. The dose-scaled estimate with the revenue first stage, the revenue exclusions, and
   the exclusion restriction stated as an assumption.
6. The Lee bracket (high school gaps (b) and (c)).
7. The estimator agreement table: the overall average of the primary estimator, the
   four secondary estimators and the two-way fixed effects comparison row, with the
   event times each covers.
8. The weighted comparison.
9. The two narrow event sets.
10. The sample variants, then the timing variants.
11. The source, coverage and span splits that apply to the family.
12. The thin-cohort appendix reference and the treated-unit counts.

Each family closes with a table of the hypothesis verdicts under Section 12, giving
for each hypothesis and gap the verdict, the bound set at M̄ = 1 (for H5, the
dose-scaled interval) and which parts of the agreement criterion hold.

The counts of Section 5.3, the cohorts removed by the floor, the units left out of
each estimator and the revenue exclusions are reported with the models they concern.

### 16.2 Wording rules

- The answer to the research question is stated for each gap as an interval in SD
  units, the bound set at M̄ = 1, and as an interval per $1,000 of per-pupil revenue,
  the dose-scaled interval or its unbounded status.
- No result is described as a significance claim or as statistically significant.
- A point estimate is described as robust only when the agreement criterion holds. A
  point estimate failing any part of it is reported as a quantity and not as a
  finding.
- Results of the continuous-treatment estimator are labelled exploratory.

### 16.3 Models that cannot be estimated

Where a model cannot be estimated (for example a balanced panel with no estimable
cohort), the report shows the model's recorded status in place of its numbers,
wherever its estimate, bootstrap, randomization or bound-set row is absent. Every cell
whose row exists is shown unchanged. The run log counts and lists the models shown
with a status, so a reader can see which models exist.

## 17. Limitations

- State assessments differ in content. The outcome measures relative position within
  a state-year test and is not a cross-state comparison of achievement levels.
- The equal-variance normality assumption behind V is maintained and not tested. V is
  invariant to the cut only under that assumption, and cut-score changes on an
  unchanged test are not flagged.
- Gap (a) averages district probit scores, each relative to its own district's score
  distribution. It is a gap in a common unit only where districts' standard
  deviations are similar.
- A range midpoint is measurement error in the outcome, bounded at half the range
  width. It is not classical error, since it depends on where the true rate falls
  within its band and is larger in probit units near the tails, so the argument that
  it does not bias the estimate is approximate; the exact-only and five-point samples
  are the check.
- The participation rule cannot be applied to 2010-2012 or to report-card states that
  print no participation rate. Test participation was a federal requirement in the
  early years and the opt-out movement had not yet begun, so the retained early
  state-years are unlikely to fail the rule.
- The sample window begins in 2010 (2009 for SEDA). Reforms before the window are
  outside the design, and states reforming in the five years before it are excluded.
- Treatment is binary at the state level in the event-based design. Within-state
  variation in reform intensity enters only through the dose-scaled estimate and the
  continuous-treatment estimator, which rests on a different identifying assumption.
- Post-2011 reforms that changed parameters of an existing formula without replacing it
  are coded as untreated. This can attenuate the estimate but cannot inflate it. The
  narrow event sets show how much the estimate depends on the post-2011 coding.
- Few states are treated. The bootstrap's accuracy with so few treated clusters is
  uncertain, and models with fewer than five treated states are marked and read with
  the randomization p-value beside the interval.
- Late event times rest on few states, because only the early cohorts reach them. The
  overall average weights every event time equally, so it gives those states more
  influence than their number suggests.
- The reform years are public and set r1 has only one permuted arrangement, so the
  blinding protects against estimates on the real assignment during development but
  not against knowledge of the reform years.
- Some public state documents consulted for assessment histories while the
  test-replacement table was verified also contained published achievement results
  (New Mexico proficiency workbooks for several years from 2011 to 2021, an Illinois
  PARCC performance report for 2015-16, the achievement sections of federal
  Consolidated State Performance Reports for about fifteen states, and several state
  results releases), and statewide rates were briefly displayed on the West Virginia
  ZoomWV dashboard during the coverage review. No value from them was recorded or
  used. Every rule here that depends on outcome data was fixed before these documents
  were opened, except the test-replacement codings, which follow the written rule from
  assessment-history sources. The decision log records the disclosure.
- The high school report-card years cover only the states that publish district-level
  results by race, on tests that differ across states and, in some states, with
  definitions that differ from the federal files. Gaps are comparable across years
  within a state, not across states.
- SEDA measures grades 3 through 8, not the high school outcome the question names.
  Its results speak to the grades that feed high school. Its 2022-2025 estimates come
  from public suppressed data rather than the restricted-use counts behind 2009-2019.
- The treated-unit floor makes the covariate-adjusted models of gaps (b) and (c)
  depend on the larger cohorts. The smaller cohorts are reported without adjustment.
- Event-time coefficients and the two windows of the growth contrast rest on different
  cohorts, because the windows end in 2025 and some years are missing.
- The dose-scaled estimate uses 2010-2024, the years with F-33 revenue, in both
  stages, so the 2025 cohort has no post-reform year in it.
- The Lee bracket uses a three-year lag from grade 9 membership for every state, and
  trims district-years rather than students, so it is an approximation to Lee's
  bounds.
- The graduation gap is a gap in a binary outcome in probit units, not a
  scale-invariant test-score gap, and has no power calculation.
- The unbalanced panel lets composition change between the periods each group-time
  effect compares; the balanced panel is the check where it can be formed.
