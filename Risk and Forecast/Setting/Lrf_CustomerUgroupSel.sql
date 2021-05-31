/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_CustomerUgroupSel]
	@custids NVARCHAR(MAX)
AS
	/*
		Created: 20210428@Johnson
		Task: get current ugroup for list customers to write log multiple update
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
	
	SELECT t.custid, ugroup
	FROM #tmpCust t
		INNER JOIN dbo.Customer c WITH  (NOLOCK) ON t.custid = c.custid

	DROP TABLE #tmpCust
END
GO