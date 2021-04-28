/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_CheckBelongingMultiple_GetAgentInfo]
	@custIds	NVARCHAR(MAX) = ''
AS
/*
	Created: 20210505@Johnson
	Description: LAP - Get agent info which customers belongs for multiple update
	DB: DBEXT.bodb02
   
	Revisions:
		- 20210505@Johnson: initial sp [redmine:#121042]		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpCust (custid INT PRIMARY KEY)
	
	INSERT INTO #tmpCust(custid)
	SELECT val
	FROM dbo.f_SplitString(@custids,',')
	OPTION (maxrecursion 0)
	
	SELECT c.custid, c.recommend as AgentID, c.currency AS CurrencyId
	FROM #tmpCust t
		INNER JOIN CustInfo c ON t.custid = c.custid
	WHERE c.srecommend IN (SELECT custid FROM Dep_CustSuper WITH(NOLOCK))

	DROP TABLE #tmpCust
END
	
	