/*<info serverAlias="DBSID-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SiteDB_Lrf_CustomerSelByCustid]
(
	@LicenseeName	VARCHAR(50),
	@custids		VARCHAR(MAX)	= NULL,
	@PageSize		INT				= 50,
	@PageIndex		INT				= 1,
	@BAFilter		SMALLINT		= 0,
	@TotalRows		INT				= 0 OUTPUT,
	@SpecialLevel	VARCHAR(100)	= '',
	@OddsGroups		VARCHAR(100)	= '',
	@CustomerClass	VARCHAR(1000)	= NULL,
	@FullCustomerClass	VARCHAR(1000)	= NULL,
	@CommGroups		VARCHAR(1000)	= '',
	@AgentList		VARCHAR(MAX)
)
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
		- 20240910@Kelvin: Support Odds Boost Voucher [RedmineID: #199292]
	Parameter's explanations:
		+ @BAFilter: support filter BA members (0: both BA + non BA, 1: BA Members only, 2: non-BA members)
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
			@SQL VARCHAR(MAX),
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
	
	--TODO: temp tables
	DROP TABLE IF EXISTS #TempAg
	DROP TABLE IF EXISTS #tblCustList
	DROP TABLE IF EXISTS #Temp
	DROP TABLE IF EXISTS #OutstandingTranslog
	DROP TABLE IF EXISTS #Data
	DROP TABLE IF EXISTS #tmpCust
	DROP TABLE IF EXISTS #TempMember
	DROP TABLE IF EXISTS #Exchange
	DROP TABLE IF EXISTS #TotalBalance
	DROP TABLE IF EXISTS #LicenseeCustComm
	DROP TABLE IF EXISTS #Dep_CustSpecialLevel
	DROP TABLE IF EXISTS #LicenseeBAHistory

	CREATE TABLE #TempAg (custid INT)
	CREATE TABLE #tblCustList (custid INT PRIMARY KEY)
	CREATE TABLE #LicenseeCustDiscount (LicenseeID INT, GroupDiscountID INT, CustID INT PRIMARY KEY, GroupName VARCHAR(100))
	CREATE TABLE #Dep_CustSpecialLevel(CustID INT PRIMARY KEY, SpecialLevel INT)
	CREATE TABLE #LicenseeBAHistory(CustID INT, Status VARCHAR(50), OffBy INT, ID INT)
	
	CREATE TABLE #Exchange
	(
		Id		INT PRIMARY KEY,
		Name	VARCHAR(50),
	)
	
	DECLARE @DocHandler INT

	SELECT @LicenseeID	= LicenseeID
	FROM DBCUST.bodb_Licensee.dbo.Licensees l WITH(NOLOCK)
	WHERE LicenseeName = @LicenseeName

	SELECT @SQL = ' SELECT LicenseeID, GroupDiscountID, CustID, GroupName
						FROM OPENQUERY (DBCUST, '' SELECT lc.LicenseeID, lc.GroupDiscountID, lc.CustID, lg.GroupName
													FROM bodb_licensee.dbo.LicenseeCustDiscount lc WITH(NOLOCK)
													LEFT JOIN bodb_Licensee.dbo.LicenseeGroupDiscount lg WITH (NOLOCK) ON lc.GroupDiscountID = lg.GroupDiscountID	
													WHERE lc.LicenseeID = ' +CAST(@LicenseeID AS VARCHAR(50)) + '
													AND lc.CustID IN (SELECT value FROM STRING_SPLIT('''''+@custids+''''','''',''''))
													AND lc.GroupDiscountID IN (SELECT value FROM STRING_SPLIT('''''+@CommGroups+''''','''',''''))''
						)
					'
	INSERT INTO #LicenseeCustDiscount(LicenseeID, GroupDiscountID, CustID, GroupName)
	EXEC( @SQL)

	SELECT @SQL = ' SELECT CustID, SpecialLevel
					FROM OPENQUERY (DBCUST, ''	SELECT sl.CustID, sl.SpecialLevel 
												FROM CustDb.dbo.Dep_CustSpecialLevel sl WITH(NOLOCK)
												WHERE sl.CustID IN (SELECT value FROM STRING_SPLIT('''''+@custids+''''','''',''''))
											''
					)'
	INSERT INTO  #Dep_CustSpecialLevel(CustID, SpecialLevel)
	EXEC( @SQL)

	SELECT @SQL = ' SELECT CustID, status, OffBy, ID
						FROM OPENQUERY (DBCUST, '' SELECT CustID, status, OffBy, ID
													FROM bodb_licensee.dbo.LicenseeBAHistory lc WITH(NOLOCK)
													WHERE LicenseeID = ' +CAST(@LicenseeID AS VARCHAR(50)) + '
															AND CustID IN (SELECT value FROM STRING_SPLIT('''''+@custids+''''','''',''''))
												''
						)
					'
	INSERT INTO  #LicenseeBAHistory(CustID, status, OffBy, ID)
	EXEC( @SQL)

	DECLARE @sporttype	TABLE (SportType INT)

	INSERT INTO @sporttype ( SportType )
	SELECT DISTINCT SportType 
	FROM [dbo].[SportBettypeMatrix] l WITH(NOLOCK)
	WHERE RefTable = 3

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [INT], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	INSERT INTO #tblCustList(custid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@custids,',')
	
	CREATE TABLE #Temp
	(
		CustId					INT PRIMARY KEY,
		Currency				TINYINT,
		Username				NVARCHAR (50),
		Closed					BIT,
		suspended				BIT,
		nickname				NVARCHAR (50),
		BAStatus				BIT,
		SpecialLevel			INT,
		IsPowerBAUserTurnoff	BIT,
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
		Currency		INT,
		statusID		TINYINT,
		actual_stake	MONEY
	)

	CREATE TABLE #TempMember
	(
		CustID			INT PRIMARY KEY CLUSTERED,
		currency		TINYINT,
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

	DECLARE @TempBACust TABLE
	(
		ID		INT IDENTITY(1, 1),
		CustID	INT
	)

	DECLARE @CustID INT, @i INT, @max INT, @LastOffBy INT

	SET @OddsGroups = ISNULL(@OddsGroups, '')
	--For predicate pushdown
	DECLARE @OddsGroupsC VARCHAR (100)
	SELECT @OddsGroupsC = '''' + REPLACE(@OddsGroups, ',', ''',''') + ''''
	DECLARE @strSQL NVARCHAR(MAX)

	IF @BAFilter = 0 
	BEGIN	
		SELECT @strSQL = 'INSERT INTO #tmpCust(custid, closed, reject, ugroup,CustomerClass)
		SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1),ci.CustomerClass
		FROM #TempAg t 
			 INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON t.custid = ci.recommend
			 INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid 
		WHERE ci.roleid=1
				AND ci.custid IN (SELECT custid FROM #tblCustList)
				AND c.username  NOT LIKE ''%CASHOUT%''
				AND c.username  NOT LIKE ''%01OddsAdj%''
				AND c.username  NOT LIKE ''%01OddsBoostAdj%''
				AND (''' + @OddsGroups + ''' = '''' OR RIGHT(c.ugroup,1) IN (' + @OddsGroupsC + '))'
				
		IF ISNULL(@CustomerClass, '') <> ''
		BEGIN
			SET @strSQL = @strSQL + 'AND ISNULL(ci.CustomerClass,0) IN  (' +  @CustomerClass + ')' +
							CASE WHEN @IsUncategorizedCC = 1 THEN ' OR ISNULL(ci.CustomerClass,0) NOT IN ('+  @FullCustomerClass + ')'
										ELSE '' END
		END 		
			
		--EXEC sp_executesql @strSQL
		EXEC (@strSQL)

		SELECT @strSQL = 'INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject,CustomerClass)
		SELECT c.CustID, lc.currency, lc.speciallevel, lc.username2, lc.username, c.ugroup, c.closed, c.reject,c.CustomerClass
		FROM
			#tmpCust c
			INNER JOIN 
			(SELECT lci.custid, lci.currency, ISNULL(lc.speciallevel,0) as speciallevel, lci.username, lci.username2 
			 FROM CustDB.dbo.Customer lci WITH(NOLOCK) 
				 INNER JOIN #TempAg t ON lci.recommend = t.custid
				 LEFT JOIN #Dep_CustSpecialLevel lc ON lc.CustID = lci.CustID
			 WHERE lci.RoleID = 1 
			 ) lc ON lc.custid = c.custid
		WHERE 
			ISNULL(lc.speciallevel,0) IN  (' +  @SpecialLevel + ')'

		--EXEC sp_executesql @strSQL
		EXEC (@strSQL)
		
		IF @CommGroups IS NOT NULL
		BEGIN
			DELETE t
			FROM #TempMember t
				LEFT JOIN #LicenseeCustDiscount lc ON t.custid=lc.custid 
			WHERE ISNULL(lc.GroupDiscountID,0) NOT IN (SELECT value FROM STRING_SPLIT(@CommGroups,','))		
		END 
		
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c

		INSERT INTO #Temp (custid, currency, username, closed, suspended, nickname, BAStatus, SpecialLevel, ugroup, RowNumber,CustomerClass)
		SELECT t.custid, t.currency, t.username, t.closed, t.suspended, t.nickname, CASE WHEN lb.CustID IS NULL THEN 0 ELSE 1 END AS BAStatus, t.speciallevel, t.ugroup, t.RowNumber ,t.CustomerClass 
		FROM
			(
				SELECT a.custid, a.currency, a.username, a.closed, a.suspended, a.nickname, a.speciallevel, a.ugroup, a.CustomerClass, a.RowNumber  
				FROM
				(
					SELECT 
						m.custid, 
						m.currency,
						m.username, 
						m.closed,
						ISNULL(m.reject,0) AS suspended,
						SUBSTRING(m.username2,  CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
						m.SpecialLevel,
						m.ugroup,
						m.CustomerClass,
						ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
					FROM
						#TempMember m
				) a 
				WHERE a.rownumber BETWEEN @rowstart AND @rowend
			) t
			LEFT JOIN #LicenseeBAHistory lb ON t.CustID = lb.CustID AND lb.[Status] = 'Running'
	END
	ELSE IF @BAFilter = 1
	BEGIN
		SELECT @strSQL = 'INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject,CustomerClass)
						  SELECT ci.CustID, ci.currency, ISNULL(lc.speciallevel,0)  as speciallevel, cu.username2, cu.username, RIGHT(cu.ugroup, 1), ci.closed, ci.reject,ci.CustomerClass
						  FROM #LicenseeBAHistory lb
							INNER JOIN CustDB.dbo.CustInfo ci WITH(NOLOCK) ON lb.custid = ci.custid
							INNER JOIN CustDB.dbo.Customer cu WITH(NOLOCK) ON ci.CustID = cu.custid 
							INNER JOIN #TempAg t ON ci.recommend = t.custid
							LEFT JOIN #Dep_CustSpecialLevel lc ON ci.custid = lc.custid								
						 WHERE  lb.[Status] = ''Running''
							AND ci.custid IN (SELECT custid FROM #tblCustList)		
							AND (''' + @OddsGroups + ''' = '''' OR RIGHT(cu.ugroup,1) IN (' + @OddsGroupsC + '))
							AND ISNULL(lc.speciallevel,0) IN  (' +  @SpecialLevel + ') '
							
		IF ISNULL(@CustomerClass, '') <> ''
		BEGIN
			SET @strSQL = @strSQL + 'AND ISNULL(ci.CustomerClass,0) IN  (' +  @CustomerClass + ')' +
							CASE WHEN @IsUncategorizedCC = 1 THEN ' OR ISNULL(ci.CustomerClass,0) NOT IN ('+  @FullCustomerClass + ')'
										ELSE '' END
		END 
		
		--EXEC sp_executesql @strSQL
		EXEC (@strSQL)
		
		IF @CommGroups IS NOT NULL
		BEGIN
			DELETE t
			FROM #TempMember t
				LEFT JOIN #LicenseeCustDiscount lc WITH(NOLOCK) ON t.custid=lc.custid
			WHERE ISNULL(lc.GroupDiscountID,0) NOT IN (SELECT value FROM STRING_SPLIT(@CommGroups,','))		
		END
		
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c

		INSERT INTO #Temp (custid, currency, username, closed, suspended, nickname, BAStatus, SpecialLevel, ugroup,CustomerClass, RowNumber)
		SELECT * FROM 
		(
			SELECT 
				m.custid, 
				m.currency,
				m.username, 
				m.closed,
				ISNULL(m.reject, 0) AS suspended,
				SUBSTRING(m.username2, CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
				1 AS BAStatus, 
				m.SpecialLevel, 
				m.ugroup,
				m.CustomerClass,
				ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
			FROM
				#TempMember m 
		) a 
		WHERE a.rownumber BETWEEN @rowstart AND @rowend
	END 
	ELSE IF @BAFilter = 2
	BEGIN
		SELECT @strSQL = 'INSERT INTO #tmpCust(custid, closed, reject, ugroup,CustomerClass)
		SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1),ci.CustomerClass
		FROM #TempAg t 
			 INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON t.custid = ci.recommend
			 INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid 
		WHERE ci.roleid=1 
				AND ci.custid IN (SELECT custid FROM #tblCustList)
				AND c.username NOT LIKE ''%CashOut%''
				AND c.username  NOT LIKE ''%01OddsAdj%''
				AND c.username  NOT LIKE ''%01OddsBoostAdj%''
				AND (''' + @OddsGroups + ''' = '''' OR RIGHT(c.ugroup,1) IN (' + @OddsGroupsC + ')) '
				
		IF ISNULL(@CustomerClass, '') <> ''
		BEGIN
			SET @strSQL = @strSQL + 'AND ISNULL(ci.CustomerClass,0) IN  (' +  @CustomerClass + ')' +
							CASE WHEN @IsUncategorizedCC = 1 THEN ' OR ISNULL(ci.CustomerClass,0) NOT IN ('+  @FullCustomerClass + ')'
										ELSE '' END
		END 		
			
	
		--EXEC sp_executesql @strSQL
		EXEC (@strSQL)

		SELECT @strSQL = 'INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject,CustomerClass)
		SELECT c.CustID, lc.currency, lc.speciallevel, lc.username2, lc.username, c.ugroup, c.closed, c.reject,c.CustomerClass
		FROM
			#tmpCust c
			INNER JOIN 
			(SELECT c.custid, c.currency, ISNULL(lc.speciallevel,0) as speciallevel, c.username, c.username2 
			 FROM CustDB.dbo.Customer c WITH(NOLOCK)
				LEFT JOIN #Dep_CustSpecialLevel lc ON c.CustID = lc.CustID			 
				INNER JOIN #TempAg t ON c.recommend = t.custid
			 WHERE c.RoleID = 1
			 ) lc ON lc.custid = c.custid
			LEFT JOIN #LicenseeBAHistory lb ON c.custid = lb.custid AND lb.[Status] = ''Running''				
		WHERE ISNULL (lb.CustID, 0) = 0
			AND ISNULL(lc.speciallevel,0) IN  (' +  @SpecialLevel + ')'

		--EXEC sp_executesql @strSQL
		EXEC (@strSQL)
		
		IF @CommGroups IS NOT NULL
		BEGIN
			DELETE t
			FROM #TempMember t
				LEFT JOIN #LicenseeCustDiscount lc ON t.custid=lc.custid 
			WHERE ISNULL(lc.GroupDiscountID,0) NOT IN (SELECT value FROM STRING_SPLIT(@CommGroups,','))		
		END
		
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c

		INSERT INTO #Temp (custid, currency, username, closed, suspended, nickname, BAStatus, SpecialLevel, ugroup ,CustomerClass , RowNumber)
		SELECT * FROM 
		(
			SELECT 
				m.custid, 
				m.currency,
				m.username, 
				m.closed,
				ISNULL(m.reject,0) AS suspended,
				SUBSTRING(m.username2, CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
				0 AS BAStatus, 
				m.SpecialLevel, 
				m.ugroup,
				m.CustomerClass,
				ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
			FROM
				#TempMember m 
		) a 
		WHERE a.rownumber BETWEEN @rowstart AND @rowend
	END

	--Case 1: BA is ON
	UPDATE #Temp SET IsPowerBAUserTurnoff = 0
	WHERE BAStatus = 1

	--Case 2: BA is OFF
	--Case 2.1: never turn-off BA
	UPDATE #Temp SET IsPowerBAUserTurnoff = 0
	WHERE
		BAStatus = 0
		AND CustID NOT IN (
			SELECT DISTINCT CustID 
			FROM #LicenseeBAHistory lb
			WHERE Status = 'Done'
		)

	--Case 2.2 turned on BA before
	INSERT INTO @TempBACust (CustID)
	SELECT CustID FROM #Temp
	WHERE BAStatus = 0 AND IsPowerBAUserTurnoff IS NULL

	IF (SELECT COUNT(*) FROM @TempBACust) > 0
	BEGIN
		SELECT @i = 0
		SELECT @max = MAX(id) FROM @TempBACust

		WHILE @i < @MAX
		BEGIN
			SET @i = @i + 1
			SET @LastOffBy = 0

			SELECT @CustID = CustID 
			FROM @TempBACust WHERE id = @i
		
			--Get last turn-off BA UserID
			SELECT TOP 1 @LastOffBy = OffBy
			FROM #LicenseeBAHistory l WITH(NOLOCK)
			WHERE
				[CustID] = @CustID AND
				[Status] = 'Done'
			ORDER BY ID DESC

			--Check whether the Last turn-off BA is Power BA user or not
			--If is Power BA User then only Power BA Users can turn-on again
			IF ISNULL(@LastOffBy, 0) <> 0 AND EXISTS (
				SELECT 1 
				FROM DBCUST.bodb_licensee.dbo.LicenseeUserFunctions l WITH(NOLOCK)
				WHERE
					FunctionID = 54
					AND UserID = ISNULL(@LastOffBy, 0)
					AND LicenseeID = @LicenseeID
			) 
			BEGIN
				UPDATE #Temp SET IsPowerBAUserTurnoff = 1 WHERE CustID = @CustID
			END
		END
	END

	--Case 3 update the rest
	UPDATE #Temp SET IsPowerBAUserTurnoff = 0 WHERE IsPowerBAUserTurnoff IS NULL

	-- translog
	INSERT INTO #OutstandingTranslog
	SELECT
		tl.custid,
		tl.currency,
		tl.statusID,
		SUM(actual_stake) AS actual_stacke
	FROM
		dbo.translog tl WITH(NOLOCK)
		INNER JOIN #Temp cl on cl.custid = tl.custid
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
		dbo.bettransRnG g WITH(NOLOCK)
		INNER JOIN #Temp cl on cl.custid = g.custid
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
		dbo.bettransLC g WITH(NOLOCK)
		INNER JOIN #Temp cl on cl.custid = g.custid
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

	--TODO: get MBU days
	DECLARE @MoveBetsDay SMALLDATETIME,	@BalanceUpDay SMALLDATETIME
	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @MoveBetsDay OUTPUT
	EXEC dbo.NAP_Admin_GetBalanceUpDate @BalanceUpDate = @BalanceUpDay OUTPUT

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
		INNER JOIN dbo.bettrans b WITH (NOLOCK)ON t.custid = b.custid
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
		INNER JOIN dbo.transfer b WITH(NOLOCK) ON t.custid = b.custid
	WHERE 1 = CASE WHEN bettype = 19999 AND winlostdate > @MoveBetsDay THEN 0 --> new sum
	            WHEN bettype = 20000 AND winlostdate > @BalanceUpDay THEN 0 --> new bal
	            WHEN winlostdate < @BalanceUpDay THEN 0 --> old data
	            ELSE 1 END
	GROUP BY t.custid

	INSERT INTO #data(custid, TotalBalance, Outstanding)
	SELECT t.CustId, SUM(t.TotalBalance), SUM(t.Outstanding)
	FROM #TotalBalance t
	GROUP BY t.custid

	INSERT INTO #Exchange(Id, Name)
	EXEC dbo.SiteDB_Lrf_CurrencySel 
	
	SELECT
		t.custid,
		ex.Name AS currency,
		ex.Id AS exchangeid,
		t.Username,
		t.Closed,
		t.suspended,
		t.nickname,
		t.BAStatus,
		t.SpecialLevel,
		t.IsPowerBAUserTurnoff,
		t.RowNumber,
		t.CustomerClass,
		ISNULL(lc.GroupName, '') AS GroupName,	
		CAST((ISNULL(d.TotalBalance, 0)	- ISNULL(tl.actual_stake,0)) AS MONEY) AS TotalBalance,
		CAST((ISNULL(d.Outstanding, 0) + ISNULL(tl.actual_stake,0)) AS MONEY) AS Outstanding,
		ISNULL(UPPER(t.ugroup), '') AS OddsGroup
	FROM #Temp t
		INNER JOIN #Exchange ex WITH(NOLOCK) ON t.currency = ex.Id
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
		LEFT JOIN #LicenseeCustDiscount lc WITH(NOLOCK) ON t.custid=lc.custid
		
	ORDER BY t.username

END
GO