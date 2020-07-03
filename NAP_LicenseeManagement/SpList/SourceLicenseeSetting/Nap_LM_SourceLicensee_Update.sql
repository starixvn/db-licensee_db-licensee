/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_SourceLicensee_Update]
	@EndDate			DATE,
	@Restart			BIT,
	@RestartFrom		DATE,
	@RestartTo			DATE,
	@SettingIdList		VARCHAR(MAX)= ''
AS
/*
	 Created: Amanda
	 Date: 2018-12-14
	 Task: Implement "Source Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181212@Amanda: Supsend and restart Source Licensees [Redmine: #83584]
	  - 20200120@Amanda: Only validate restart data if @Restart = 1 [Redmine: #112840]

*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @settingId AS TABLE (
			Id			INT,
			SourceId	INT,
			LicenseeId	INT,
			IsUpdated	BIT
	)

	DECLARE @invalidSource AS TABLE (
			Id			INT
	)
	
	DECLARE @duplicateSource AS TABLE (
			Id				INT IDENTITY(1,1),
			LicenseeId		INT,
			SourceId		INT,
			DuplicatedRow	INT
	)
	
	INSERT INTO @settingId(Id)
	SELECT DISTINCT val
	FROM CUSTDB.dbo.strSplit(@SettingIdList,',')
	
	UPDATE s
	SET s.SourceId = l.SourcedId, 
		s.LicenseeId = l.LicenseeID,
		s.IsUpdated = CASE WHEN l.EndDate > @EndDate THEN 1 ELSE 0 END
	FROM @settingId s
	INNER JOIN dbo.LicenseeSourcedSetting l WITH (NOLOCK) ON s.Id = l.ID
	WHERE l.IsActive = 1
	
	DELETE @settingId
	WHERE SourceId IS NULL OR LicenseeId IS NULL
	
	-- Stop Source Licensee
	UPDATE l
	SET l.EndDate = @EndDate
	FROM dbo.LicenseeSourcedSetting l WITH (ROWLOCK, UPDLOCK)
	INNER JOIN @settingId s ON l.ID = s.Id
	WHERE s.IsUpdated = 1

	INSERT INTO @invalidSource(id) 
	SELECT s.Id 
	FROM dbo.LicenseeSourcedSetting l WITH (ROWLOCK) 
	INNER JOIN @settingId s ON l.ID = s.Id 
	WHERE l.EffectiveDate > l.EndDate

	IF (@Restart = 1 AND ISNULL(@RestartFrom,'') <> '' AND ISNULL(@RestartTo,'') <> '')
	BEGIN
		INSERT INTO @duplicateSource(SourceId, LicenseeId, DuplicatedRow)
		SELECT SourceId, LicenseeId, COUNT(1) - 1
		FROM @settingId
		GROUP BY SourceId, LicenseeId
		HAVING COUNT(1) > 1
			
		DECLARE @m INT, @i INT, @sourceId INT, @licenseeId INT, @duplicatedRow INT
		SELECT @m = MAX(Id), @i = 1 FROM @duplicateSource
			
		WHILE (@i <= @m)
		BEGIN
			SELECT @SourceId = SourceId, @licenseeId = LicenseeId, @duplicatedRow = DuplicatedRow
			FROM @duplicateSource
			WHERE Id = @i
				
			DELETE TOP (@duplicatedRow)  
			FROM @settingId
			WHERE SourceId = @sourceId AND LicenseeId = @licenseeId

			SET @i = @i + 1	
		END
			
		-- Restart
		INSERT INTO dbo.LicenseeSourcedSetting (SiteName, LicenseeID, SourcedLicenseeID, SourcedCurrencyID, IsActive, Roleid, EffectiveDate, SourcedId, SourcedSiteName, EndDate)
		SELECT l.SiteName, l.LicenseeID, l.SourcedLicenseeID, l.SourcedCurrencyID, 1, l.Roleid, @RestartFrom, l.SourcedId, l.SourcedSiteName, @RestartTo
		FROM dbo.LicenseeSourcedSetting l WITH (NOLOCK)
		INNER JOIN @settingId s ON l.ID = s.Id

	END

	DELETE l from dbo.LicenseeSourcedSetting l WITH (ROWLOCK) 
	INNER JOIN @invalidSource s ON l.ID = s.Id
END
GO