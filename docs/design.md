# **Study Design: The Effect of School Finance Reforms on Achievement Disparities in US Secondary Schools**

## **1. Research question and estimand**

**Question.** To what degree do school finance reforms affect
achievement disparities in secondary US schools?

**Estimand.** An estimand is the specific quantity the study is used to
measure. The estimand definition is stated before any data are analyzed.
**The average effect of a state school finance reform on within-state
achievement gaps measured in high school (grades 9–12) state assessments
is the estimand for this study.** The effect is expressed in pooled
student-level standard deviation units of the test (defined in Section
6). It is estimated as a function of years since reform. A dose-scaled
version expresses the same effect per \$1,000 of reform-induced change
in per-pupil revenue.

**Magnitude and time.** The study question asks how **much** reforms
change disparities. That requires a number in interpretable units rather
than a yes-or-no verdict. Effects of finance reforms may also build over
several years as funding flows through budgets and staffing. The
estimand in this study therefore covers the effect in each year after
reform rather than a single average.

**Scope boundaries.** The study estimates the magnitude and time path of
the average effect. It does not compare reform types. It does not
estimate mechanisms. It does not estimate effects on levels of
achievement except where a level is an input to a gap.

## **2. Foundational logic of the design**

**The core problem.** We cannot observe what achievement gaps in a
reforming state would have been without the reform. A causal estimate
requires a credible stand-in for that missing counterfactual. This study
uses other states that did not reform (or had not yet reformed) as the
stand-in.

**Difference-in-differences** compares the change in gaps over time in
reforming states to the change over the same period in non-reforming
states. Subtracting the second change from the first removes anything
that affected all states alike (national test trends, recessions,
federal policy). What remains is attributed to the reform.
Difference-in-differences is executed with a structural assumption:
absent the reform, gaps in reforming and non-reforming states would have
moved in parallel. This is called the parallel-trends assumption. It
cannot be proven. It can be made more plausible by showing that gaps
moved in parallel in the years before reform, and it can be
stress-tested by asking how much the conclusion would change if the
trends were somewhat non-parallel (Section 8).

**Staggered adoption.** Different states reform in different years. This
is called staggered adoption. It creates a known technical problem: the
conventional regression approach (two-way fixed effects) implicitly uses
already-reformed states as controls for later-reforming states. If
effects grow over time this contaminates the comparison and can produce
estimates with the wrong sign. Section 7 uses estimators built
specifically to avoid this.

**Event study.** An event study lines up every reforming state on a
common clock where year 0 is the reform year. It then estimates the
effect separately for each year before and after. Coefficients before
year 0 should be near zero if parallel trends holds. Coefficients after
year 0 trace the effect over time.

## **3. Fixed definitions (set before any data are examined)**

Every definition below is fixed in writing before the outcome data are
opened. This is the mechanism by which the study avoids subjective
judgment calls: each decision is converted into a rule that a computer
can apply identically to every case.

| **Term**              | **Operational definition**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | **Source of definition**                    |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------|
| Secondary school      | Grades 9–12 as tested by the state high school assessment reported to EDFacts                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | NCES grade-span convention                  |
| School finance reform | An event on the Lafortune, Rothstein, and Schanzenbach (2018) list for 1990 through 2011. After December 31, 2011 two written rules apply. Court rule: a ruling that held the state's K–12 finance system or its formula for state operating aid unconstitutional and that became final because it was not appealed or was affirmed on appeal. Rulings later vacated, reversed, or disavowed by the issuing court do not count. Statute rule: a statute that enacted a new primary formula for distributing state operating aid to districts and repealed or superseded the formula in force. Statutes that amended parameters of an existing formula or added supplemental programs do not count. A formula counts as new when its architecture changes, not when components or weights within the existing architecture are revised. A statute that applies a new formula only to funding above a locked-in base does not supersede the formula in force. Candidates come from the Education Law Center "SchoolFunding.info" case database for rulings and from Education Commission of the States and National Conference of State Legislatures finance records for statutes. Each post-2011 event is coded from the ruling or statute text before any outcome file is downloaded. The coding table with every candidate considered, the decision, and the citation is deposited with the registration. | Prior published lists; no researcher coding |
| Reform year           | The school year in which the listed ruling or enactment occurred. A spring ruling is assigned to the following school year.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Rule applied uniformly                      |
| Achievement disparity | Three pre-specified gap measures, each in pooled SD units (Section 6): (a) between-district gap by child poverty quintile, (b) within-district Black–White gap, (c) within-district Hispanic–White gap                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Pre-registered                              |
| Analysis window       | School years 2009–10 through the newest EDFacts release available on the registration date (Section 11). The end year is entered in the registration. 2019–20 is excluded.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Data availability                           |

