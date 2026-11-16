-- Run with psql from the repo root. In pgAdmin, delete the \encoding line.
\encoding UTF8

/*
15 · Triage urgency analysis

Find the distribution of triage cases by urgency level.

For each urgency_level, show:
- the number of triage cases
- the average waiting time
- the percentage of cases that led to a hospitalization
- the distribution of referrals by department

Interpretation:
- Waiting time = service_datetime - arrival_datetime
- A case that led to a hospitalization has
  outcome = 'REFERRED_FOR_HOSPITALIZATION'
- Referral by department = referred_department_id

The urgency_description labels below are the Greek triage scale:
1 Immediate, 2 Emergent, 3 Urgent, 4 Less urgent, 5 Non-urgent.

Aliases:
tc  = triage_case
dep = department
*/

WITH level_stats AS (

    SELECT
        tc.urgency_level,

        -- Total number of triage cases at this level
        COUNT(*) AS total_triage_cases,

        -- Average waiting time.
        -- AVG ignores NULL values, so a NULL service_datetime
        -- does not affect the average.
        AVG(tc.service_datetime - tc.arrival_datetime) AS avg_waiting_time,

        -- Number of cases that led to a hospitalization
        COUNT(*) FILTER (
            WHERE tc.outcome = 'REFERRED_FOR_HOSPITALIZATION'
        ) AS hospitalized_cases,

        -- Percentage of cases that led to a hospitalization
        ROUND(
            100.0 * COUNT(*) FILTER (
                WHERE tc.outcome = 'REFERRED_FOR_HOSPITALIZATION'
            ) / COUNT(*),
            2
        ) AS hospitalization_percentage

    FROM triage_case AS tc

    GROUP BY
        tc.urgency_level
),

referral_distribution AS (

    SELECT
        tc.urgency_level,

        -- Department the case was referred to
        dep.name AS referred_department_name,

        -- Number of referrals to this department
        COUNT(*) AS referral_count

    FROM triage_case AS tc

    JOIN department AS dep
        ON dep.department_id = tc.referred_department_id

    -- Keep only the cases that led to a hospitalization,
    -- since only those count as referrals.
    WHERE tc.outcome = 'REFERRED_FOR_HOSPITALIZATION'

    GROUP BY
        tc.urgency_level,
        dep.name
)

SELECT
    -- Urgency level
    ls.urgency_level,

    CASE
        WHEN ls.urgency_level = 1 THEN 'Άμεσο'
        WHEN ls.urgency_level = 2 THEN 'Επείγον'
        WHEN ls.urgency_level = 3 THEN 'Επιτακτικό'
        WHEN ls.urgency_level = 4 THEN 'Λιγότερο επείγον'
        WHEN ls.urgency_level = 5 THEN 'Μη επείγον'
    END AS urgency_description,

    -- Overall figures per level
    ls.total_triage_cases,
    ls.avg_waiting_time,
    ls.hospitalized_cases,
    ls.hospitalization_percentage,

    -- Distribution of referrals by department
    rd.referred_department_name,
    COALESCE(rd.referral_count, 0) AS referral_count

FROM level_stats AS ls

LEFT JOIN referral_distribution AS rd
    ON rd.urgency_level = ls.urgency_level

ORDER BY
    ls.urgency_level,
    referral_count DESC,
    rd.referred_department_name;
