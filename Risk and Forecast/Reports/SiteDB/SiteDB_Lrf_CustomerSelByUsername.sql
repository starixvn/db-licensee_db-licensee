/*<info serverAlias="DBSID-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_Lrf_CustomerSelByUsername]
	@LicenseeName	VARCHAR(50),
	@username		VARCHAR(50)		= NULL,
	@SearchOption	TINYINT			= 0,
	@PageSize		INT				= 50,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT,
	@SpecialLevel	VARCHAR(100)	= '',
	@OddsGroups		VARCHAR(100)	= '',
	@CustomerClass	VARCHAR(1000)	= NULL,
	@FullCustomerClass	VARCHAR(1000)	= NULL,
	@CommGroups		VARCHAR(1000)	= '',
	@AgentList		VARCHAR(MAX)
AS

/*
	Created by: [20220801@Sol]
	Task: Get customer list by custids
	DB: DBSID/bodb02
	
	Revisions:
		- 20220801@Sol: initial sp - [Redmine: #175297]
		- 20221109@Danny: Enhance performance [Redmine: #180045]
		- 20230227@Evan: Ensure correct balance calculation when allow to transfer 247 (BU) [Redmine: #173554]
		- 20240304@Johnson: HF filter Risk Level "Uncategorized" not show [redmine: #200913]
		- 20240318@Bobby: LAP EC enhancement - [RedmineID: #191592]
		- 20240318@Bobby: HF - Filter SpecialLevel - [RedmineID: #208328]
		- 20240618@Johnson: Restructure Commission [redmine:#179088]
		- 20240910@Kelvin: Integrate Odds Boost Voucher [RedmineID: #210613]
		- 20250227@Virgil: Drop BA functions [RedmineID: #216882]
		- 20250408@Kelvin: Upgrade ExchangeId Datatype [RedmineID: #222339]
		- 20251121@Tacy: Enhance performance [Redmine: #245015]

	Parameter's explanations:
		+ @SpecialLevel: '1,2,3,4,5,6,7,8,9,10' (all)
		+ @CustomerClass: '0,1,2,3,4,5,6,7,8,9,10,11,12,13' (all)
		+ @FullCustomerClass: '0,1,2,3,4,5,6,7,8,9,10,11,12,13' (all)
			-> CC = 0: Uncategorized
		+ @OddsGroups: Member's Odds Group
		+ @CommGroups: Member's comm group
		+ @searchOption: 1- Match prefix
						 2- Match case
						 3- Quick search
						 4- Match Precise and System ID
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @currentDate DATETIME,
			@LicenseeID	INT,
			@SQL NVARCHAR(MAX),
			@IsUncategorizedCC BIT = 0

	SELECT  @currentDate = CONVERT(DATE, GETDATE())

	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	
	SELECT  @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1 

	--TODO: temp tables
	DROP TABLE IF EXISTS #TempAg
	DROP TABLE IF EXISTS #Temp
	DROP TABLE IF EXISTS #OutstandingTranslog
	DROP TABLE IF EXISTS #Data
	DROP TABLE IF EXISTS #tmpCust
	DROP TABLE IF EXISTS #TempMember
	DROP TABLE IF EXISTS #Exchange
	DROP TABLE IF EXISTS #TotalBalance
	DROP TABLE IF EXISTS #LicenseeCustDiscount
	DROP TABLE IF EXISTS #Dep_CustSpecialLevel
	DROP TABLE IF EXISTS #tmpCommGroups
	DROP TABLE IF EXISTS tmpAgentCust
	DROP TABLE IF EXISTS tmpAgentCust_Batch

	-- Large temp tables
	CREATE TABLE #TempAg (custid INT PRIMARY KEY CLUSTERED)
	CREATE TABLE #LicenseeCustDiscount (CustID INT PRIMARY KEY CLUSTERED, LicenseeID INT, GroupDiscountID INT, GroupName VARCHAR(100))
	CREATE TABLE #Dep_CustSpecialLevel(CustID INT PRIMARY KEY CLUSTERED, SpecialLevel INT)

	-- Small table variables for parameter parsing
	CREATE TABLE #tmpCommGroups (GroupDiscountID INT PRIMARY KEY CLUSTERED)
	DECLARE @tmpSpecialLevel TABLE (SpecialLevel INT PRIMARY KEY)
	DECLARE @tmpOddsGroups TABLE (OddsGroup VARCHAR(3) PRIMARY KEY)
	DECLARE @tmpCustomerClass TABLE (CustomerClass SMALLINT PRIMARY KEY)
	DECLARE @tmpFullCustomerClass TABLE (CustomerClass SMALLINT PRIMARY KEY)

	DECLARE @DocHandler INT
	
	SELECT @LicenseeID	= LicenseeID
	FROM DBCUST.bodb_Licensee.dbo.Licensees WITH(NOLOCK)
	WHERE LicenseeName = @LicenseeName

	-- Populate table variables for parameter parsing
	INSERT INTO #tmpCommGroups (GroupDiscountID)
	SELECT CONVERT(INT, value) 
	FROM STRING_SPLIT(@CommGroups, ',')
	WHERE TRIM(value) <> '';

	INSERT INTO @tmpSpecialLevel (SpecialLevel)
	SELECT CONVERT(INT, value)
	FROM STRING_SPLIT(@SpecialLevel, ',')
	WHERE TRIM(value) <> '';

	INSERT INTO @tmpOddsGroups (OddsGroup)
	SELECT TRIM(value)
	FROM STRING_SPLIT(@OddsGroups, ',')
	WHERE TRIM(value) <> '';

	INSERT INTO @tmpCustomerClass (CustomerClass)
	SELECT CONVERT(SMALLINT, value)
	FROM STRING_SPLIT(@CustomerClass, ',')
	WHERE TRIM(value) <> '';

	INSERT INTO @tmpFullCustomerClass (CustomerClass)
	SELECT CONVERT(SMALLINT, value)
	FROM STRING_SPLIT(@FullCustomerClass, ',')
	WHERE TRIM(value) <> '';

	IF EXISTS (SELECT 1 FROM @tmpCustomerClass
			   WHERE CustomerClass = 0)
		SELECT @IsUncategorizedCC = 1

	IF EXISTS (SELECT 1 FROM #tmpCommGroups WHERE GroupDiscountID = 0)
	BEGIN
		SELECT @SQL = ' SELECT LicenseeID, GroupDiscountID, CustID, GroupName
							FROM OPENQUERY (DBCUST, '' SELECT lc.LicenseeID, lc.GroupDiscountID, lc.CustID, lg.GroupName
														FROM bodb_licensee.dbo.LicenseeCustDiscount lc WITH(NOLOCK)
														LEFT JOIN bodb_Licensee.dbo.LicenseeGroupDiscount lg WITH (NOLOCK) ON lc.GroupDiscountID = lg.GroupDiscountID	
														WHERE lc.LicenseeID = ' +CAST(@LicenseeID AS VARCHAR(50)) + '
															AND lc.GroupDiscountID <> 0''
							)	
						'
	END
	ELSE
	BEGIN
		SELECT @SQL = ' SELECT LicenseeID, GroupDiscountID, CustID, GroupName
							FROM OPENQUERY (DBCUST, '' SELECT lc.LicenseeID, lc.GroupDiscountID, lc.CustID, lg.GroupName
														FROM bodb_licensee.dbo.LicenseeCustDiscount lc WITH(NOLOCK)
														LEFT JOIN bodb_Licensee.dbo.LicenseeGroupDiscount lg WITH (NOLOCK) ON lc.GroupDiscountID = lg.GroupDiscountID	
														WHERE lc.LicenseeID = ' +CAST(@LicenseeID AS VARCHAR(50)) + '
															AND lc.GroupDiscountID IN (SELECT value FROM STRING_SPLIT('''''+@CommGroups+''''','''',''''))''
							)	
						'
	END
	
	INSERT INTO #LicenseeCustDiscount(LicenseeID, GroupDiscountID, CustID, GroupName)
	EXEC sp_executesql @SQL

	SELECT @SQL = 'SELECT CustID, SpecialLevel
					FROM OPENQUERY (DBCUST, ''	SELECT sl.CustID, sl.SpecialLevel 
							FROM CustDb.dbo.Dep_CustSpecialLevel sl WITH(NOLOCK)
							INNER JOIN CustDb.dbo.Customer c (NOLOCK) on c.custid = sl.custid
							INNER JOIN CustDb.dbo.Dep_CustSuper cs (NOLOCK) on cs.custid = c.srecommend
							WHERE cs.site = '''''+@LicenseeName+'''''
						''
					)'

	INSERT INTO  #Dep_CustSpecialLevel(CustID, SpecialLevel)
	EXEC sp_executesql @SQL

	DECLARE @sporttype	TABLE (SportType INT)

	INSERT INTO @sporttype ( SportType )
	SELECT DISTINCT SportType FROM [dbo].[SportBettypeMatrix] WITH (NOLOCK)
	WHERE RefTable = 3
	
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [INT], Currency SMALLINT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;
 
	SET @Username = ISNULL(@Username, '')

	CREATE TABLE #tmpAgentCust		 (custid INT PRIMARY KEY CLUSTERED)
	CREATE TABLE #tmpAgentCust_Batch (custid INT PRIMARY KEY CLUSTERED)

	CREATE TABLE #Temp
	(
		custid					INT PRIMARY KEY,
		currency 				SMALLINT,
		username				NVARCHAR (50),
		closed					BIT,
		suspended				BIT,
		nickname				NVARCHAR (50),
		SpecialLevel			INT,
		ugroup					VARCHAR(3),
		RowNumber				INT ,
		CustomerClass			SMALLINT
	)

	CREATE TABLE #tmpCust
	(
		custid	INT PRIMARY KEY CLUSTERED,
		closed	BIT,
		reject	BIT,
		ugroup	VARCHAR(3),
		CustomerClass SMALLINT
	)

	CREATE TABLE #OutstandingTranslog
	(
		Custid			INT,
		Currency		SMALLINT,
		statusID		TINYINT,
		actual_stake	MONEY
	)

	CREATE TABLE #TempMember
	(
		CustID			INT PRIMARY KEY CLUSTERED,
		currency 		SMALLINT,
		speciallevel	INT,
		username2		VARCHAR(50),
		username		VARCHAR(50),
		ugroup			VARCHAR(3),
		closed			BIT,
		reject			BIT,
		CustomerClass	SMALLINT
	)

	CREATE TABLE #Exchange
	(
		Id		INT PRIMARY KEY,
		Name	VARCHAR(50),
	)

	CREATE TABLE #TotalBalance
	(
		custid INT,
		TotalBalance MONEY,
		Outstanding MONEY
	)

	DECLARE @CustID INT, @i INT, @max INT, @LastOffBy INT
	DECLARE @HasOddsGroupFilter BIT = CASE WHEN EXISTS(SELECT 1 FROM @tmpOddsGroups) THEN 1 ELSE 0 END
	DECLARE @HasCustomerClassFilter BIT = CASE WHEN EXISTS(SELECT 1 FROM @tmpCustomerClass) THEN 1 ELSE 0 END

	IF LEN(@Username) = 0
	BEGIN
		INSERT INTO #tmpAgentCust (custid)
		SELECT c.custid
		FROM CustDB.dbo.custInfo c WITH (NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #TempAg t WHERE t.custid = c.recommend)
			AND c.RoleID = 1	

		WHILE (1=1)
		BEGIN
			TRUNCATE TABLE #tmpAgentCust_Batch

			DELETE TOP (2000) T
			OUTPUT deleted.CustId INTO #tmpAgentCust_Batch
			FROM #tmpAgentCust T

			IF @@ROWCOUNT=0
				BREAK;

			-- Optimized query using temp table joins instead of dynamic SQL
			INSERT INTO #tmpCust(custid, closed, reject, ugroup, CustomerClass)
			SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1), ci.CustomerClass
			FROM #tmpAgentCust_Batch t 
				INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON t.custid = ci.custid
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid 
				LEFT JOIN @tmpOddsGroups og ON RIGHT(c.ugroup, 1) = og.OddsGroup
				LEFT JOIN @tmpCustomerClass cc ON ISNULL(ci.CustomerClass, 0) = cc.CustomerClass
				LEFT JOIN @tmpFullCustomerClass fcc ON ISNULL(ci.CustomerClass, 0) = fcc.CustomerClass
			WHERE ci.roleid = 1 
				AND c.username NOT LIKE '%CashOut%'
				AND c.username NOT LIKE '%01OddsAdj%'
				AND c.username NOT LIKE '%01OddsBoostAdj%'
				AND c.username NOT LIKE '%ClearBal%'
				AND c.username NOT LIKE '%BetTrade%'	
				AND (@HasOddsGroupFilter = 0 OR og.OddsGroup IS NOT NULL)
				AND (
					@HasCustomerClassFilter = 0 
					OR cc.CustomerClass IS NOT NULL
					OR (@IsUncategorizedCC = 1 AND fcc.CustomerClass IS NULL)
				)
		END

		-- Optimized TempMember insert using temp table joins
		INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject, CustomerClass)
		SELECT c.CustID, c2.currency, ISNULL(sl.SpecialLevel, 0), c2.username2, c2.username, c.ugroup, c.closed, c.reject, c.CustomerClass
		FROM #tmpCust c
			INNER JOIN CustDB.dbo.Customer c2 WITH (NOLOCK) ON c.custid = c2.custid
			INNER JOIN #TempAg t ON c2.recommend = t.custid
			LEFT JOIN #Dep_CustSpecialLevel sl ON c2.CustID = sl.CustID
			INNER JOIN @tmpSpecialLevel tsl ON ISNULL(sl.SpecialLevel, 0) = tsl.SpecialLevel
		WHERE c2.RoleID = 1
			
		DELETE t
		FROM #TempMember t
			LEFT JOIN #LicenseeCustDiscount lc ON t.custid=lc.custid
		WHERE NOT EXISTS (SELECT 1 
						  FROM #tmpCommGroups cg 
						  WHERE ISNULL(lc.GroupDiscountID, 0) = cg.GroupDiscountID
						)		
						
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c

		INSERT INTO #Temp (custid, currency, username, closed, suspended, nickname, SpecialLevel, ugroup ,CustomerClass, RowNumber)
		SELECT custid, currency, username, closed, suspended, nickname, SpecialLevel, ugroup ,CustomerClass, RowNumber
		FROM 
		(
			SELECT 
				m.custid, 
				m.currency,
				m.username, 
				m.closed,
				ISNULL(m.reject,0) AS suspended,
				SUBSTRING(m.username2, CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
				m.SpecialLevel, 
				m.ugroup,
				m.CustomerClass,
				ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
			FROM
				#TempMember m 
		) a 
		WHERE a.rownumber BETWEEN @rowstart AND @rowend
	END -- end LEN(username) = 0
	ELSE
	BEGIN
		SET @username = TRIM(@username)

		-- Optimized username search using temp table joins instead of dynamic SQL
		INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject, CustomerClass)
		SELECT ci.custid, ci.currency, ISNULL(sl.SpecialLevel, 0), c.username2, c.username, RIGHT(c.ugroup, 1), ci.closed, ci.reject, ci.CustomerClass
		FROM #TempAg t
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.recommend = t.custid
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.custid
			LEFT JOIN #Dep_CustSpecialLevel sl ON c.custid = sl.custid
			LEFT JOIN @tmpOddsGroups og ON RIGHT(c.ugroup, 1) = og.OddsGroup
			LEFT JOIN @tmpCustomerClass cc ON ISNULL(ci.CustomerClass, 0) = cc.CustomerClass
			LEFT JOIN @tmpFullCustomerClass fcc ON ISNULL(ci.CustomerClass, 0) = fcc.CustomerClass
			INNER JOIN @tmpSpecialLevel tsl ON ISNULL(sl.SpecialLevel, 0) = tsl.SpecialLevel
		WHERE 
			c.RoleID = 1
			AND (
				(@searchOption = 1 AND c.username2 LIKE '%$' + @Username + '%') 
				OR (@searchOption = 2 AND SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2)) LIKE '%' + @Username + '%') 
				OR (@searchOption = 3 AND c.username2 LIKE '%$' + @Username)
				OR (@searchOption = 4 AND (c.username2 LIKE '%$' + @Username OR c.username = @Username))
			)
			AND c.username NOT LIKE '%CashOut%'
			AND c.username NOT LIKE '%01OddsAdj%'
			AND c.username NOT LIKE '%01OddsBoostAdj%'
			AND c.username NOT LIKE '%ClearBal%'
			AND c.username NOT LIKE '%BetTrade%'	
			AND (@HasOddsGroupFilter = 0 OR og.OddsGroup IS NOT NULL)
			AND (
				@HasCustomerClassFilter = 0 
				OR cc.CustomerClass IS NOT NULL
				OR (@IsUncategorizedCC = 1 AND fcc.CustomerClass IS NULL)
			)
		
		DELETE t
		FROM #TempMember t
			LEFT JOIN #LicenseeCustDiscount lc ON t.custid=lc.custid 
		WHERE NOT EXISTS (SELECT 1 
						  FROM #tmpCommGroups cg 
						  WHERE ISNULL(lc.GroupDiscountID, 0) = cg.GroupDiscountID
						)		
		
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c

		INSERT INTO #Temp (custid, currency, username, closed, suspended, nickname, SpecialLevel, ugroup,CustomerClass, RowNumber)
		SELECT a.custid, a.currency, a.username, a.closed, a.suspended, a.nickname, a.SpecialLevel, a.ugroup,a.CustomerClass, a.RowNumber
		FROM 
			(
				SELECT m.custid,
					m.currency,
					m.username, 
					m.closed,
					ISNULL(m.reject, 0) AS suspended,
					SUBSTRING(m.username2,  CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
					m.SpecialLevel,
					m.ugroup,
					m.CustomerClass,
					ROW_NUMBER() OVER (ORDER BY ci.currency ASC, ci.custid ASC) AS RowNumber 
				FROM #TempMember m
					INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON m.CustID = ci.custid
			) a 
		WHERE a.rownumber BETWEEN @rowstart AND @rowend
	END


	-- translog
	INSERT INTO #OutstandingTranslog (Custid, Currency, statusID, actual_stake)
	SELECT tl.custid, tl.currency, statusID, SUM(actual_stake) AS actual_stacke
	FROM
		dbo.translog tl WITH (NOLOCK)
		INNER JOIN #Temp cl on cl.custid = tl.custid
		INNER JOIN @sporttype s ON s.SportType = productID
	WHERE
		statusID IN (0, 1)  --running and Waiting
	GROUP BY tl.custid, tl.currency, productID, statusID

	--- bettransRNG
	INSERT INTO #OutstandingTranslog (Custid, Currency, statusID, actual_stake)
	SELECT g.custid, g.currency, statusID, SUM(g.actual_stake) AS actual_stacke
	FROM
		dbo.bettransRnG g WITH (NOLOCK)
		INNER JOIN #Temp cl on cl.custid = g.custid
	WHERE g.statusID IN (0, 1)  --running and Waiting
	GROUP BY g.custid, g.currency, statusID

	--- bettransLC
	INSERT INTO #OutstandingTranslog (Custid, Currency, statusID, actual_stake)
	SELECT g.custid, g.currency, statusID, SUM(g.actual_stake) AS actual_stacke
	FROM
		dbo.bettransLC g WITH (NOLOCK)
		INNER JOIN #Temp cl on cl.custid = g.custid
	WHERE g.statusID IN (0, 1)  --running and Waiting
	GROUP BY g.custid, g.currency, statusID

	CREATE TABLE #data(
		custid INT PRIMARY KEY,
		TotalBalance MONEY,
		Outstanding MONEY
	)

	--TODO: get MBU days
	DECLARE @MoveBetsDay SMALLDATETIME,	@BalanceUpDay SMALLDATETIME
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @MoveBetsDay OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @BalanceUpDay OUTPUT

	---insert data totalbalance
	--bettrans
	INSERT INTO #TotalBalance(custid, TotalBalance, Outstanding)
	SELECT 
		t.custid,
		ISNULL(SUM(ISNULL(b.winlost-b.actual_stake + b.playercomm, 0)), 0) AS TotalBalance,
		ISNULL(SUM(CASE WHEN ruben = 0 THEN ISNULL(b.actual_stake, 0)*(CASE WHEN b.bettype = 71 THEN 0 ELSE 1 END) ELSE 0 END), 0) AS Outstanding
	FROM
		#Temp t
		INNER JOIN bettrans b WITH(NOLOCK) ON t.custid = b.custid
	WHERE b.matchid >= 0
		AND winlostdate > @MoveBetsDay
	GROUP BY t.custid

	--transfer
	INSERT INTO #TotalBalance(custid, TotalBalance, Outstanding)
	SELECT 
		t.custid,
		ISNULL(SUM(ISNULL(b.winlost-b.actual_stake + b.playercomm, 0)), 0) AS TotalBalance,
		0 AS Outstanding
	FROM
		#Temp t
		INNER JOIN dbo.Transfer b WITH(NOLOCK) ON t.custid = b.custid
	WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @MoveBetsDay THEN 0 --> new sum
	            WHEN bettype = 20000 AND winlostdate > @BalanceUpDay THEN 0 --> new bal
	            WHEN winlostdate < @BalanceUpDay THEN 0 --> old data
	            ELSE 1 END
	GROUP BY t.custid

	INSERT INTO #data(custid, TotalBalance,Outstanding)
	SELECT t.custid, SUM(t.TotalBalance), SUM(t.Outstanding)
	FROM #TotalBalance t
	GROUP BY t.custid

	INSERT INTO #Exchange(Id, Name)
	EXEC SiteDB_Lrf_CurrencySel 

	SELECT
		t.custid,
		ex.Name AS currency,
		ex.Id AS exchangeid,
		username,
		closed,
		suspended,
		nickname,
		SpecialLevel,
		ISNULL(lc.GroupName, '') AS GroupName,		
		RowNumber,
		t.CustomerClass,
		CAST((ISNULL(d.TotalBalance, 0)	- ISNULL(tl.actual_stake,0)) AS MONEY) AS TotalBalance ,
		CAST((ISNULL(d.Outstanding, 0)	+ ISNULL(tl.actual_stake,0)) AS MONEY) AS Outstanding,
		ISNULL(UPPER(t.ugroup), '') AS OddsGroup
	FROM #Temp t
		INNER JOIN #Exchange ex WITH(NOLOCK ) ON t.currency = ex.Id
		LEFT JOIN #Data d ON t.custid = d.custid
		LEFT JOIN
		(
			SELECT
				SUM(actual_stake) actual_stake,
				Custid,
				Currency
			FROM #OutstandingTranslog
			GROUP BY Custid, Currency
		)tl ON t.custid = tl.Custid
		LEFT JOIN #LicenseeCustDiscount lc  ON t.custid=lc.custid
		
	ORDER BY t.username ASC

END
GO