**Why the reform list is borrowed through 2011 and rule-bound after.**
Deciding what counts as a reform is the largest point of discretion in
this literature. Legislatures adjust funding formulas nearly every year,
so what counts as a fully fledged reform is in question. Using lists
published by other peer reviewed research moves that judgment outside
the study and into the documented record. After 2011 no such list
exists. Events after 2011 are therefore coded under two written rules.
The court rule turns on a checkable fact: whether the ruling became
final. The statute rule turns on whether a new primary formula was
enacted. Parameter changes to an existing formula are left out because
deciding which of them are large enough would require the magnitude
judgment this design avoids. Both rules are applied and the coding table
is deposited before any outcome file is downloaded, so the coding cannot
respond to results. Two pre-registered robustness checks bound the
coding: one restricts events to the published list plus final state
supreme court rulings, and one uses court rulings only. The cost is that
post-2011 parameter reforms are coded as untreated. That
misclassification can only push the estimate toward zero because a
reformed state coded as untreated carries any real reform effect into
the comparison group and narrows the very gap the estimate measures. I
accept a possibly understated effect in exchange for a treatment
variable fixed before the data are seen.

**Why two forms of disparity.** "Achievement disparity" has two common
meanings in this literature. One is the gap between poor and affluent
districts. The other is the gap between student groups inside the same
district. Finance reforms typically move money between districts, so the
first form is the most direct target. The second form captures whether
the money reaches the students within districts who are behind. Both are
registered so the study cannot select between them after seeing results.

## **4. Data sources (all free and public)**

| **Data**                                                                                                                                                 | **Use**                                                          | **Location**                                |
|----------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------|---------------------------------------------|
| EDFacts assessment files (school and LEA level, by subgroup, HS grade band, math and reading/language arts)                                              | Outcome construction                                             | data.ed.gov                                 |
| EDFacts assessment participation files                                                                                                                   | Sample validity checks                                           | data.ed.gov                                 |
| NCES Common Core of Data (CCD): membership by grade, race, FRL; district directory and agency type                                                       | Denominators, composition, district identity                     | nces.ed.gov/ccd                             |
| Census SAIPE school-district child poverty estimates                                                                                                     | Between-district poverty quintiles independent of school records | census.gov/programs-surveys/saipe           |
| Census F-33 Annual Survey of School System Finances                                                                                                      | Per-pupil revenue by source; dose variable                       | census.gov/programs-surveys/school-finances |
| Lafortune–Rothstein–Schanzenbach (2018) online appendix                                                                                                  | Reform event list                                                | AEJ: Applied article site                   |
| Education Law Center SchoolFunding.info                                                                                                                  | Court events after 2011                                          | schoolfunding.info                          |
| State statutes and official legislative summaries; Education Commission of the States and National Conference of State Legislatures K–12 finance records | Statute events after 2011                                        | state legislature sites; ecs.org; ncsl.org  |
| USDA Community Eligibility Provision participation lists                                                                                                 | Flag FRL measurement breaks                                      | fns.usda.gov                                |
| State assessment histories (state education agency documentation and EDFacts metadata)                                                                   | Test-replacement flag (Section 5)                                | State education agency sites; data.ed.gov   |

