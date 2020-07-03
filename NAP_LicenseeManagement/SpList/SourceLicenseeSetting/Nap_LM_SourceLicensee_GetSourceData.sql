/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_SourceLicensee_GetSourceData]
	@FromDate			DATE		= '',
	@ToDate				DATE		= '',
	@LicenseeId			INT			= 0,
	@SourceLicenseeId	INT			= 0,
	@CurrencyId			VARCHAR(MAX) = '',
	@RoleId				INT			= 0,
	@PageIndex			INT			= 1,
	@PageSize			INT			= 20,
	@TotalItem			INT			= 0 OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2018-12-11
	 Task: Implement "Source Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181211@Amanda: Select Source Licensees [Redmine: #83584]
	  - 20180315@Amanda: Fix paging issue [Redmine: #83584]
	  - 20200117@Amanda: Allow search with multiple currencies [Redmine: #112840]
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #data (
		RowNum		INT,
		SourceId	INT,
		CurrencyId	INT,
		EffectiveDate SMALLDATETIME,
		EndDate		SMALLDATETIME,
		IsActive	BIT
	)
	DECLARE @currency AS TABLE (
		Id			INT
	)
	
	DECLARE @from INT, @to INT
		
	INSERT INTO @currency(Id)
	SELECT DISTINCT val
	FROM CUSTDB.dbo.strSplit(@CurrencyId,',')
	
	IF @RoleId = 2 -- Agent
	BEGIN
		;WITH Setting_CTE AS (
			SELECT l.SourcedId, l.EffectiveDate, l.EndDate 
			FROM dbo.LicenseeSourcedSetting l WITH(NOLOCK)
			WHERE l.LicenseeID = @LicenseeId
				AND l.SourcedLicenseeID = @SourceLicenseeId
				AND l.Roleid = @Roleid
				AND @FromDate <= l.EndDate
				AND @ToDate >= l.EffectiveDate
				AND l.EffectiveDate <= l.EndDate
				AND EXISTS (SELECT 1 FROM @currency c WHERE c.Id = 0 OR l.SourcedCurrencyID = c.Id)
		)
		INSERT INTO #data (RowNum, SourceId, CurrencyId, EffectiveDate, EndDate, IsActive)
		SELECT	ROW_NUMBER() OVER (ORDER BY l.CustID ASC, l.Currency ASC, s.EffectiveDate ASC),
				l.CustID,
				l.Currency,
				s.EffectiveDate,
				s.EndDate,
				CASE WHEN s.SourcedId IS NOT NULL THEN 0 ELSE 1 END AS IsActive
		FROM dbo.LicenseeCust l WITH (NOLOCK)
		LEFT JOIN Setting_CTE s ON s.SourcedId = l.CustID
		WHERE l.LicenseeID = @SourceLicenseeId AND l.RoleID = 2 AND EXISTS (SELECT 1 FROM @currency c WHERE c.Id = 0 OR l.Currency = c.Id)
	END
	IF @RoleId = 1 -- Member
	BEGIN
		;WITH Setting_CTE AS (
			SELECT l.SourcedId, l.EffectiveDate, l.EndDate 
			FROM dbo.LicenseeSourcedSetting l WITH(NOLOCK)
			WHERE l.LicenseeID = @LicenseeId
				AND l.SourcedLicenseeID = @SourceLicenseeId
				AND l.Roleid = @Roleid
				AND @FromDate <= l.EndDate
				AND @ToDate >= l.EffectiveDate
				AND l.EffectiveDate <= l.EndDate
				AND EXISTS (SELECT 1 FROM @currency c WHERE c.Id = 0 OR l.SourcedCurrencyID = c.Id)
		)
		INSERT INTO #data (RowNum, SourceId, CurrencyId, EffectiveDate, EndDate, IsActive)
		SELECT	ROW_NUMBER() OVER (ORDER BY c.custid ASC, c.currency ASC, s.EffectiveDate ASC),
				c.custid,
				c.currency,
				s.EffectiveDate,
				s.EndDate,
				CASE WHEN s.SourcedId IS NOT NULL THEN 0 ELSE 1 END AS IsActive
		FROM CustDB.dbo.custInfo c WITH (NOLOCK)
		INNER JOIN dbo.LicenseeCust l WITH (NOLOCK) ON l.CustID = c.recommend AND c.currency = l.currency
		LEFT JOIN Setting_CTE s ON s.SourcedId = c.custid
		WHERE l.LicenseeID = @SourceLicenseeId AND l.RoleID = 2 AND c.roleid = 1 AND EXISTS (SELECT 1 FROM @currency cu WHERE cu.Id = 0 OR l.Currency = cu.Id)
	END

	SELECT @TotalItem = MAX(RowNum)
	FROM #data
	
	SET @from = ((@PageIndex - 1) * @PageSize) + 1
	SET @to = @from + @PageSize - 1
	
	SELECT	d.SourceId,
			d.CurrencyId	AS CurrencyID,
			e.currency		AS CurrencyName,
			@RoleId			AS RoleId,
			d.EffectiveDate,
			d.EndDate,
			d.IsActive		
	FROM #data d
	INNER JOIN CustDB.dbo.Exchange e WITH (NOLOCK) ON e.exchangeid = d.CurrencyId
	WHERE d.RowNum BETWEEN @from AND @to
	ORDER BY d.RowNum
	
	DROP TABLE #data
	
END
GO
