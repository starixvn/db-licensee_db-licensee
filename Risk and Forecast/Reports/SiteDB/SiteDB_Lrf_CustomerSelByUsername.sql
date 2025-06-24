/*<info serverAlias="DBSID-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[SiteDB_Lrf_CustomerSelByUsername]
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
		- 20250620@Kelvin: Handle Security (Dynamic Query) issue [RedmineID: #227496]

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
			@SQL VARCHAR(MAX),
			@IsUncategorizedCC BIT = 0

	SELECT  @currentDate = CONVERT(DATE, GETDATE())

	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	
	IF EXISTS (SELECT 1 
			FROM STRING_SPLIT(@CustomerClass,',')
			WHERE value = 0)
	SELECT @IsUncategorizedCC = 1
	
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

	CREATE TABLE #TempAg (custid INT)
	CREATE TABLE #LicenseeCustDiscount (LicenseeID INT, GroupDiscountID INT, CustID INT PRIMARY KEY, GroupName VARCHAR(100))
	CREATE TABLE #Dep_CustSpecialLevel(CustID INT PRIMARY KEY, SpecialLevel INT)
	
	DECLARE @DocHandler INT
	
	SELECT @LicenseeID	= LicenseeID
	FROM DBCUST.bodb_Licensee.dbo.Licensees WITH(NOLOCK)
	WHERE LicenseeName = @LicenseeName

	DECLARE @SafeCommGroups VARCHAR(MAX) =
	(
		SELECT STRING_AGG(value, ',') 
		FROM STRING_SPLIT(@CommGroups, ',')
		WHERE TRY_CAST(value AS INT) IS NOT NULL
	)

	IF EXISTS (SELECT 1 FROM STRING_SPLIT(@SafeCommGroups,',') WHERE value = 0)
	BEGIN
		SELECT @SQL = ' SELECT LicenseeID, GroupDiscountID, CustID, GroupName
							FROM OPENQUERY (DBCUST, '' SELECT lc.LicenseeID, lc.GroupDiscountID, lc.CustID, lg.GroupName
														FROM bodb_licensee.dbo.LicenseeCustDiscount lc WITH(NOLOCK)
														LEFT JOIN bodb_Licensee.dbo.LicenseeGroupDiscount lg WITH (NOLOCK) ON lc.GroupDiscountID = lg.GroupDiscountID	
														WHERE lc.LicenseeID = ' + CAST(@LicenseeID AS VARCHAR(50)) + '
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
														WHERE lc.LicenseeID = ' + CAST(@LicenseeID AS VARCHAR(50)) + '
															AND lc.GroupDiscountID IN (SELECT value FROM STRING_SPLIT(''''' + @SafeCommGroups + ''''','''',''''))''
							)	
						'
	END
	
	INSERT INTO #LicenseeCustDiscount(LicenseeID, GroupDiscountID, CustID, GroupName)
	EXEC( @SQL)

	SELECT @SQL = 'SELECT CustID, SpecialLevel
					FROM OPENQUERY (DBCUST, ''	SELECT sl.CustID, sl.SpecialLevel 
							FROM CustDb.dbo.Dep_CustSpecialLevel sl WITH(NOLOCK)
							INNER JOIN CustDb.dbo.Customer c (NOLOCK) on c.custid = sl.custid
							INNER JOIN CustDb.dbo.Dep_CustSuper cs (NOLOCK) on cs.custid = c.srecommend
							WHERE cs.site = ''''' + @LicenseeName + '''''
						''
					)'

	INSERT INTO  #Dep_CustSpecialLevel(CustID, SpecialLevel)
	EXEC( @SQL)


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

	SET @OddsGroups = ISNULL(@OddsGroups, '')

	DECLARE @OddsGroupTable TABLE (val VARCHAR(10));
	INSERT INTO @OddsGroupTable SELECT value FROM STRING_SPLIT(@OddsGroups, ',');

	DECLARE @CustomerClassTable TABLE (val INT);
	INSERT INTO @CustomerClassTable SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@CustomerClass, ',');

	DECLARE @FullCustomerClassTable TABLE (val INT);
	INSERT INTO @FullCustomerClassTable SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@FullCustomerClass, ',');

	DECLARE @SpecialLevelTable TABLE (val INT);
	INSERT INTO @SpecialLevelTable SELECT TRY_CAST(value AS INT) FROM STRING_SPLIT(@SpecialLevel, ',');

	IF LEN(@Username) = 0
	BEGIN
		INSERT INTO #tmpCust(custid, closed, reject, ugroup, CustomerClass)
		SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1), ci.CustomerClass
		FROM #TempAg t 
			INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON t.custid = ci.recommend
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid 
		WHERE 
			ci.roleid=1 
			AND c.username NOT LIKE '%CashOut%'
			AND c.username  NOT LIKE '%01OddsAdj%'
			AND c.username  NOT LIKE '%01OddsBoostAdj%'
			AND c.username  NOT LIKE '%ClearBal%'
			AND c.username  NOT LIKE '%BetTrade%'
			AND (
					@OddsGroups = ''
					OR RIGHT(c.ugroup,1) IN (SELECT val FROM @OddsGroupTable)
				)
			AND (
					ISNULL(@CustomerClass, '') = '' 
					OR ISNULL(ci.CustomerClass,0) IN (SELECT val FROM @CustomerClassTable)
				)

		IF @IsUncategorizedCC = 1
		BEGIN
			INSERT INTO #tmpCust(custid, closed, reject, ugroup, CustomerClass)
			SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1), ci.CustomerClass
			FROM #TempAg t 
				INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON t.custid = ci.recommend
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid 
			WHERE ISNULL(ci.CustomerClass,0) NOT IN (SELECT val FROM @FullCustomerClassTable)
		END

		INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject,CustomerClass)
		SELECT c.CustID, lc.currency, lc.speciallevel, lc.username2, lc.username, c.ugroup, c.closed, c.reject,c.CustomerClass
		FROM
			#tmpCust c
			INNER JOIN 
			(SELECT c.custid, c.currency, ISNULL(lc.speciallevel,0) as speciallevel , c.username, c.username2 
				FROM CustDB.dbo.Customer c WITH (NOLOCK)
				LEFT JOIN #Dep_CustSpecialLevel lc ON c.CustID = lc.CustID
				INNER JOIN #TempAg t ON c.recommend = t.custid
				WHERE c.RoleID = 1
				) lc ON lc.custid = c.custid
		WHERE ISNULL(lc.speciallevel,0) IN (SELECT val FROM @SpecialLevelTable)

		DELETE t
		FROM #TempMember t
			LEFT JOIN #LicenseeCustDiscount lc ON t.custid=lc.custid
		WHERE ISNULL(lc.GroupDiscountID,0) NOT IN (SELECT value FROM STRING_SPLIT(@SafeCommGroups,','))		
			
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c

		INSERT INTO #Temp (custid, currency, username, closed, suspended, nickname, SpecialLevel, ugroup ,CustomerClass, RowNumber)
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
	END -- end LEN(username) = 0
	ELSE
	BEGIN
		SET @username = LTRIM(RTRIM(@username))

		INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject, CustomerClass)
		SELECT ci.custid, ci.currency, ISNULL(lc.SpecialLevel,0) as speciallevel , c.username2, c.username, RIGHT(c.ugroup, 1), ci.closed, ci.reject, ci.CustomerClass
		FROM #TempAg t
			INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.recommend = t.custid
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.custid
			LEFT JOIN #Dep_CustSpecialLevel lc ON c.custid = lc.custid
		WHERE
			c.RoleID = 1
			AND (
					(1= @searchOption AND c.username2 LIKE '%$' + @Username + '%')
					OR ( 2= @searchOption AND SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, len(c.username2)) LIKE '%' + @Username + '%')
					OR ( 3= @searchOption AND c.username2 LIKE '%$' + @Username)
					OR ( 4= @searchOption AND (c.username2 LIKE '%$' + @Username OR c.username = @Username))
				)
			AND c.username NOT LIKE '%CashOut%'
			AND c.username  NOT LIKE '%01OddsAdj%'
			AND c.username  NOT LIKE '%01OddsBoostAdj%'
			AND c.username  NOT LIKE '%ClearBal%'
			AND c.username  NOT LIKE '%BetTrade%'
			AND (
					@OddsGroups = '' 
					OR RIGHT(c.ugroup,1) IN (SELECT val FROM @OddsGroupTable)
				)
			AND ISNULL(lc.speciallevel,0) IN (SELECT val FROM @SpecialLevelTable)
			AND (
					ISNULL(@CustomerClass, '') = '' 
					OR ISNULL(ci.CustomerClass,0) IN (SELECT val FROM @CustomerClassTable)
				)

		IF @IsUncategorizedCC = 1
		BEGIN
			INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject, CustomerClass)
			SELECT ci.custid, ci.currency, ISNULL(lc.SpecialLevel,0) as speciallevel , c.username2, c.username, RIGHT(c.ugroup, 1), ci.closed, ci.reject, ci.CustomerClass
			FROM #TempAg t
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.recommend = t.custid
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.custid
				LEFT JOIN #Dep_CustSpecialLevel lc ON c.custid = lc.custid
			WHERE ISNULL(ci.CustomerClass,0) NOT IN (SELECT val FROM @FullCustomerClassTable)
		END

		DELETE t
		FROM #TempMember t
			LEFT JOIN #LicenseeCustDiscount lc ON t.custid=lc.custid 
		WHERE ISNULL(lc.GroupDiscountID,0) NOT IN (SELECT value FROM STRING_SPLIT(@SafeCommGroups,','))		
		
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
	INSERT INTO #OutstandingTranslog
	SELECT tl.custid, tl.currency, statusID, SUM(actual_stake) actual_stacke
	FROM
		dbo.translog tl WITH (NOLOCK)
		INNER JOIN #Temp cl on cl.custid = tl.custid
		INNER JOIN @sporttype s ON s.SportType = productID
	WHERE
		statusID IN (0, 1)  --running and Waiting
	GROUP BY tl.custid, tl.currency, productID, statusID

	--- bettransRNG
	INSERT INTO #OutstandingTranslog
	SELECT g.custid, g.currency, statusID, SUM(g.actual_stake) actual_stacke
	FROM
		dbo.bettransRnG g WITH (NOLOCK)
		INNER JOIN #Temp cl on cl.custid = g.custid
	WHERE g.statusID IN (0, 1)  --running and Waiting
	GROUP BY g.custid, g.currency, statusID

	--- bettransLC
	INSERT INTO #OutstandingTranslog
	SELECT g.custid, g.currency, statusID, SUM(g.actual_stake) actual_stacke
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
		
	ORDER BY t.username

END
GO