**What these sources are.** EDFacts is the federal system through which
every state reports school-level test results required under federal
law. It is the only national source of high school assessment results by
subgroup. The Common Core of Data is the federal directory and
enrollment census of public schools. SAIPE is the Census Bureau's annual
estimate of child poverty for each school district boundary. F-33 is the
Census Bureau's annual survey of school district revenues and spending.

**Archiving.** Each release is archived with a checksum and a
DOI-bearing deposit on OSF at the time of download. A copy is held in
the analysis repository on the author's workstation (Section 11).
Outcome files are downloaded in two stages. The 2009–10 through 2012–13
assessment files are downloaded first for the power simulation (Section
10). All later years are downloaded after the registration is filed
(Section 11). The registration date fixes the last school year in the
window (Section 3). Federal files are periodically revised. Archiving
fixes the version used so the analysis can be reproduced exactly.

## **5. Sample construction rules**

All inclusion decisions are rules applied by code. The rules are fixed
in this document before any outcome file is opened. They are registered
before any file for school years after 2012–13 is downloaded.

1.  **Unit.** Regular public school districts (CCD agency type 1 and 2).
    > Charter-only agencies, state-operated agencies, and supervisory
    > unions are excluded because their finance and enrollment are not
    > comparable. A supervisory union is an administrative body that
    > oversees several small districts without operating schools itself.

2.  **Stability.** A district is retained only if its CCD identifier is
    > present in every year of the window and it is not flagged with a
    > boundary or consolidation change. A district whose boundaries
    > change is not the same unit before and after, and comparing its
    > gaps over time would mix two different populations.

3.  **Suppression.** A district-year-subject-subgroup cell is used only
    > if the EDFacts count is reported as an exact value (not a range)
    > and the tested count is at least 30. Range-reported cells are
    > treated as missing and are not imputed. Suppression is explained
    > below.

4.  **Participation.** A district-year-subject is used only if reported
    > participation is at least 95 percent for each subgroup in the gap.
    > If many students skip the test the tested group no longer
    > represents the enrolled group. This rule excludes most of 2020–21
    > without a case-by-case decision.

5.  **Assessment regime.** A state-year is flagged if the state replaced
    > its high school assessment in that year. Cut-score changes on an
    > unchanged test are not flagged. The flag is a state-by-year table
    > built from state assessment documentation and EDFacts metadata.
    > Each entry is checked before registration. The flag enters the
    > model as a control and is used in a robustness exclusion.

6.  **Treatment timing.** States with a reform in the window are treated
    > cohorts. States with no reform in the window and no reform in the
    > five years before it are never-treated controls. States with a
    > reform in the five years before the window are excluded because
    > their pre-period cannot be observed and they may still be under
    > the influence of that earlier reform. Cohorts that reform early in
    > the window have few pre-reform years. They are retained. The
    > number of cohorts behind each event-time coefficient is reported
    > with the estimate. A robustness version drops cohorts with fewer
    > than three pre-reform years.

**What suppression is and why it matters here.** Federal privacy rules
prohibit publishing results that could reveal an individual student's
score. When a subgroup in a district has few tested students EDFacts
replaces the exact proficiency rate with a range (for example "20–39%")
or withholds it. Ranges cannot be converted into the gap measure in
Section 6. High school files are more affected than elementary files
because states test one high school grade rather than six, so counts are
smaller. The 30-student floor is stricter than the federal suppression
threshold. It is set there because a proficiency rate based on 10
students carries sampling error of roughly 0.3 standard deviations,
which is larger than any effect the study could plausibly detect. The
consequence is that the retained sample tilts toward larger districts.
Section 9 contains a check on whether reforms change which districts
clear the threshold.

## **6. Outcome construction**

