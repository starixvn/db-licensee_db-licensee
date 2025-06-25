/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerSelByCustid]
	@LicenseeName	VARCHAR(50),
	@custids		VARCHAR(MAX)	= NULL,
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
	Created by: [20190625@Johnson]
	Task: Get customer list by custids
	DB: DBEXT/bodb02
	Original: Lrf_CustomerSel
	
	Revisions:
		- 20190621@Johnson: initial sp [redmine: #112658]
		- 20200220@Louis: Cheat currency name for HID Currency [RedmineID: #128816]
		- 20200323@Vickie: Add new product Indo 4D [RedmineID: #130859]
		- 20200508@Johnson: add group comm [redmine:#131774] 
		- 20201103@Winfred: add customer class [redmine:#144706]
		- 20201005@Winfred: unshow OddsAdj dummy customers [redmine:#142952]
		- 202100203@Johnson: Search by Commission Group [redmine:#147477]
		- 20210413@Johnson: HF Set @CommGroups = NULL when search left panel [redmine:#147477]
		- 20210518@Percy: Change code to adapt new Move Bets flow [RedmineID: #154866]
		- 20210806@Johnson: extend @CustomerClass VARCHAR(1000) [redmine:#159754]
		- 20211111@Sol: Split Transfer out of bettrans/Support IPv6 - [RedmineID: #164301]
		- 20230227@Evan: Ensure correct balance calculation when allow to transfer 247 (BU) [Redmine: #173554]
		- 20240304@Johnson: HF filter Risk Level "Uncategorized" not show [redmine: #200913]
		- 20240614@Johnson: Restructure Commission [redmine:#179088]
		- 20240910@Kelvin: Integrate Odds Boost Voucher [RedmineID: #210613]
		- 20250227@Virgil: Drop BA functions [RedmineID: #216882]
		- 20250408@Kelvin: Upgrade ExchangeId Datatype [RedmineID: #222339]
		- 20250620@Kelvin: Handle Security (Dynamic Query) issue [RedmineID: #227496]

	Parameter's explanations:
		+ @SpecialLevel: default value '1,2,3,4,5,6,7,8,9,10' (all)
		+ @CustomerClass: '0,1,2,3,4,5,6,7,8,9,10,11,12,13' (all)
		+ @FullCustomerClass: '0,1,2,3,4,5,6,7,8,9,10,11,12,13' (all)
			-> CC = 0: Uncategorized
		+ @OddsGroups: Member's Odds Group
		+ @CommGroups: Member's comm group
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @currentDate DATETIME,
			@LicenseeID	INT,
			@IsUncategorizedCC BIT = 0

	SELECT  @currentDate = CONVERT(DATE, GETDATE())
	
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT

	SELECT  @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1 
	
	IF EXISTS (SELECT 1 
			FROM STRING_SPLIT(@CustomerClass,',')
			WHERE value = 0)
	SELECT @IsUncategorizedCC = 1
	
	CREATE TABLE #TempAg (custid INT PRIMARY KEY)
	CREATE TABLE #tblCustList (custid INT PRIMARY KEY)
	
	CREATE TABLE #Exchange
	(
		Id		INT PRIMARY KEY,
		Name	VARCHAR(50),
	)
	
	DECLARE @DocHandler INT

	SELECT @LicenseeID	= LicenseeID
	FROM bodb_Licensee.dbo.Licensees WITH(NOLOCK)
	WHERE LicenseeName = @LicenseeName
	
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
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	INSERT INTO #tblCustList(custid)
	SELECT val
	FROM dbo.strSplit(@custids,',')
	
	CREATE TABLE #Temp
	(
		CustId					INT PRIMARY KEY,
		Currency				SMALLINT,
		Username				NVARCHAR (50),
		Closed					BIT,
		suspended				BIT,
		nickname				NVARCHAR (50),
		SpecialLevel			INT,
		ugroup					VARCHAR(3),
		RowNumber				INT,
		CustomerClass			SMALLINT		
	)

	CREATE TABLE #tmpCust
	(
		custid	INT PRIMARY KEY,
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
		currency		SMALLINT,
		speciallevel	INT,
		username2		VARCHAR(50),
		username		VARCHAR(50),
		ugroup			VARCHAR(3),
		closed			BIT,
		reject			BIT,
		CustomerClass	SMALLINT
	)

	CREATE TABLE #TotalBalance
	(
		custid INT,
		TotalBalance MONEY,
		Outstanding MONEY
	)

	DECLARE @CustID INT, @i INT, @max INT, @LastOffBy INT

	SET @OddsGroups = ISNULL(@OddsGroups, '')
	SET @CustomerClass = ISNULL(@CustomerClass, '')

	CREATE TABLE #OddsGroupTable (val VARCHAR(10) PRIMARY KEY)
	INSERT INTO #OddsGroupTable SELECT value FROM STRING_SPLIT(@OddsGroups, ',')

	CREATE TABLE #CustomerClassTable (val INT PRIMARY KEY)
	INSERT INTO #CustomerClassTable SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@CustomerClass, ',');

	CREATE TABLE #FullCustomerClassTable (val INT PRIMARY KEY)
	INSERT INTO #FullCustomerClassTable SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@FullCustomerClass, ',');

	CREATE TABLE #SpecialLevelTable (val INT PRIMARY KEY)
	INSERT INTO #SpecialLevelTable SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@SpecialLevel, ',');

	CREATE TABLE #CommGroupsTable (val INT PRIMARY KEY)
	INSERT INTO #CommGroupsTable SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@CommGroups, ',');

	BEGIN
		INSERT INTO #tmpCust(custid, closed, reject, ugroup, CustomerClass)
		SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1), ci.CustomerClass
		FROM #TempAg t 
			INNER JOIN dbo.custInfo ci WITH(NOLOCK) ON t.custid = ci.recommend
			INNER JOIN dbo.Customer c WITH (NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid
		WHERE 
			ci.roleid=1 
			AND EXISTS (SELECT 1 FROM #tblCustList tbl WHERE tbl.custid = ci.custid)
			AND c.username NOT LIKE '%CashOut%'
			AND c.username NOT LIKE '%01OddsAdj%'
			AND c.username NOT LIKE '%01OddsBoostAdj%'
			AND (
					@OddsGroups = ''
					OR EXISTS (SELECT 1 FROM #OddsGroupTable tbl WHERE tbl.val = RIGHT(c.ugroup,1))
				)
			AND (
					@CustomerClass = ''
					OR EXISTS (SELECT 1 FROM #CustomerClassTable tbl WHERE tbl.val = ISNULL(ci.CustomerClass,0))
				)

		IF @IsUncategorizedCC = 1
		BEGIN
			INSERT INTO #tmpCust(custid, closed, reject, ugroup, CustomerClass)
			SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1), ci.CustomerClass
			FROM #TempAg t 
				INNER JOIN dbo.custInfo ci WITH(NOLOCK) ON t.custid = ci.recommend
				INNER JOIN dbo.Customer c WITH (NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid
			WHERE NOT EXISTS(SELECT 1 FROM #FullCustomerClassTable tbl WHERE tbl.val = ISNULL(ci.CustomerClass,0))
		END

		INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject,CustomerClass)
		SELECT c.CustID, lc.currency, lc.speciallevel, lc.username2, lc.username, c.ugroup, c.closed, c.reject,c.CustomerClass
		FROM
			#tmpCust c
			INNER JOIN
			(
				SELECT c.custid, c.currency, ISNULL(lc.speciallevel,0) as speciallevel, c.username, c.username2 
				FROM bodb02.dbo.Customer c WITH (NOLOCK)
					LEFT JOIN dbo.Dep_CustSpecialLevel lc WITH(NOLOCK) ON c.CustID = lc.CustID
					INNER JOIN #TempAg t ON c.recommend = t.custid
				WHERE c.RoleID = 1
			) lc ON lc.custid = c.custid
		WHERE EXISTS (SELECT 1 FROM #SpecialLevelTable tbl WHERE tbl.val = lc.speciallevel)

		IF @CommGroups IS NOT NULL
		BEGIN
			DELETE t
			FROM #TempMember t
				LEFT JOIN bodb_Licensee.dbo.LicenseeCustDiscount lc WITH (NOLOCK) ON t.custid=lc.custid AND lc.Licenseeid = @Licenseeid
			WHERE NOT EXISTS(SELECT 1 FROM #CommGroupsTable tbl WHERE tbl.val = ISNULL(lc.GroupDiscountID,0))
		END
		
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c

		INSERT INTO #Temp (custid, currency, username, closed, suspended, nickname, SpecialLevel, ugroup ,CustomerClass , RowNumber)
		SELECT * FROM 
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
	END

	-- translog
	INSERT INTO #OutstandingTranslog
	SELECT
		tl.custid,
		tl.currency,
		tl.statusID,
		SUM(actual_stake) AS actual_stacke
	FROM
		dbo.translog tl WITH (NOLOCK)
		INNER JOIN #TempAg lc ON tl.recommend = lc.CustID
		INNER JOIN @sporttype s ON s.SportType = productID
	WHERE tl.statusID IN (0, 1)		-- running and Waiting
	GROUP BY
		tl.custid,
		tl.currency,
		tl.productID,
		tl.statusID

	-- bettransRNG
	INSERT INTO #OutstandingTranslog
	SELECT
		g.custid,
		g.currency,
		g.statusID,
		SUM(g.actual_stake) AS actual_stacke
	FROM
		dbo.bettransRnG g WITH (NOLOCK)
		INNER JOIN #TempAg lc ON g.recommend = lc.CustID
	WHERE g.statusID IN (0, 1)		-- running and Waiting
	GROUP BY
		g.custid,
		g.currency,
		g.statusID

	-- bettransLC
	INSERT INTO #OutstandingTranslog
	SELECT
		g.custid,
		g.currency,
		g.statusID,
		SUM(g.actual_stake) AS actual_stacke
	FROM
		dbo.bettransLC g WITH (NOLOCK)
		INNER JOIN #TempAg lc ON g.recommend = lc.CustID
	WHERE g.statusID IN (0, 1)  -- running and Waiting
	GROUP BY
		g.custid,
		g.currency,
		g.statusID

	CREATE TABLE #data(
		CustId			INT PRIMARY KEY,
		TotalBalance	MONEY,
		Outstanding		MONEY
	)
	
	DECLARE @MBBU TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME)
	INSERT INTO @MBBU (BalanceUpDay, MoveBetsDay)
	EXEC dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay SMALLDATETIME, @BalanceUpDate SMALLDATETIME
	SELECT  @MoveBetsDay = MoveBetsDay, @BalanceUpDate = BalanceUpDay FROM @MBBU

	---insert data totalbalance
	--bettrans
	INSERT INTO #TotalBalance(custid, TotalBalance, Outstanding)
	SELECT
		t.custid,
		ISNULL(SUM(ISNULL(b.winlost - b.actual_stake + b.playercomm, 0)), 0) AS TotalBalance,
		ISNULL(SUM(CASE
					WHEN b.ruben = 0 THEN ISNULL(b.actual_stake, 0)*(CASE WHEN b.bettype = 71 THEN 0 ELSE 1 END)
					ELSE 0
				END), 0) AS Outstanding
	FROM
		#Temp t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.custid = b.custid
	WHERE b.matchid >= 0
		AND winlostdate > @MoveBetsDay
	GROUP BY t.custid

	--transfer
	INSERT INTO #TotalBalance(custid, TotalBalance, Outstanding)
	SELECT
		t.custid,
		ISNULL(SUM(ISNULL(b.winlost - b.actual_stake + b.playercomm, 0)), 0) AS TotalBalance,
		0 AS Outstanding
	FROM
		#Temp t
		INNER JOIN dbo.transfer b WITH (NOLOCK) ON t.custid = b.custid
	WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @MoveBetsDay THEN 0 --> new sum
	            WHEN bettype = 20000 AND winlostdate > @BalanceUpDate THEN 0 --> new bal
	            WHEN winlostdate < @BalanceUpDate THEN 0 --> old data
	            ELSE 1 END
	GROUP BY t.custid

	INSERT INTO #data(custid, TotalBalance, Outstanding)
	SELECT t.CustId, SUM(t.TotalBalance), SUM(t.Outstanding)
	FROM #TotalBalance t
	GROUP BY t.custid

	INSERT INTO #Exchange(Id, Name)
	EXEC dbo.Lrf_CurrencySel 
	
	SELECT
		t.custid,
		ex.Name AS currency,
		ex.Id AS exchangeid,
		t.Username,
		t.Closed,
		t.suspended,
		t.nickname,
		t.SpecialLevel,
		t.RowNumber,
		t.CustomerClass,
		ISNULL(lg.GroupName, '') AS GroupName,	
		CAST((ISNULL(d.TotalBalance, 0)	- ISNULL(tl.actual_stake,0)) AS MONEY) AS TotalBalance,
		CAST((ISNULL(d.Outstanding, 0) + ISNULL(tl.actual_stake,0)) AS MONEY) AS Outstanding,
		ISNULL(UPPER(t.ugroup), '') AS OddsGroup
	FROM #Temp t
		INNER JOIN #Exchange ex WITH (NOLOCK) ON t.currency = ex.Id
		LEFT JOIN #Data d ON t.custid = d.custid
		LEFT JOIN
		(
			SELECT
				SUM(actual_stake) actual_stake,
				Custid,
				Currency
			FROM #OutstandingTranslog
			GROUP BY Custid, Currency
		) tl ON t.custid = tl.Custid
		LEFT JOIN bodb_Licensee.dbo.LicenseeCustDiscount lc WITH (NOLOCK) ON t.custid=lc.custid AND lc.Licenseeid = @Licenseeid
		LEFT JOIN bodb_Licensee.dbo.LicenseeGroupDiscount lg WITH (NOLOCK) ON lc.GroupDiscountID = lg.GroupDiscountID			
	ORDER BY t.username

	DROP TABLE IF EXISTS #TempAg
	DROP TABLE IF EXISTS #Temp
	DROP TABLE IF EXISTS #OutstandingTranslog
	DROP TABLE IF EXISTS #Data
	DROP TABLE IF EXISTS #tmpCust
	DROP TABLE IF EXISTS #TempMember
	DROP TABLE IF EXISTS #Exchange
	DROP TABLE IF EXISTS #TotalBalance
	DROP TABLE IF EXISTS #OddsGroupTable
	DROP TABLE IF EXISTS #CustomerClassTable
	DROP TABLE IF EXISTS #FullCustomerClassTable
	DROP TABLE IF EXISTS #SpecialLevelTable
	DROP TABLE IF EXISTS #CommGroupsTable

END
GO
