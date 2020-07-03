/*<info serverAlias="DBCUST-SiteConfig" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Operator_Search]
	@SiteName			VARCHAR(50)	= '',
	@CurrencyId			INT			= 0,
	@OperatorId			VARCHAR(50)	= '',
	@AgentId			INT			= 0,
	@IsEmptyOperatorId	BIT			= 0,
	@PageIndex			INT			= 1,
	@PageSize			INT			= 20,
	@TotalItem			INT			= 0 OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2018-09-24
	 Task: Implement "Manage operatorID" function
	 DB: DBCUST.SiteConfig
	 
	 Revisions:
	  - 20180924@Amanda: Select Lrf Site Name which enable subsidiary  [Redmine: #83584]
	  - 20181225@Amanda: Implement paging [Redmine: #83584]
	  
	 Example:
	  exec Nap_LM_Operator_Select
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #OperatorIdTbl (RowNum INT, Id INT)
	DECLARE @from INT, @to INT

	INSERT INTO #OperatorIdTbl(RowNum, Id)
	SELECT	ROW_NUMBER() OVER (ORDER BY o.SiteName ASC, o.Currency ASC, o.AgentID ASC),
			o.AgentID
	FROM dbo.Operator o WITH(NOLOCK)
	WHERE (@IsEmptyOperatorId = 1 OR @AgentId = 0 OR o.AgentID = @AgentId) 
			AND (ISNULL(@SiteName,'') = '' OR o.SiteName = @SiteName)
			AND (@CurrencyId = 0 OR o.Currency = @CurrencyId)
			AND (
				(@IsEmptyOperatorId = 1 AND ISNULL(o.OperatorID,'') = '') 
				OR 
				(@IsEmptyOperatorId = 0 AND (ISNULL(@OperatorId,'') = '' OR o.OperatorID = @OperatorId))
			)
	ORDER BY o.SiteName, o.Currency
	
	SET @from = ((@PageIndex - 1) * @PageSize) + 1
	SET @to = @from + @PageSize - 1
	
	SELECT i.RowNum, o.AgentID, o.SiteName, o.Currency AS CurrencyId, e.currency AS CurrencyName, o.OperatorID, c.username
	FROM dbo.Operator o WITH(NOLOCK)
	INNER JOIN #OperatorIdTbl i ON o.AgentID = i.Id
	INNER JOIN CustDB.dbo.exchange e WITH(NOLOCK) ON o.Currency = e.exchangeid
	LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON o.AgentID = c.custid
	WHERE i.RowNum BETWEEN @from AND @to
	ORDER BY i.RowNum
	
	SELECT @TotalItem = MAX(RowNum)
	FROM #OperatorIdTbl
	
	DROP TABLE #OperatorIdTbl
END
GO