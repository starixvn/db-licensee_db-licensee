/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_CustomerBAStatusSel]
	@custids NVARCHAR(MAX)
AS
	/*
		Created: 20210428@Johnson
		Task: get current BA status for list customers to write log multiple update
		DB: DBCUST/CUSTDB
		
		Revisions: 
			- 20210428@Johnson: initial sp [redmine:#121042]
			- 20220614@Eden: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831] 
			
		Parameter's Explanations:	
			- @custids: list custid, '1,2,3'
	*/
BEGIN
	CREATE TABLE #tmpCust (custid INT PRIMARY KEY)
	
	INSERT INTO #tmpCust(custid)
	SELECT value
	FROM STRING_SPLIT(@custids,',')
	WHERE value <> ''
	
	SELECT t.custid, CASE WHEN c.custid IS NULL THEN 0 ELSE 1 END isBA
	FROM #tmpCust t
		LEFT JOIN Dep_CustBAActive c ON t.custid = c.custid

	DROP TABLE #tmpCust
END
GO