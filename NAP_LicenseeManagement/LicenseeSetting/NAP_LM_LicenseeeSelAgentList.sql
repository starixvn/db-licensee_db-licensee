/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[NAP_LM_LicenseeSelAgentList]
	@SRecommend INT
AS
/*
	Created: 20211223@Johnson
	Task: Get list agent belong to super to update bet settings 
	DB: DBCUST.CustDB	
	Revisions:
		- 20211223@Johnson: initial sp [redmine:#165885]
	Parameter's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tblmrecommend  (CustID INT PRIMARY KEY)
		
	INSERT INTO #tblmrecommend(CustID)
	SELECT custid FROM custinfo WITH (NOLOCK) WHERE roleid=3
	and username LIKE '%Acc%' and srecommend=@SRecommend		

	SELECT username + CASE WHEN NULLIF(s.OperatorID,'') IS NOT NULL THEN ' ('+s.OperatorID+')'
							WHEN ISNULL(s.OperatorID,'') = '' AND s.AgentID IS NOT NULL THEN ' (sub)'
							ELSE '' END as username
		, CustID
	FROM customer c WITH (NOLOCK)
		LEFT JOIN [SiteConfig].[dbo].[Operator] s WITH(NOLOCK) ON c.Custid=s.AgentID
	WHERE roleid = 2 and Srecommend = @SRecommend AND mrecommend NOT IN (SELECT CustID FROM #tblmrecommend)
	ORDER BY username
END
GO
