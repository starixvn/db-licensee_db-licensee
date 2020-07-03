/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_Select]
	@LicenseeName	VARCHAR(50)	= '',
	@IsActive		BIT			= 1,
	@IsAll			BIT			= 1,
	@PageIndex		INT			= 1,
	@PageSize		INT			= 20,
	@TotalItem		INT			= 0 OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2018-11-01
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20181101@Amanda: Select Licensees [Redmine: #83584]
	  - 20181225@Amanda: Implement paging [Redmine: #83584]
	  - 20180111@Amanda: Remove [Description] column from returned data [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @LicenseeId AS TABLE (RowNum INT, Id INT)
	DECLARE @from INT, @to INT

	INSERT INTO @LicenseeId(RowNum, Id)
	SELECT	ROW_NUMBER() OVER (ORDER BY l.LicenseeName ASC),
			l.LicenseeID
	FROM dbo.Licensees l WITH(NOLOCK)
	WHERE ( @IsAll = 0 AND LicenseeName = @LicenseeName)
			OR (
				@IsAll = 1 AND
				(ISNULL(@LicenseeName,'') = '' OR l.LicenseeName LIKE '%' + @LicenseeName + '%')
				AND l.IsActive = @IsActive
			)
	
	SET @from = ((@PageIndex - 1) * @PageSize) + 1
	SET @to = @from + @PageSize - 1
	
	SELECT 	l.LicenseeID,
			l.LicenseeName,
			l.IsDeposit,
			l.AffectedDate,
			l.IsActive,
			l.IsKPIActive,
			l.IsOneWorkActive,
			l.BrandName,
			l.CompanyName,
			l.IsAllowedMemberComm,
			l.EditBetSetting
	FROM dbo.Licensees l WITH(NOLOCK)
	INNER JOIN @LicenseeId i ON l.LicenseeID = i.Id
	WHERE i.RowNum BETWEEN @from AND @to
	ORDER BY i.RowNum
	
	SELECT @TotalItem = MAX(RowNum)
	FROM @LicenseeId
END
GO