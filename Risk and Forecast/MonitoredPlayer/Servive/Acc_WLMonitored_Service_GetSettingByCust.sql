/*<info serverAlias="DBCUST-CUSTDB" executers="bodbDownlineNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Acc_WLMonitored_Service_GetSettingByCust
	 @CustList	VARCHAR(MAX)
	,@Sporttype SMALLINT = 0
	,@IsDeposit BIT = 0
	,@SuperList VARCHAR(MAX) = '' --super test list
	,@IsTest	BIT = 0
AS  
/*  
	Created:	20220523@Eden
	Task:		Get WLMonitored setting  of input custid(s)
	DB:			DBCUST/CustDB
	Original:	
  
	Revisions:  
	    - 20220523@Eden: LAP - Player Segmentation - Monitored Player [Redmine:#172605]

	Param's Explanation:
		@IsSub : Subsidiary Search

	EXEC Acc_WLMonitored_Service_GetSettingByCust 
		@CustList = '29047611,29049901,1833153,1176092,1584729',
		@IsDeposit = 1,
		@SuperList = '3233912',
		@IsTest = 1
	
*/  
BEGIN 
	CREATE TABLE #Cust_Tbl(CustID INT)
	CREATE TABLE #Cust_Tbl_Credit(CustID INT)
	CREATE TABLE #Cust_Tbl_Deposit(CustID INT)

	DECLARE @SuperTbl TABLE(CustID INT PRIMARY KEY)

	INSERT INTO @SuperTbl(CustID)
	SELECT DISTINCT value FROM STRING_SPLIT(@SuperList,',') WHERE value <> ''

	INSERT INTO #Cust_Tbl(CustID)
	SELECT DISTINCT value FROM string_split(@CustList,',') WHERE value <> '' 

	IF @IsDeposit = 0
	BEGIN
		IF @IsTest = 1
		BEGIN
			INSERT INTO #Cust_Tbl_Credit(CustID)
			SELECT c.CustID
			FROM #Cust_Tbl c
				INNER JOIN custinfo ci WITH(NOLOCK) 
					ON c.CustID = ci.custid
			WHERE ci.srecommend NOT IN ( SELECT CustID FROM Dep_CustSuper WITH(NOLOCK))
				AND ci.srecommend IN (SELECT custid FROM @SuperTbl)
		END
		ELSE
		BEGIN
			INSERT INTO #Cust_Tbl_Credit(CustID)
			SELECT c.CustID
			FROM #Cust_Tbl c
				INNER JOIN custinfo ci WITH(NOLOCK) 
					ON c.CustID = ci.custid
			WHERE ci.srecommend NOT IN ( SELECT CustID FROM Dep_CustSuper WITH(NOLOCK))
				AND ci.srecommend NOT IN (SELECT custid FROM @SuperTbl)
		END

		---------get setting Credit
		SELECT ci.custid, w.WinningThreshold, w.LosingThreshold
			, w.WinningUpdateTime, w.LosingUpdateTime, 1 AS SettingType
			, ci.srecommend
		FROM WLMonitored_Global w WITH(NOLOCK) 
			INNER JOIN custInfo ci WITH(NOLOCK) ON w.agentid = ci.recommend AND ci.roleid = 1 AND ci.Enabled = 1
			INNER JOIN #Cust_Tbl_Credit cr ON cr.CustID = ci.custid
			LEFT JOIN WLMonitored_Player per WITH(NOLOCK) ON per.custid = ci.custid AND w.Sporttype = per.Sporttype
		WHERE per.CustID IS NULL
			AND w.Sporttype = @Sporttype
		UNION ALL
		SELECT per.custid, per.WinningThreshold, per.LosingThreshold
			, per.WinningUpdateTime, per.LosingUpdateTime, 2 AS SettingType
			, ci.srecommend
		FROM WLMonitored_Player per WITH(NOLOCK) 
			INNER JOIN custInfo ci WITH(NOLOCK) ON per.custid = ci.custid AND ci.roleid = 1 AND ci.Enabled = 1
			INNER JOIN #Cust_Tbl_Credit cr ON cr.CustID = ci.custid
		WHERE NOT( per.WinningThreshold IS NULL AND per.LosingThreshold IS NULL) -- config unlimited
			AND per.Sporttype = @Sporttype
	END
	ELSE
	BEGIN
		IF @IsTest = 1
		BEGIN
			INSERT INTO #Cust_Tbl_Deposit(CustID)
			SELECT c.CustID
			FROM #Cust_Tbl c
				INNER JOIN custinfo ci WITH(NOLOCK) 
					ON c.CustID = ci.custid
			WHERE ci.srecommend IN ( SELECT CustID FROM Dep_CustSuper WITH(NOLOCK))
				AND ci.srecommend IN (SELECT custid FROM @SuperTbl)
		END
		ELSE
		BEGIN
			INSERT INTO #Cust_Tbl_Deposit(CustID)
			SELECT c.CustID
			FROM #Cust_Tbl c
				INNER JOIN custinfo ci WITH(NOLOCK) 
					ON c.CustID = ci.custid
			WHERE ci.srecommend IN ( SELECT CustID FROM Dep_CustSuper WITH(NOLOCK))
				AND ci.srecommend NOT IN (SELECT custid FROM @SuperTbl)
		END
		---------get setting Deposit
		SELECT per.custid, per.WinningThreshold
			, per.WinningUpdateTime 
			, ci.srecommend
		FROM Dep_WLMonitored_Player per WITH(NOLOCK) 
			INNER JOIN custInfo ci WITH(NOLOCK) ON per.custid = ci.custid AND ci.roleid = 1 AND ci.Enabled = 1
			INNER JOIN #Cust_Tbl_Deposit cr ON cr.CustID = ci.custid
		WHERE per.Sporttype = @Sporttype
	END
	
	DROP TABLE #Cust_Tbl
	DROP TABLE #Cust_Tbl_Credit
	DROP TABLE #Cust_Tbl_Deposit
END
GO