**The measurement problem.** EDFacts reports the share of tested
students scoring at or above a proficiency cut. A percentage-proficient
figure is not comparable across states because each state uses its own
test and sets its own cut. It is not comparable across years within a
state either because states replace tests and move cut scores. A study
that compared raw proficiency rates across states and years would be
measuring differences in tests rather than differences in achievement.

**The solution: converting proficiency rates to standard deviation
units.** The study uses the method of Ho and Reardon (2012) and Reardon,
Kalogrides, and Ho (2021). The idea is as follows. Suppose achievement
within a group follows a normal (bell-shaped) distribution. A
proficiency cut is a vertical line through that bell. The share of
students above the line tells you where the line sits relative to the
group's mean. If 50 percent are proficient the cut sits at the mean. If
84 percent are proficient the cut sits one standard deviation below the
mean. The function that converts a share into that position is the
inverse normal function Φ⁻¹ (the "probit"). Φ⁻¹(0.50) = 0 and Φ⁻¹(0.84)
≈ 1.

For two groups A and B with proficiency shares p_A and p_B, the gap in
pooled SD units is

V = Φ⁻¹(p_A) − Φ⁻¹(p_B)

Because both groups face the same cut in the same test, the cut cancels
out of the difference. What remains is the distance between the two
group means measured in standard deviations of the test. That distance
does not depend on which test was used or where the cut was placed. It
is comparable across states and years.

**What "pooled SD units" means.** The unit is one standard deviation of
test scores. "Pooled" specifies that the standard deviation is taken
over all tested students combined rather than within one group. A gap of
0.5 means the two group means differ by half of the spread of scores
across all students in that state, year, and subject.

**The assumption.** The conversion assumes each group's latent
achievement is normally distributed with the same variance. The EDFacts
files used here report a single proficiency cut. The study does not seek
multi-level achievement data from any other source. The equal-variance
assumption is therefore maintained rather than tested. It is listed as a
limitation in Section 14.

**Gap (a): between-district poverty gap.** Within each state-year,
districts are assigned to SAIPE child-poverty quintiles using poverty
rates fixed at the 2009 value. The gap is the enrollment-weighted mean
district score (Φ⁻¹(p) per district) in the top-poverty quintile minus
that in the bottom-poverty quintile. Poverty is fixed at 2009 so that
districts cannot migrate between quintiles in response to the reform.
This measure does not depend on school-reported free-lunch status and is
therefore immune to the Community Eligibility Provision problem
described below.

**Gaps (b) and (c): within-district racial gaps.** V computed from
subgroup proficiency shares in each district-year-subject. Race
classification is stable across the window.

Math and reading/language arts are analyzed separately and then averaged
within district-year. The three gaps form one outcome family for
multiplicity adjustment (Section 8).

**Why an economically-disadvantaged gap is not primary.** The Community
Eligibility Provision (CEP) began in 2014. It allows high-poverty
schools to serve free meals to every student without collecting
individual applications. Once a school adopts CEP the count of students
flagged as economically disadvantaged changes for administrative reasons
unrelated to actual poverty. A gap built on that flag would move when
the flag changes rather than when achievement changes. The ED gap is
reported as a supplementary outcome with CEP adoption year as a control.

## **7. Identification and estimation**

**Design.** Staggered difference-in-differences event study. Treatment
is assigned at the state level. Outcomes are observed at the district
level (gaps b and c) or state level (gap a).

**Primary estimator.** Callaway and Sant'Anna (2021) group-time average
treatment effects. This estimator first computes the effect for each
reform cohort in each calendar year using only states that have not yet
reformed (or never reform) as the comparison. It then averages those
cohort-year effects into event-time coefficients for event years −5
through +8 and into one overall post-reform average. Restricting
comparisons to not-yet-treated states is what avoids the
negative-weighting problem of two-way fixed effects described in Section
2.

**Covariates.** Pre-treatment district characteristics (2009 enrollment,
SAIPE poverty, racial composition) enter through the doubly-robust
specification. "Doubly robust" means the estimator combines a model of
the outcome with a model of treatment probability and remains consistent
if either one is correct. Time-varying controls are limited to the
assessment-regime flag and CEP adoption. No post-treatment variables
enter the model. Controlling for something the reform itself may have
changed would absorb part of the effect.

