/*<info serverAlias="DBCUST-CUSTDB" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_OddsGroup_AgentListSel]
	@LicenseeId	INT = 0,
	@CurrencyList VARCHAR(MAX) = '',
	@AgentList VARCHAR(MAX) = ''
AS
/*
	Created: 20241031@Johnson
	Task: Get list agent belong to licensee to update odds group 
	DB: DBCUST.CustDB	
	
	Revisions:
		- 20241031@Johnson: LAP - Supporting update Odds Group by site/subsidiary [redmine:#199306]
	Parameter's Explanation:
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @tmpCurrency TABLE (currency INT)
	DECLARE @tmpAgent TABLE (custid INT)
	DECLARE @tmpSuper TABLE (custid INT)
	CREATE TABLE #tblDummy  (CustID INT PRIMARY KEY)
	CREATE TABLE #Result (custid INT PRIMARY KEY,currency INT, Oddsgroup VARCHAR(10))
	
	INSERT INTO @tmpCurrency(currency)
	SELECT value 
	FROM STRING_SPLIT(@CurrencyList,',')
	
	INSERT INTO @tmpAgent(custid)
	SELECT value 
	FROM STRING_SPLIT(@AgentList,',')
	
	IF @AgentList = ''
	BEGIN
		INSERT INTO @tmpSuper(custid)
		SELECT custid
		FROM Dep_CustSuper WITH(NOLOCK)
		WHERE site IN (SELECT LicenseeName 
						FROM bodb_Licensee.dbo.Licensees WITH(NOLOCK) 
						WHERE LicenseeID = @LicenseeId
							AND IsActive = 1)
			AND currency IN (SELECT currency FROM @tmpCurrency)
						
		INSERT INTO #tblDummy(CustID)
		SELECT custid 
		FROM custinfo WITH (NOLOCK) 
		WHERE roleid=3
			AND (username LIKE '%Acc%' OR username LIKE '%LocalBank%' OR username LIKE '%AFF%' OR username LIKE 'AB88'+'CAS%')
			AND srecommend IN (SELECT custid FROM @tmpSuper)
			
		SELECT c.custid, c.currency, c.username, o.ugroup as OddsGroup , ISNULL(s.OperatorID,'') OperatorID
		FROM customer c WITH(NOLOCK)
			LEFT JOIN Dep_DefaultOddGroup o WITH(NOLOCK) ON c.custid = o.AgentID
			LEFT JOIN [SiteConfig].[dbo].[Operator] s WITH(NOLOCK) ON c.Custid=s.AgentID
		WHERE srecommend IN (SELECT custid FROM @tmpSuper)
			AND mrecommend NOT IN (SELECT custid FROM #tblDummy)
			AND roleid = 2
		ORDER BY currency,srecommend	
	END
	ELSE
	BEGIN
		SELECT c.custid, c.currency, c.username, o.ugroup as OddsGroup , ISNULL(s.OperatorID,'') OperatorID
		FROM customer c WITH(NOLOCK)
			LEFT JOIN Dep_DefaultOddGroup o WITH(NOLOCK) ON c.custid = o.AgentID
			LEFT JOIN [SiteConfig].[dbo].[Operator] s WITH(NOLOCK) ON c.Custid=s.AgentID
		WHERE c.roleid = 2
			AND c.custid IN (SELECT custid FROM @tmpAgent)
			AND c.currency IN (SELECT currency FROM @tmpCurrency)
		ORDER BY c.currency,srecommend
	END
	
END		