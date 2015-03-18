USE bodb_licensee
GO

ALTER PROCEDURE Task_CheckMisingActiveBAMember
AS
/*
Created: 
Task : Check missing Activer BA member 
	 + if missing then insert & throw alert
	 + if redundant then delete & throw alert

DB: DB052/bodb_Licensee
Original:

Revisions:
*/
BEGIN
	SET NOCOUNT ON

	--only run after 5am & even hours (1PM to 5PM (GMT+8))
	IF (DATEPART(HOUR, GETDATE()) BETWEEN 1 AND 5) OR DATEPART(HOUR, GETDATE()) / 2 <> 0
		RETURN

	DECLARE @HistoryMemberCount INT, @ActiveMeberCount INT
	SELECT @HistoryMemberCount = 0, @ActiveMeberCount = 0
	
	--history
	SELECT @HistoryMemberCount = COUNT(1)
	FROM dbo.LicenseeBAHistory WITH(NOLOCK)
	WHERE Status = 'Running'

	--active
	SELECT @ActiveMeberCount = COUNT(1)
	FROM DBTXN.CustDB.dbo.Dep_CustBAActive WITH(NOLOCK)

	--select @ActiveMeberCount as '@ActiveMeberCount', @HistoryMemberCount as '@HistoryMemberCount'
	IF @ActiveMeberCount <> @HistoryMemberCount
	BEGIN
		DECLARE @MissingBAMember TABLE (CustId INT)
		DECLARE @CustIds VARCHAR(1024), @AlertStr VARCHAR(2000)

		--For case missing
		INSERT INTO @MissingBAMember(CustId)
		SELECT ba.CustId
		FROM (
			SELECT CustId
			FROM dbo.LicenseeBAHistory WITH(NOLOCK)
			WHERE Status = 'Running'
		)ba	LEFT JOIN DBTXN.CustDB.dbo.Dep_CustBAActive at WITH(NOLOCK)	ON ba.CustID = at.CustId
		WHERE at.CustID IS NULL

		IF EXISTS (SELECT 1 FROM @MissingBAMember)
		BEGIN
			SELECT @CustIds = ''
			SELECT @CustIds = @CustIds  + CAST(CustId AS VARCHAR(20)) + ','
			FROM @MissingBAMember

			INSERT INTO DBTXN.CustDB.dbo.Dep_CustBAActive(CustId)
			SELECT CustId 
			FROM @MissingBAMember
			GROUP BY CustId

			SELECT @CustIds = SUBSTRING(@CustIds, 0, LEN(@CustIds)) --remove last comma
			SELECT @AlertStr = 'Missing one or more BA active members: ' + @CustIds + ' .The job has just inserted the missing BA active members.'
			RAISERROR (@AlertStr, 16, 1)
		END

		--For case redundant
		DECLARE @Redundant TABLE (CustId INT)
		DECLARE @CustIds1 VARCHAR(1024), @AlertStr1 VARCHAR(2000)

		INSERT INTO @Redundant(CustId)
		SELECT at.CustId
		FROM DBTXN.CustDB.dbo.Dep_CustBAActive at WITH(NOLOCK)
		LEFT JOIN (
			SELECT CustId
			FROM dbo.LicenseeBAHistory WITH(NOLOCK)
			WHERE Status = 'Running'
		)ba	ON ba.CustID = at.CustId
		WHERE ba.CustID IS NULL
		
		IF EXISTS (SELECT 1 FROM @Redundant)
		BEGIN
			SELECT @CustIds1 = ''
			SELECT @CustIds1 = @CustIds1  + CAST(CustId AS VARCHAR(20)) + ','
			FROM @Redundant

			DELETE DBTXN.CustDB.dbo.Dep_CustBAActive WITH(ROWLOCK)
			WHERE CustId IN (SELECT CustId FROM @Redundant)

			SELECT @CustIds1 = SUBSTRING(@CustIds1, 0, LEN(@CustIds1)) --remove last comma
			SELECT @AlertStr1 = 'Redundant one or more BA active members: ' + @CustIds1 + ' .The job has just deleted the redundant BA active members.'
			RAISERROR (@AlertStr1, 16, 1)
		END

	END
END
GO