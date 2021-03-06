--query to produce MEDDRA PT --> SNOMED mapping
--to be used for mapping SPLICER data into LAERTES
--also to be used to identify synonyms to label tagging


--objective:  map as many MEDDRA PTs to SNOMED,  but don't do it as sacrifice of not having a decent mapping

--create table #meddra_to_snomed with (location=user_db, distribution=replicate)
--as
--first, find all MedDRA PTs that have verbatim string match to SNOMED
--second, find MedDRA LLTs with verbatim strnig match, get the PT and map to SNOMED
--third, find synonyms of SNOMED concept with verbatim string match to PT
--fourth, find synonyms of SNOMED concept with verbatim match to LLT
--fifth, use relationships to choose 1 SNOMED concept which has direct relationship to MedDRA and is closest in string length

COPY (
WITH CTE_EXACT_PT AS (
select meddrapt.concept_id as meddra_concept_id, meddrapt.concept_name as meddra_concept_name, min(snomed.concept_id) as snomed_concept_id
from (
select concept_id, concept_name
from concept
where vocabulary_id = 'MedDRA'
and concept_class_id = 'PT'
) meddrapt
inner join (
select concept_id, concept_name
from concept
where vocabulary_id = 'SNOMED'
and invalid_reason is null
) snomed
on meddrapt.concept_name = snomed.concept_name
group by meddrapt.concept_id, meddrapt.concept_name
),
CTE_EXACT_LLT AS (
select meddrapt.concept_id as meddra_concept_id, meddrapt.concept_name as meddra_concept_name, min(snomed.concept_id) as snomed_concept_id
from (
select concept_id, concept_name
from concept c1
left join CTE_EXACT_PT nc1
on c1.concept_id = nc1.meddra_concept_id
where vocabulary_id = 'MedDRA'
and concept_class_id = 'PT'
and nc1.meddra_concept_id is null
) meddrapt
inner join concept_relationship cr1
on meddrapt.concept_id = cr1.concept_id_1
and cr1.invalid_reason is null
inner join (
select concept_id, concept_name
from concept
where vocabulary_id = 'MedDRA'
and concept_class_id = 'LLT'
) meddrallt
on cr1.concept_id_2 = meddrallt.concept_id
inner join (
select concept_id, concept_name
from concept
where vocabulary_id = 'SNOMED'
and invalid_reason is null
) snomed
on meddrallt.concept_name = snomed.concept_name
group by meddrapt.concept_id, meddrapt.concept_name
),
CTE_PT_SYNONYM_SNOMED AS (
select meddrapt.concept_id as meddra_concept_id, meddrapt.concept_name as meddra_concept_name, min(snomed.concept_id) as snomed_concept_id
from  (
select concept_id, concept_name
from concept c1
left join CTE_EXACT_PT nc1
on c1.concept_id = nc1.meddra_concept_id
left join CTE_EXACT_LLT nc2
on c1.concept_id = nc2.meddra_concept_id
where vocabulary_id = 'MedDRA'
and concept_class_id = 'PT'
and nc1.meddra_concept_id is null
and nc2.meddra_concept_id is null
) meddrapt
inner join (
select c1.concept_id, cs1.concept_synonym_name as concept_name
from concept c1
inner join concept_synonym cs1
on c1.concept_id = cs1.concept_id
where c1.vocabulary_id = 'SNOMED'
and c1.invalid_reason is null
) snomed
on meddrapt.concept_name = snomed.concept_name
group by meddrapt.concept_id, meddrapt.concept_name
),
CTE_LLT_SYNONYM_SNOMED AS (
select meddrapt.concept_id as meddra_concept_id, meddrapt.concept_name as meddra_concept_name, min(snomed.concept_id) as snomed_concept_id
from (
select concept_id, concept_name
from concept c1
left join CTE_EXACT_PT nc1
on c1.concept_id = nc1.meddra_concept_id
left join CTE_EXACT_LLT nc2
on c1.concept_id = nc2.meddra_concept_id
left join CTE_PT_SYNONYM_SNOMED nc3
on c1.concept_id = nc3.meddra_concept_id
where vocabulary_id = 'MedDRA'
and concept_class_id = 'PT'
and nc1.meddra_concept_id is null
and nc2.meddra_concept_id is null
and nc3.meddra_concept_id is null
) meddrapt
inner join concept_relationship cr1
on meddrapt.concept_id = cr1.concept_id_1
and cr1.invalid_reason is null
inner join (
select concept_id, concept_name
from concept
where vocabulary_id = 'MedDRA'
and concept_class_id = 'LLT'
) meddrallt
on cr1.concept_id_2 = meddrallt.concept_id
inner join (
select c1.concept_id, cs1.concept_synonym_name as concept_name
from concept c1
inner join concept_synonym cs1
on c1.concept_id = cs1.concept_id
where c1.vocabulary_id = 'SNOMED'
and c1.invalid_reason is null
) snomed
on meddrallt.concept_name = snomed.concept_name
group by meddrapt.concept_id, meddrapt.concept_name
),
CTE_RELATIONSHIP AS (
select meddra_concept_id, meddra_concept_name, snomed_concept_id
from (
select meddrapt.concept_id as meddra_concept_id, meddrapt.concept_name as meddra_concept_name, snomed.concept_id as snomed_concept_id,
row_number() over (partition by meddrapt.concept_id order by ca1.min_levels_of_separation, abs(length(meddrapt.concept_name) - length(snomed.concept_name)), ca1.max_levels_of_separation, snomed.concept_id) as row_num
from  (
select concept_id, concept_name
from concept c1
left join CTE_EXACT_PT nc1
on c1.concept_id = nc1.meddra_concept_id
left join CTE_EXACT_LLT nc2
on c1.concept_id = nc2.meddra_concept_id
left join CTE_PT_SYNONYM_SNOMED nc3
on c1.concept_id = nc3.meddra_concept_id
left join CTE_LLT_SYNONYM_SNOMED nc4
on c1.concept_id = nc4.meddra_concept_id
where vocabulary_id = 'MedDRA'
and concept_class_id = 'PT'
and nc1.meddra_concept_id is null
and nc2.meddra_concept_id is null
and nc3.meddra_concept_id is null
and nc4.meddra_concept_id is null
) meddrapt
inner join concept_ancestor ca1
on meddrapt.concept_id = ca1.ancestor_concept_id
inner join (
select c1.concept_id, c1.concept_name
from concept c1
where c1.vocabulary_id = 'SNOMED'
and c1.concept_class_id = 'Clinical finding'
and c1.invalid_reason is null
) snomed
on ca1.descendant_concept_id = snomed.concept_id
where ca1.min_levels_of_separation = 0
and abs(length(meddrapt.concept_name) - length(snomed.concept_name)) < 10
) t1
where row_num = 1
)
SELECT all_maps.meddra_concept_id, all_maps.meddra_concept_name, all_maps.snomed_concept_id, c1.concept_name as snomed_concept_name
FROM (
SELECT * FROM CTE_EXACT_PT
UNION
SELECT * FROM CTE_EXACT_LLT
UNION
SELECT * FROM CTE_PT_SYNONYM_SNOMED
UNION
SELECT * FROM CTE_LLT_SYNONYM_SNOMED
UNION
SELECT * FROM CTE_RELATIONSHIP
) all_maps
inner join concept c1
on all_maps.snomed_concept_id = c1.concept_id
)
TO '/tmp/LU_MEDDRAPT_TO_SNOMED.txt' WITH (DELIMITER '	', FORMAT CSV, HEADER TRUE);

