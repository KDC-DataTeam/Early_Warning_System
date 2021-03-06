
--only run this step if the table exists
--figure out the syntax in T-SQL for "If Exists"

IF OBJECT_ID('CUSTOM.CUSTOM_EARLY_WARNING_ATTENDANCE', 'U') IS NOT NULL
	DELETE FROM CUSTOM.CUSTOM_EARLY_WARNING_ATTENDANCE

--DROP TABLE CUSTOM.CUSTOM_EARLY_WARNING_ATTENDANCE;
ELSE 
	CREATE TABLE CUSTOM.CUSTOM_EARLY_WARNING_ATTENDANCE (
	STUDENT_NUMBER INT,
	STUDENTID INT,
	STUDENTKEY INT,
	SYSTEMSTUDENTID VARCHAR(25),
	TERMKEY INT,
	ABSENCES INT,
	MEMBERSHIP INT,
	UNEXCUSED_ABSENCES INT,
	TARDIES INT,
	LASTUPDATED DATETIME);

IF (SELECT OBJECT_ID
	FROM sys.indexes 
	WHERE name='EW_ATT' AND object_id = OBJECT_ID('CUSTOM.CUSTOM_EARLY_WARNING_ATTENDANCE')) IS NULL
	CREATE INDEX EW_ATT ON CUSTOM.CUSTOM_EARLY_WARNING_ATTENDANCE (STUDENT_NUMBER,TERMKEY);

INSERT INTO CUSTOM.CUSTOM_EARLY_WARNING_ATTENDANCE --(STUDENT_NUMBER,STUDENTID,STUDENTKEY,SYSTEMSTUDENTID,TERMKEY,ABSENCES,MEMBERSHIP,UNEXCUSED_ABSENCES,TARDIES)
SELECT
S.STUDENT_NUMBER AS STUDENT_NUMBER,
S.ID AS STUDENTID,
DS.STUDENTKEY,
DS.SYSTEMSTUDENTID,
COALESCE(CAST(CAST(T.ID AS VARCHAR) + CAST(E.SCHOOLID AS VARCHAR) AS INT),-1) AS TERMKEY, --CREATE TERMKEY BY CONCATENATING TERMID AND A.SCHOOLID AND CASTING AS INT
SUM(CASE WHEN AC.PRESENCE_STATUS_CD = 'Absent' THEN 1 ELSE 0 END) ABSENCES,
SUM(1) MEMBERSHIP,
SUM(CASE WHEN DESCRIPTION IN ('Absent','Absent Unexcused','Medical Unexcused','Released Early Absent','Tardy Absent') THEN 1 ELSE 0 END) UNEXCUSED_ABSENCES, --there is ap probably a better value to pull unexcused absences from so they don't need be hardcoded
SUM(CASE WHEN DESCRIPTION LIKE 'Tardy%' AND DESCRIPTION NOT LIKE '%Absent%' AND DESCRIPTION != 'Tardy To Class' THEN 1 ELSE 0 END) TARDIES, --find a better field to pull tardies from instead of hard coding
GETDATE() AS LASTUPDATE
FROM POWERSCHOOL.POWERSCHOOL_STUDENTS S
JOIN (SELECT SCHOOLID, ID AS STUDENTID, ENTRYDATE, EXITDATE, GRADE_LEVEL FROM POWERSCHOOL.POWERSCHOOL_STUDENTS S --get all student enrollemts ever entered
		UNION
	  SELECT SCHOOLID, STUDENTID, ENTRYDATE, EXITDATE, GRADE_LEVEL FROM POWERSCHOOL.POWERSCHOOL_REENROLLMENTS R) E ON E.STUDENTID = S.ID
JOIN [custom].[custom_StudentBridge] SB ON SB.STUDENT_NUMBER = S.STUDENT_NUMBER
JOIN DW.DW_DIMSTUDENT DS ON DS.SYSTEMSTUDENTID = SB.SYSTEMSTUDENTID
JOIN POWERSCHOOL.POWERSCHOOL_CALENDAR_DAY CD ON CD.SCHOOLID = E.SCHOOLID AND CD.DATE_VALUE BETWEEN E.ENTRYDATE AND E.EXITDATE AND CD.DATE_VALUE <= GETDATE()
LEFT JOIN [Cust1220].[powerschool].[powerschool_ATTENDANCE] A ON A.SCHOOLID = E.SCHOOLID AND A.STUDENTID = E.STUDENTID AND A.ATT_DATE = CD.DATE_VALUE
LEFT JOIN [powerschool].[powerschool_ATTENDANCE_CODE] AC ON AC.ID = ATTENDANCE_CODEID
LEFT JOIN [powerschool].[powerschool_TERMS] T ON CD.DATE_VALUE BETWEEN T.FIRSTDAY AND T.LASTDAY AND T.SCHOOLID = E.SCHOOLID
WHERE CD.INSESSION = 1 
	AND (ATT_MODE_CODE = 'ATT_ModeDaily' OR ATT_MODE_CODE IS NULL)
	AND E.SCHOOLID != 999999
GROUP BY
	S.STUDENT_NUMBER,
	T.ID,
	T.YEARID,
	E.SCHOOLID,
	S.ID,
	DS.STUDENTKEY,
	DS.SYSTEMSTUDENTID