**Weighting.** Gaps (b) and (c) are estimated unweighted. Each
district-year counts once because the district is the unit of analysis
(Section 5). The estimand for those gaps is therefore the effect in the
average district rather than for the average student. A version weighted
by the number of students tested in the two groups is registered as a
robustness check. A difference between the two estimates would suggest
that the effect varies with district size. Gap (a) is a state-level
outcome and does not involve this choice.

**Secondary estimators (pre-registered, reported in full).** Several
estimators exist for staggered designs and each makes slightly different
choices about weighting and comparison groups. Reporting all of them
guards against the possibility that the result depends on one choice.

- Sun and Abraham (2021) interaction-weighted estimator.

- Borusyak, Jaravel, and Spiess (2024) imputation estimator. This fits
  > the untreated trend using only untreated observations and then
  > predicts the counterfactual for each treated observation.

- Synthetic difference-in-differences (Arkhangelsky et al., 2021). This
  > reweights control states so that their pre-reform trend matches the
  > treated states, which weakens the parallel-trends requirement.

- Stacked regression with a clean-control window of five years. This
  > builds a separate dataset for each reform cohort and stacks them, so
  > that each cohort is compared only to states untreated within its own
  > window.

Agreement across estimators is a pre-registered criterion for reporting
a point estimate as robust.

**Implementation.** All estimators are run in R in the local environment
described in Section 11. Callaway–Sant'Anna uses the did package. The
weighted robustness check enters through its sampling-weight option.
Sun–Abraham and the stacked regression use fixest. The imputation
estimator uses didimputation. Synthetic difference-in-differences uses
synthdid. Package versions are recorded in the registration.

**Dose scaling.** The question asks about degree. Reforms differ in how
much money they move. The first stage regresses district per-pupil
state-plus-local revenue (F-33) on the same event-study design. Revenue
is deflated with the CPI-U all-items index averaged over July through
June of each school year. Dollars are expressed in the last year of the
window. This yields the average revenue change a reform produces. The
ratio of the gap effect to the revenue effect gives the effect per
\$1,000 and is estimated by two-stage least squares with the event-study
indicators as instruments. This scaling requires an exclusion
restriction: the reform affects gaps only through revenue and not
through other channels such as accountability rules passed alongside it.
That is stated as an assumption and not asserted as fact. The
reduced-form estimate (the direct effect of reform on gaps) remains the
primary answer to the question.

**Anticipation.** Districts may change behavior before a reform takes
effect because litigation signals what is coming. If so the year before
reform is already contaminated. Event year −1 is the reference period in
the main specification. A robustness version sets the reference at −2. A
second version dates treatment to the year of the initial lawsuit
filing.

## **8. Inference**

Inference is the process of deciding how much uncertainty surrounds an
estimate. Several features of this design make standard methods
unreliable, so each is replaced.

- **Clustering.** Districts within a state share the same reform and the
  > same test, so their errors are correlated. Standard errors are
  > clustered at the state level to account for this.

- **Few treated clusters.** Only a modest number of states reform within
  > the window. With few clusters the usual clustered standard errors
  > are too small. The wild cluster bootstrap with Webb weights is the
  > primary inference method. It rebuilds the sampling distribution by
  > resampling at the state level in a way that performs acceptably with
  > as few as six clusters. It uses 9,999 replications and the
  > fwildclusterboot R package.

- **Randomization inference.** Reform years are reassigned across states
  > 10,000 times and the estimator is rerun each time. This produces the
  > distribution of estimates one would see if reforms had no effect and
  > were randomly timed. The actual estimate is compared to that
  > distribution. This method makes no assumption about the error
  > structure at all.

