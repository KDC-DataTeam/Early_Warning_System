# Early-Warning-System
The Early Warning System (EWS) tables exist in the Custom schema. The schema was developed using the dimensional modle. There is a series of staged tables (roughly one table per domain covered in the EWS). There is a fact table that contains columns for each measure derived from the staged tables. In the fact table there is one record per student per term. Terms can take the form of quarters, semesters, trimesters, or full school years.

