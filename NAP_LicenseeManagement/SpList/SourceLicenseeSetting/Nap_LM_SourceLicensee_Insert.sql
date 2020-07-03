/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_SourceLicensee_Insert]
	@FromDate			DATE,
	@ToDate				DATE,
	@LicenseeId			INT,
	@SourceLicenseeId	INT,
	@CurrencyId			VARCHAR(MAX) = '',
	@RoleId				INT,
	@IsAddAll			BIT,
	@SourceIdList		VARCHAR(MAX) = '',
	@AffectedRow		INT	= 0 OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2018-12-12
	 Task: Implement "Source Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181212@Amanda: Add new Source Licensees [Redmine: #83584]
	  - 20200117@Amanda: Allow to add data with multiple currencies [Redmine: #112840]
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #data (
		SourceId	INT,
		CurrencyId	INT
	)
	DECLARE @sourceId AS TABLE (
		Id			INT,
		CurrencyId	INT,
		IsValid		BIT,
		Existed		BIT
	)
	DECLARE @currency AS TABLE (
		Id			INT
	)
	
	DECLARE @SiteName VARCHAR(50), @SourceSiteName VARCHAR(50)
	
	INSERT INTO @currency(Id)
	SELECT DISTINCT val
	FROM CUSTDB.dbo.strSplit(@CurrencyId,',')
	
	SELECT @SiteName = LicenseeName
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeId
	
	SELECT @SourceSiteName = LicenseeName
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeID = @SourceLicenseeId
	
	IF @IsAddAll = 1
	BEGIN
		IF @RoleId = 1
		BEGIN
			;WITH Setting_CTE AS (
				SELECT l.SourcedId
				FROM dbo.LicenseeSourcedSetting l WITH(NOLOCK)
				WHERE l.LicenseeID = @LicenseeId
					AND l.SourcedLicenseeID = @SourceLicenseeId
					AND l.Roleid = @Roleid
					AND @FromDate <= l.EndDate
					AND @ToDate >= l.EffectiveDate
					AND l.EffectiveDate <= l.EndDate
					AND l.IsActive = 1
					AND EXISTS (SELECT 1 FROM @currency c WHERE c.Id = 0 OR l.SourcedCurrencyID = c.Id)
			)
			INSERT INTO #data (SourceId, CurrencyId)
			SELECT c.custid, l.Currency
			FROM CustDB.dbo.custInfo c WITH (NOLOCK)
			INNER JOIN dbo.LicenseeCust l WITH (NOLOCK) ON l.CustID = c.recommend AND l.Currency = c.currency
			LEFT JOIN Setting_CTE s ON c.custid = s.SourcedId
			WHERE l.LicenseeID = @SourceLicenseeId 
				AND l.RoleID = 2 
				AND c.roleid = 1
				AND s.SourcedId IS NULL
				AND EXISTS (SELECT 1 FROM @currency cu WHERE cu.Id = 0 OR l.Currency = cu.Id)
				
			;SET @AffectedRow = @@ROWCOUNT	
		END
		ELSE IF @RoleId = 2
		BEGIN
			;WITH Setting_CTE AS (
				SELECT l.SourcedId
				FROM dbo.LicenseeSourcedSetting l WITH(NOLOCK)
				WHERE l.LicenseeID = @LicenseeId
					AND l.SourcedLicenseeID = @SourceLicenseeId
					AND l.Roleid = @Roleid
					AND @FromDate <= l.EndDate
					AND @ToDate >= l.EffectiveDate
					AND l.EffectiveDate <= l.EndDate
					AND l.IsActive = 1
					AND EXISTS (SELECT 1 FROM @currency c WHERE c.Id = 0 OR l.SourcedCurrencyID = c.Id)
			)
			INSERT INTO #data (SourceId, CurrencyId)
			SELECT l.CustID, l.Currency
			FROM dbo.LicenseeCust l WITH (NOLOCK)
			LEFT JOIN Setting_CTE s ON l.custid = s.SourcedId
			WHERE l.LicenseeID = @SourceLicenseeId
				AND l.RoleID = 2
				AND s.SourcedId IS NULL
				AND EXISTS (SELECT 1 FROM @currency c WHERE c.Id = 0 OR l.Currency = c.Id)
				
			;SET @AffectedRow = @@ROWCOUNT
		END
	END
	ELSE
	BEGIN
		INSERT INTO @sourceId(Id, IsValid, Existed, CurrencyId)
		SELECT DISTINCT val, 0, 0, 0
		FROM CUSTDB.dbo.strSplit(@SourceIdList,',')
		
		IF @RoleId = 1
		BEGIN
			UPDATE s
			SET IsValid = 1, s.CurrencyId = l.Currency
			FROM @sourceId s
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = s.Id
			INNER JOIN dbo.LicenseeCust l WITH (NOLOCK) ON l.CustID = c.recommend AND l.Currency = c.currency
			WHERE l.LicenseeID = @SourceLicenseeId
				AND l.RoleID = 2
				AND c.roleid = 1
				AND EXISTS (SELECT 1 FROM @currency cu WHERE cu.Id = 0 OR l.Currency = cu.Id)
		END
		ELSE IF @RoleId = 2
		BEGIN
			UPDATE s
			SET IsValid = 1, s.CurrencyId = l.Currency
			FROM @sourceId s
			INNER JOIN dbo.LicenseeCust l WITH (NOLOCK) ON l.CustID = s.Id
			WHERE l.LicenseeID = @SourceLicenseeId
				AND l.RoleID = 2
				AND EXISTS (SELECT 1 FROM @currency c WHERE c.Id = 0 OR l.Currency = c.Id)
		END
		
		UPDATE s
		SET Existed = 1
		FROM @sourceId s
		INNER JOIN dbo.LicenseeSourcedSetting l WITH(NOLOCK) ON l.SourcedId = s.Id
		WHERE l.LicenseeID = @LicenseeId
			AND l.SourcedLicenseeID = @SourceLicenseeId
			AND l.Roleid = @Roleid
			AND @FromDate <= l.EndDate
			AND @ToDate >= l.EffectiveDate
			AND l.EffectiveDate <= l.EndDate
			AND l.IsActive = 1
			AND s.IsValid = 1
			AND EXISTS (SELECT 1 FROM @currency c WHERE c.Id = 0 OR l.SourcedCurrencyID = c.Id)
			
		IF NOT EXISTS (SELECT 1 FROM @sourceId WHERE IsValid = 0 OR Existed = 1)
		BEGIN
			INSERT INTO #data(SourceId, CurrencyId)
			SELECT Id, CurrencyId
			FROM @sourceId
			WHERE IsValid = 1 AND Existed = 0
			
			;SET @AffectedRow = @@ROWCOUNT
		END	
	END
	
	INSERT INTO dbo.LicenseeSourcedSetting(	
		SiteName,
		LicenseeId,
		SourcedLicenseeId,
		SourcedCurrencyId,
		IsActive,
		RoleId,
		EffectiveDate,
		SourcedId,
		SourcedSiteName,
		EndDate
	)
	SELECT @SiteName, @LicenseeId, @SourceLicenseeId, CurrencyId, 1, @RoleId, @FromDate, SourceId, @SourceSiteName, @ToDate
	FROM #data
	
	SELECT Id AS SourceId, IsValid, Existed
	FROM @sourceId
	WHERE IsValid = 0 OR Existed = 1
	
	DROP TABLE #data
END
GO