- **Multiplicity.** Testing three gaps raises the chance that one
  > appears significant by luck. The Romano–Wolf step-down procedure
  > adjusts the p-values so that the probability of any false positive
  > across the family is controlled. It is run with 9,999 bootstrap
  > draws through the wildrwolf R package.

- **Pre-trend sensitivity.** Rambachan and Roth (2023) honest-DiD bounds
  > ask: if the pre-reform trends were allowed to be non-parallel by up
  > to some amount, what range of post-reform effects is still
  > consistent with the data? The reported effect is the bound set, not
  > only the point estimate. This converts the untestable
  > parallel-trends assumption into a transparent statement of how much
  > deviation the conclusion can tolerate. The relative-magnitudes
  > restriction is applied to the overall post-reform average. Bound
  > sets are reported for M̄ values of 0, 0.5, 1, 1.5, and 2. The
  > HonestDiD R package is used.

- **Seeds.** Every stochastic step derives its seed from one master
  > integer. The master integer is 130 and is recorded in the
  > registration. That covers the bootstrap draws, the randomization
  > reassignments, and the power simulation. The blinding permutation in
  > Section 11 uses a separate seed that the author holds outside the
  > repository.

## **9. Threats to validity and the built-in remedies**

| **Threat**                                                       | **Remedy**                                                                                                                                                                                       |
|------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Researcher discretion in coding reforms                          | Published list through 2011; written finality and formula-replacement rules after 2011 applied before outcome data are downloaded; coding table deposited; robustness on two narrower event sets |
| Assessment changes coincide with reforms                         | Test-replacement flag as control; robustness excluding transition years; scale-invariant outcome                                                                                                 |
| Non-normal latent distributions bias V                           | No remedy in the design. Equal-variance normality is a maintained assumption (Section 6) and a stated limitation (Section 14)                                                                    |
| Differential dropout alters the tested population in high school | CCD grade-9-to-12 enrollment ratios by subgroup; Lee (2009) trimming bounds on the gap effect                                                                                                    |
| FRL classification breaks (CEP)                                  | Poverty gap uses SAIPE; ED gap is supplementary only                                                                                                                                             |
| Composition change through migration                             | Poverty quintiles fixed at 2009; district racial composition reported as an outcome in a balance table and not used as a control                                                                 |
| Few treated clusters                                             | Wild cluster bootstrap and randomization inference                                                                                                                                               |
| Few pre-reform years for early cohorts                           | Cohort count reported for each event-time coefficient; robustness drops cohorts with fewer than three pre-reform years                                                                           |
| Negative weights under staggered adoption                        | Estimators designed for staggered timing; two-way fixed effects reported only for comparison                                                                                                     |
| A few large districts dominate the district-level estimates      | Unweighted primary estimate for gaps (b) and (c); tested-count weighted version as a registered robustness check                                                                                 |
| Suppressed cells not missing at random                           | No imputation; sample-inclusion indicator regressed on treatment as a selection check                                                                                                            |
| Data revision                                                    | Archived snapshots with checksums in the repository and on OSF                                                                                                                                   |

**The dropout threat explained.** In high school some students leave
before the tested grade. If a reform changes dropout rates differently
for two groups, the tested population changes and the gap could move
without any change in learning. Lee bounds address this. The method
trims the group whose tested share grew by the amount of the
differential change, once from the top of its distribution and once from
the bottom. The two resulting estimates bracket the true effect under
the assumption that selection is monotone. The study reports the
bracket.

**The selection check explained.** If reforms change enrollment they may
change which districts clear the 30-student floor. The study regresses
an indicator for whether a district-year is included in the sample on
the same event-study design. If inclusion responds to treatment the
estimate is reported as conditional on stable inclusion rather than as a
population effect.

## **10. Power**

Statistical power is the probability that a study detects an effect of a
given size when that effect is real. A study with low power cannot
distinguish a real effect from zero and its null results are
uninformative. Power depends on the sample size after suppression, which
cannot be known from documentation alone.

