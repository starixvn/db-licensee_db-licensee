/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_SourceLicensee_Select]
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
	 Date: 2018-12-07
	 Task: Implement "Source Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181207@Amanda: Select Source Licensees [Redmine: #83584]
	  - 20181225@Amanda: Add 'order by' [Redmine: #83584]
	  - 20190215@Amanda: Correct where condition for date [Redmine: #83584]
	  - 20200117@Amanda: Allow search with multiple currencies [Redmine: #112840]
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #data (
		ID		INT,
		RowNum	INT
	)
	
	DECLARE @currency AS TABLE (
		Id			INT
	)
	
	DECLARE @from INT, @to INT, @isAllCurrency BIT
	
	INSERT INTO @currency(Id)
	SELECT DISTINCT val
	FROM CUSTDB.dbo.strSplit(@CurrencyId,',')
	
	IF EXISTS (SELECT 1 FROM @currency WHERE Id = 0)
	BEGIN
		SET @isAllCurrency = 1;
	END
	
	IF (@isAllCurrency = 1)
	BEGIN	
		INSERT INTO #data (
				RowNum,
				ID
		)
		SELECT	ROW_NUMBER() OVER (ORDER BY l.LicenseeID ASC, l.SourcedLicenseeID ASC, l.SourcedCurrencyID ASC, l.SourcedId ASC, l.EffectiveDate ASC),
				l.ID	
		FROM dbo.LicenseeSourcedSetting l WITH(NOLOCK)
		WHERE (ISNULL(@ToDate, '') = '' OR l.EffectiveDate <= @ToDate)
			AND (ISNULL(@FromDate, '') = '' OR l.EndDate >= @FromDate)
			AND l.EffectiveDate <= l.EndDate
			AND (@LicenseeId = 0 OR l.LicenseeID = @LicenseeId)
			AND (@SourceLicenseeId = 0 OR l.SourcedLicenseeID = @SourceLicenseeId)
			AND l.Roleid = @RoleId
			AND l.IsActive = 1
	END
	ELSE
	BEGIN
		INSERT INTO #data (
				RowNum,
				ID
		)
		SELECT	ROW_NUMBER() OVER (ORDER BY l.LicenseeID ASC, l.SourcedLicenseeID ASC, l.SourcedCurrencyID ASC, l.SourcedId ASC, l.EffectiveDate ASC),
				l.ID	
		FROM dbo.LicenseeSourcedSetting l WITH(NOLOCK)
		WHERE (ISNULL(@ToDate, '') = '' OR l.EffectiveDate <= @ToDate)
			AND (ISNULL(@FromDate, '') = '' OR l.EndDate >= @FromDate)
			AND l.EffectiveDate <= l.EndDate
			AND (@LicenseeId = 0 OR l.LicenseeID = @LicenseeId)
			AND (@SourceLicenseeId = 0 OR l.SourcedLicenseeID = @SourceLicenseeId)
			AND l.Roleid = @RoleId
			AND l.IsActive = 1
			AND EXISTS (SELECT 1 FROM @currency c WHERE l.SourcedCurrencyID = c.Id)
	END

	SELECT @TotalItem = MAX(RowNum)
	FROM #data
	
	SET @from = ((@PageIndex - 1) * @PageSize) + 1
	SET @to = @from + @PageSize - 1
	
	SELECT	l.ID,
			l.SiteName,
			l.SourcedId			AS SourceId,
			l.SourcedCurrencyID AS CurrencyID,
			e.currency			AS CurrencyName,
			l.Roleid,
			l.SourcedSiteName	AS SourceSiteName,
			l.EffectiveDate,
			l.EndDate,
			l.IsActive
	FROM #data d 
	INNER JOIN dbo.LicenseeSourcedSetting l WITH(NOLOCK) ON l.ID = d.ID
	INNER JOIN CustDB.dbo.Exchange e WITH (NOLOCK) ON e.exchangeid = l.SourcedCurrencyID
	WHERE d.RowNum BETWEEN @from AND @to
	ORDER BY d.RowNum
	
	DROP TABLE #data
	
END
GO
