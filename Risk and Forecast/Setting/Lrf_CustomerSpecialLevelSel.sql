/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_CustomerSpecialLevelSel]
	@custids NVARCHAR(MAX)
AS
	/*
		Created: 20210428@Johnson
		Task: get current special level for list customers to write log multiple update
		DB: DBCUST/CUSTDB
		
		Revisions: 
			- 20210428@Johnson: initial sp [redmine:#121042]
			
		Parameter's Explanations:	
			- @custids: list custid, '1,2,3'
	*/
BEGIN
	CREATE TABLE #tmpCust (custid INT PRIMARY KEY)
	
	INSERT INTO #tmpCust(custid)
	SELECT val
	FROM dbo.f_SplitString(@custids,',')
	OPTION (maxrecursion 0)
	
	SELECT t.custid, ISNULL(SpecialLevel,0) SpecialLevel
	FROM #tmpCust t
		LEFT JOIN dbo.Dep_CustSpecialLevel c WITH  (NOLOCK) ON t.custid = c.custid

	DROP TABLE #tmpCust
END
GO