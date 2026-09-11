# Deviations from the registered design

Log every departure from docs/design.md here with the date and the reason
(design document, Section 11). Leave the table empty until a deviation occurs.

| Date | Section | Deviation | Reason |
|---|---|---|---|
| 2026-09-11 | 5 (rule 3), 9 | Percent proficient reported as a range no wider than 10 percentage points enters at the range midpoint. Wider ranges and suppressed cells stay missing, and the 30-student floor stays. Width and midpoint come from the printed endpoints, with one-sided labels closed at 0 and 100. Robustness samples: exact values only (the rule as written) and ranges of 5 points or less. This replaces "reported as an exact value (not a range) ... Range-reported cells are treated as missing and are not imputed" in rule 3 and "No imputation" in the Section 9 table. | Author decision, 2026-09-11. In the stage-1 files EDFacts reports high school percent proficient as a whole number only for groups of more than 300 tested students. Groups of 31-60 get 10-point ranges and groups of 61-300 get 5-point ranges (`outputs/03_sample/range_widths_by_bracket.csv`). |
| 2026-09-11 | 5 | Districts that pass rules 1 and 2 but have no SAIPE 2009 child-poverty rate are dropped for all three gaps. Section 5 has no such rule. | Author decision, 2026-09-11. |