Before any outcome file for school years after 2012–13 is downloaded,
power is computed by simulation on the 2009–10 to 2012–13 assessment
files. Those files are downloaded first for this purpose (Section 4).
Placebo reform years are assigned to random states and the
Callaway–Sant'Anna pipeline is run 2,000 times in the local environment
described in Section 11. The spread of those placebo estimates reveals
how large a true effect would need to be to stand out. The minimum
detectable effect at 80 percent power and a 5 percent two-sided test is
reported in the pre-registration. If the minimum detectable effect
exceeds 0.10 SD for every primary gap the study is registered as
underpowered and proceeds only as a bounds analysis.

## **11. Pre-registration and reproducibility**

Pre-registration is the public deposit of the full analysis plan before
data are analyzed. It makes it impossible to change the plan in response
to results without the change being visible.

- Hypotheses, definitions, sample rules, estimators, and inference
  > procedures are registered on OSF after the power simulation and
  > before any outcome file for school years after 2012–13 is
  > downloaded. The registration also records the master seed, the R
  > package versions, the code license, the end year of the window, and
  > the post-2011 event coding table.

- All analysis code is written in R and kept in a version-controlled
  > repository on the author's workstation. The workstation runs Windows
  > 11 with a 14-core Intel Core i9-12900H processor and 32 GB of
  > memory. Claude Code is the development environment. Code is run
  > locally against the archived data files.

- All code is released under the MIT license with a containerized
  > environment so that any reader can rerun it. The container pins the
  > R and package versions used in the final run.

- Deviations from the registration are logged with the date and reason.

- A blinded analysis is used. The set of reforming states stays real
  > during pipeline development. Their reform years are permuted among
  > them with a seed the author holds outside the repository. The true
  > years are restored only after the code is frozen and the freeze is
  > recorded in the repository history. This prevents the analyst from
  > seeing real results while still making coding decisions.

## **12. Novelty**

Published causal work on finance reforms and achievement has relied on
NAEP grades 4 and 8 or on attainment outcomes such as graduation. To my
knowledge no study has estimated reform effects on high school
test-score gaps across states using scale-invariant gap measures. The
post-2010 reform wave (for example Illinois, Nevada, Texas, Ohio,
Maryland, and Tennessee) appears not to have been studied with a
multi-state design. Combining EDFacts high school files with the
probit-based gap method and modern staggered-adoption estimators is the
contribution.

## **13. Reporting**

The dissertation reports, for each primary gap: the event-study plot
with honest-DiD bounds and the number of cohorts behind each
coefficient, the overall post-reform average with bootstrap and
randomization p-values, the dose-scaled estimate with its assumption
stated, the Lee bounds, a table of estimator agreement, the weighted
comparison for gaps (b) and (c), and the estimates under the two
narrower event definitions. The answer to the research question is
stated as an interval in SD units and per \$1,000, not as a single
number. An interval is the honest form of the answer because the
assumptions in Sections 7 through 9 each carry uncertainty that a point
estimate would hide.

## **14. Stated limitations**

- State assessments differ in content. The outcome measures relative
  > position within a state-year test and should not be read as a
  > cross-state achievement comparison.

- The sample window begins in 2009–10. Pre-2009 reforms are outside the
  > design.

- Treatment is binary at the state level. Within-state variation in
  > reform intensity enters only through the dose-scaled estimate.

- The equal-variance normality assumption behind V is maintained and not
  > tested. The study uses single-cut proficiency data only and does not
  > seek multi-level data.

- Cut-score changes on an unchanged test are not flagged. V is invariant
  > to the cut under the normality assumption in Section 6. It is not
  > invariant if that assumption fails.

- Post-2011 reforms that changed parameters of an existing formula
  > without replacing it are coded as untreated. This can attenuate the
  > estimate toward zero but cannot inflate it. The event definition
  > changes at the end of 2011 from a published list to written rules;
  > the narrower-set robustness checks show how much the estimate
  > depends on the added codings.
