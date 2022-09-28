/*<info serverAlias="DBCUST-CUSTDB" executers="bodbDownlineNet,bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Acc_WLMonitored_Service_GetChangedSettingList
	 @Sporttype SMALLINT = 0
	,@IsDeposit BIT = 0
	,@SuperList VARCHAR(MAX) = ''
	,@IsTest	BIT = 0
	,@LastScanDate DATETIME = NULL
AS  
/*  
	Created:	20220523@Eden
	Task:		Get setting global/Personal whose changed today
	DB:			DBCUST/CustDB
	Original:	
  
	Revisions:  
	    - 20220523@Eden: LAP - Player Segmentation - Monitored Player [Redmine:#172605]

	Param's Explanation:
		@IsSub : Subsidiary Search
		@LastScanDate: time when lastest service finished

	EXEC Acc_WLMonitored_Service_GetChangedSettingList 
		@IsDeposit = 0,
		@SuperList = '',
		@IsTest = 1
	
*/  
BEGIN 
	DECLARE @CurrentDate DATETIME = CONVERT(DATE,GETDATE())

	IF ISNULL(@LastScanDate,'') = '' OR @LastScanDate < @CurrentDate 
		SET @LastScanDate = @CurrentDate

	DECLARE @SuperTbl TABLE(CustID INT PRIMARY KEY)

	INSERT INTO @SuperTbl(CustID)
	SELECT DISTINCT value FROM STRING_SPLIT(@SuperList,',') WHERE value <> ''

	CREATE TABLE #AgentChangedTbl (custid INT,roleid TINYINT,WinningThreshold money,LosingThreshold	money
								,WinningUpdateTime datetime,LosingUpdateTime datetime, SettingType TINYINT, srecommend INT)

	IF @IsDeposit = 0
	BEGIN
		---------get setting Credit
		IF @IsTest = 1
		BEGIN
			INSERT INTO #AgentChangedTbl(custid, roleid, WinningThreshold, LosingThreshold
										, WinningUpdateTime, LosingUpdateTime, SettingType, srecommend)
			SELECT ci.custid, ci.roleid, w.WinningThreshold, w.LosingThreshold
				, w.WinningUpdateTime, w.LosingUpdateTime, 1 AS SettingType
				, ci.srecommend
			FROM WLMonitored_Global w WITH(NOLOCK) 
				INNER JOIN custInfo ci WITH(NOLOCK) ON w.AgentID = ci.custid AND ci.Enabled = 1
			WHERE (w.WinningUpdateTime >= @LastScanDate OR w.LosingUpdateTime >= @LastScanDate)
				AND w.Sporttype = @Sporttype
				AND ci.srecommend IN (SELECT custid FROM @SuperTbl)
			
			--Global changed
			SELECT custid, roleid, WinningThreshold, LosingThreshold
				 , WinningUpdateTime, LosingUpdateTime, SettingType
				 , srecommend, CAST(0 AS BIT) AS IsExclude
			FROM #AgentChangedTbl
			UNION ALL --Global changed but personal not changed (or set unlimited)
			SELECT per.custid, ci.roleid, per.WinningThreshold,per.LosingThreshold
				, per.WinningUpdateTime, per.LosingUpdateTime, 2 AS SettingType
				, ci.srecommend , CAST(1 AS BIT) AS IsExclude
			FROM WLMonitored_Player per WITH(NOLOCK) 
				INNER JOIN custInfo ci WITH(NOLOCK) ON per.custid = ci.custid AND ci.Enabled = 1 AND ci.roleid = 1
			WHERE (	(per.WinningThreshold IS NULL AND per.LosingThreshold IS NULL) -- config unlimited
					 OR (per.WinningUpdateTime < @LastScanDate AND per.LosingUpdateTime < @LastScanDate)
				   )
				AND per.Sporttype = @Sporttype
				AND ci.recommend IN (SELECT custid FROM #AgentChangedTbl)
			UNION ALL --personal changed
			SELECT per.custid, ci.roleid, per.WinningThreshold,per.LosingThreshold
				, per.WinningUpdateTime, per.LosingUpdateTime, 2 AS SettingType
				, ci.srecommend , CAST(0 AS BIT) AS IsExclude
			FROM WLMonitored_Player per WITH(NOLOCK) 
				INNER JOIN custInfo ci WITH(NOLOCK) ON per.custid = ci.custid AND ci.Enabled = 1 AND ci.roleid = 1
			WHERE NOT( per.WinningThreshold IS NULL AND per.LosingThreshold IS NULL) -- config unlimited
				AND (per.WinningUpdateTime >= @LastScanDate OR per.LosingUpdateTime >= @LastScanDate)
				AND per.Sporttype = @Sporttype
				AND ci.srecommend IN (SELECT custid FROM @SuperTbl)
		END
		ELSE
		BEGIN
			INSERT INTO #AgentChangedTbl(custid, roleid, WinningThreshold, LosingThreshold
										, WinningUpdateTime, LosingUpdateTime, SettingType, srecommend)
			SELECT ci.custid, ci.roleid, w.WinningThreshold, w.LosingThreshold
				, w.WinningUpdateTime, w.LosingUpdateTime, 1 AS SettingType
				, ci.srecommend
			FROM WLMonitored_Global w WITH(NOLOCK) 
				INNER JOIN custInfo ci WITH(NOLOCK) ON w.AgentID = ci.custid AND ci.Enabled = 1
			WHERE (w.WinningUpdateTime >= @LastScanDate OR w.LosingUpdateTime >= @LastScanDate)
				AND w.Sporttype = @Sporttype
				AND ci.srecommend NOT IN (SELECT custid FROM @SuperTbl)
			
			--Global changed
			SELECT custid, roleid, WinningThreshold, LosingThreshold
				 , WinningUpdateTime, LosingUpdateTime, SettingType
				 , srecommend, CAST(0 AS BIT) AS IsExclude
			FROM #AgentChangedTbl
			UNION ALL --Global changed but personal not changed (or set unlimited)
			SELECT per.custid, ci.roleid, per.WinningThreshold,per.LosingThreshold
				, per.WinningUpdateTime, per.LosingUpdateTime, 2 AS SettingType
				, ci.srecommend , CAST(1 AS BIT) AS IsExclude
			FROM WLMonitored_Player per WITH(NOLOCK) 
				INNER JOIN custInfo ci WITH(NOLOCK) ON per.custid = ci.custid AND ci.Enabled = 1 AND ci.roleid = 1
			WHERE (	(per.WinningThreshold IS NULL AND per.LosingThreshold IS NULL) -- config unlimited
					 OR (per.WinningUpdateTime < @LastScanDate AND per.LosingUpdateTime < @LastScanDate)
				   )
				AND per.Sporttype = @Sporttype
				AND ci.recommend IN (SELECT custid FROM #AgentChangedTbl)
			UNION ALL --personal changed
			SELECT per.custid, ci.roleid, per.WinningThreshold,per.LosingThreshold
				, per.WinningUpdateTime, per.LosingUpdateTime, 2 AS SettingType
				, ci.srecommend, CAST(0 AS BIT) AS IsExclude
			FROM WLMonitored_Player per WITH(NOLOCK) 
				INNER JOIN custInfo ci WITH(NOLOCK) ON per.custid = ci.custid AND ci.Enabled = 1 AND ci.roleid = 1
			WHERE NOT( per.WinningThreshold IS NULL AND per.LosingThreshold IS NULL) -- config unlimited
				AND (per.WinningUpdateTime >= @LastScanDate OR per.LosingUpdateTime >= @LastScanDate)
				AND per.Sporttype = @Sporttype
				AND ci.srecommend NOT IN (SELECT custid FROM @SuperTbl)
		END
	END
	ELSE --get setting Deposit
	BEGIN 
		IF @IsTest = 1
		BEGIN
			SELECT per.custid, per.WinningThreshold, per.WinningUpdateTime, ci.srecommend
			FROM Dep_WLMonitored_Player per WITH(NOLOCK) 
				INNER JOIN custInfo ci WITH(NOLOCK) ON per.custid = ci.custid AND ci.roleid = 1 AND ci.Enabled = 1
			WHERE WinningUpdateTime >= @LastScanDate
				AND per.Sporttype = @Sporttype
				AND ci.srecommend IN (SELECT custid FROM @SuperTbl)
		END
		ELSE 
		BEGIN
			SELECT per.custid, per.WinningThreshold, per.WinningUpdateTime, ci.srecommend
			FROM Dep_WLMonitored_Player per WITH(NOLOCK) 
				INNER JOIN custInfo ci WITH(NOLOCK) ON per.custid = ci.custid AND ci.roleid = 1 AND ci.Enabled = 1
			WHERE WinningUpdateTime >= @LastScanDate
				AND per.Sporttype = @Sporttype
				AND ci.srecommend NOT IN (SELECT custid FROM @SuperTbl)
		END
	END

	DROP TABLE #AgentChangedTbl
END
GO