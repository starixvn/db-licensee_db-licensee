/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[N88_CustomerSelByUsername]
	@LicenseeName	VARCHAR(50),
	@username		VARCHAR(50) = NULL,
	@username2 		VARCHAR(50) = NULL,
	@SearchOption	TINYINT = 0,
	@PageSize		INT = 50,
	@PageIndex		INT = 1,	
	@TotalRows		INT = 0  OUTPUT,
	@SpecialLevel	VARCHAR(100) = '', 
	@OddsGroups		VARCHAR(100) = '',
	@AgentList		VARCHAR(MAX)
AS

/*
	Created by: [20200313@Johnson]
	Task: Get customer list by username for Nova Cash site
	DB: DBEXT/bodb02
	Original: Lrf_CustomerSelByUsername
	
	Revisions:
		- 20200313@Johnson: initial sp [redmine: #129873]
		- 20250227@Virgil: Drop BA functions [RedmineID: #216882]
		- 20250408@Kelvin: Upgrade ExchangeId Datatype [RedmineID: #222339]
	
	Parameter's explanations:
		+ @username: systemID
		+ @username2: nickname
		+ @SpecialLevel: '1,2,3,4,5,6,7,8,9,10' (all)
		+ @OddsGroups: Member's Odds Group
		+ @searchOption: 1- basic search
						 2- advance search						 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @currentDate DATETIME,
			@LicenseeID	INT
			
	SELECT  @currentDate = CONVERT(DATE, GETDATE())

	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #TempAg (custid INT)
	
	DECLARE @DocHandler INT
	
	SELECT @LicenseeID	= LicenseeID
	FROM bodb_Licensee.dbo.Licensees WITH(NOLOCK)
	WHERE LicenseeName = @LicenseeName
	
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency SMALLINT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH;
 
	SELECT @Username = NULLIF(@Username, ''),
		@Username2 = NULLIF(@Username2, '')

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
		RowNumber				INT
	)

	CREATE TABLE #tmpCust
	(
		custid		INT PRIMARY KEY,		
		closed		BIT,
		reject		BIT,
		ugroup		VARCHAR(3)
	)

	CREATE TABLE #OutstandingTranslog
	(
		Custid			INT,
		Currency		SMALLINT,
		statusID		tinyint,
		actual_stake	money
	)

	CREATE TABLE #TempMember
	(
		CustID			INT PRIMARY KEY CLUSTERED,
		currency 		SMALLINT,
		speciallevel	int,
		username2		VARCHAR(50),
		username		VARCHAR(50),
		ugroup			VARCHAR(3),
		closed			BIT,
		reject			BIT
	)
	
	CREATE TABLE #Exchange
	(
		Id				INT PRIMARY KEY,
		Name			VARCHAR(50),
	)

	
	DECLARE @tmpSpecial TABLE (Level TINYINT)
	
	DECLARE @CustID INT, @i INT, @max INT, @LastOffBy INT

	SET @OddsGroups = ISNULL(@OddsGroups, '')
	--For predicate pushdown
	DECLARE @tmpOddsGroups TABLE (OddsGroup VARCHAR(10))
	
	INSERT INTO @tmpOddsGroups(OddsGroup)
	SELECT val 
	FROM strSplit (@OddsGroups,',')
		
	INSERT INTO @tmpSpecial(level)
	SELECT val
	FROM strSplit(@SpecialLevel,',')
	
	IF @Username IS NULL AND @Username2 IS NULL AND @SearchOption = 2
	BEGIN
		INSERT INTO #tmpCust(custid, closed, reject, ugroup)
		SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1)
		FROM #TempAg t 
				INNER JOIN custInfo ci WITH(NOLOCK) ON t.custid = ci.recommend
				INNER JOIN Customer c WITH (NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid 
		WHERE ci.roleid=1 
				AND c.username NOT LIKE '%CashOut%'				
				AND (@OddsGroups = '' OR RIGHT(c.ugroup,1) IN (SELECT OddsGroup FROM @tmpOddsGroups) )
		
		INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject)
		SELECT c.CustID, lc.currency, lc.speciallevel, lc.username2, lc.username, c.ugroup, c.closed, c.reject
		FROM
			#tmpCust c
			INNER JOIN 
			(SELECT c.custid, c.currency, ISNULL(lc.speciallevel,0) as speciallevel , c.username, c.username2 
				FROM bodb02.dbo.Customer c WITH (NOLOCK)
				LEFT JOIN dbo.Dep_CustSpecialLevel lc WITH(NOLOCK) ON c.CustID = lc.CustID			 
				INNER JOIN #TempAg t ON c.recommend = t.custid
				WHERE c.RoleID = 1
				) lc ON lc.custid = c.custid			
		WHERE ISNULL(lc.speciallevel,0) IN (SELECT level FROM @tmpSpecial)				
		
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c
						
		INSERT INTO #Temp (custid, currency, username, closed, suspended, nickname, SpecialLevel, ugroup, RowNumber)
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
				ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
			FROM
				#TempMember m 
		) a 
		WHERE a.rownumber BETWEEN @rowstart AND @rowend
	END -- end LEN(username) = 0
	ELSE
	BEGIN
		SELECT @username = LTRIM(RTRIM(@username)),
			@username2 = LTRIM(RTRIM(@username2))
				
		SELECT @username = REPLACE(@username,'',''''),
				@username2 = REPLACE(@username2,'','''')
		

		INSERT INTO #TempMember (CustID, currency, speciallevel, username2, username, ugroup, closed, reject)
		SELECT ci.custid, ci.currency, ISNULL(lc.SpecialLevel,0) as speciallevel , c.username2, c.username, RIGHT(c.ugroup, 1), ci.closed, ci.reject
		FROM #TempAg t
			INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.recommend = t.custid
			INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.custid					
			LEFT JOIN dbo.Dep_CustSpecialLevel lc WITH(NOLOCK) ON c.custid = lc.custid					
		WHERE 
			c.RoleID = 1
			AND (1= @searchOption AND (c.username LIKE ISNULL(@Username,c.username) 
										AND (SUBSTRING(c.username2,CHARINDEX('$',c.username2)+1,len(c.username2))) LIKE ISNULL(@username2,(SUBSTRING(c.username2,CHARINDEX('$',c.username2)+1,len(c.username2)))) 
										)
				OR (2= @searchOption AND ((SUBSTRING(c.username2,CHARINDEX('$',c.username2)+1,len(c.username2)) LIKE ISNULL(@Username2,'') + '%') 
											AND c.username LIKE ISNULL(@Username,'') + '%')
					)
				)	
			AND c.username NOT LIKE '%CashOut%'				
			AND (@OddsGroups = '' OR RIGHT(c.ugroup,1) IN (SELECT OddsGroup FROM @tmpOddsGroups) )
			AND ISNULL(lc.speciallevel,0) IN (SELECT level FROM @tmpSpecial)				
		
															
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c
				
		INSERT INTO #Temp (custid, currency, username, closed, suspended, nickname, SpecialLevel, ugroup, RowNumber)
		SELECT a.custid, a.currency, a.username, a.closed, a.suspended, a.nickname, a.SpecialLevel, a.ugroup, a.RowNumber
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
					ROW_NUMBER() OVER (ORDER BY ci.currency ASC, ci.custid ASC) AS RowNumber 
				FROM #TempMember m
				INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON m.CustID = ci.custid
			) a 
		WHERE a.rownumber BETWEEN @rowstart AND @rowend
	END

	
	DECLARE @sporttype	TABLE (SportType INT)

	INSERT INTO @sporttype ( SportType )
	SELECT DISTINCT SportType FROM [dbo].[SportBettypeMatrix] WITH (NOLOCK)
	WHERE reftable = 3

	-- translog
	INSERT INTO #OutstandingTranslog
	SELECT tl.custid, tl.currency, statusID, SUM(actual_stake) actual_stacke
	FROM
		dbo.translog tl WITH (NOLOCK)
		INNER JOIN #TempAg lc ON tl.recommend=lc.CustID
		INNER JOIN @sporttype s ON s.SportType = productID
	WHERE
		statusID IN (0, 1)  --running and Waiting		
	GROUP BY tl.custid, tl.currency, productID, statusID

	--- bettransRNG
	INSERT INTO #OutstandingTranslog
	SELECT g.custid, g.currency, statusID, SUM(g.actual_stake) actual_stacke
	FROM
		dbo.bettransRnG g WITH (NOLOCK)
		INNER JOIN #TempAg lc ON g.recommend = lc.CustID
	WHERE g.statusID IN (0, 1)  --running and Waiting		
	GROUP BY g.custid, g.currency, statusID

	--- bettransLC
	INSERT INTO #OutstandingTranslog
	SELECT g.custid, g.currency, statusID, SUM(g.actual_stake) actual_stacke
	FROM
		dbo.bettransLC g WITH (NOLOCK)
		INNER JOIN #TempAg lc ON g.recommend = lc.CustID
	WHERE g.statusID IN (0, 1)  --running and Waiting		
	GROUP BY g.custid, g.currency, statusID

	CREATE TABLE #data(
		custid int PRIMARY KEY,
		TotalBalance money,		
		Outstanding money		
	)

	INSERT INTO #data(custid, TotalBalance,Outstanding)
	SELECT 
		t.custid,
		ISNULL(SUM(ISNULL(b.winlost-b.actual_stake + b.playercomm, 0)), 0) AS TotalBalance,
		ISNULL(SUM(CASE WHEN ruben = 0 THEN ISNULL(b.actual_stake, 0)*(CASE WHEN b.bettype = 71 THEN 0 ELSE 1 END) ELSE 0 END), 0) AS Outstanding
	FROM
		#Temp t
		INNER JOIN bettrans b WITH(NOLOCK) ON t.custid = b.custid		
	WHERE b.matchid >= 0
	GROUP BY t.custid
	
	INSERT INTO #Exchange(Id, Name)	EXEC Lrf_CurrencySel 

	SELECT
		t.custid,
		ex.Name AS currency,
		ex.Id AS exchangeid,
		username,
		closed,
		suspended,
		nickname,
		SpecialLevel,
		RowNumber,
		CAST((ISNULL(d.TotalBalance, 0)	- isnULL(tl.actual_stake,0)) AS MONEY) AS TotalBalance ,
		CAST((ISNULL(d.Outstanding, 0)	+ ISNULL(tl.actual_stake,0)) AS MONEY) AS Outstanding,
		ISNULL(UPPER(t.ugroup), '') AS OddsGroup
	FROM #Temp t
		INNER JOIN #Exchange ex WITH(NOLOCK ) ON t.currency = ex.id
		LEFT JOIN #Data d ON t.custid = d.custid
		LEFT JOIN
		(
			SELECT SUM(actual_stake) actual_stake, Custid, Currency
			FROM #OutstandingTranslog
			GROUP BY Custid, Currency
		)tl ON t.custid = tl.Custid		
	ORDER BY t.username
		
	DROP TABLE #TempAg
	DROP TABLE #Temp
	DROP TABLE #OutstandingTranslog
	DROP TABLE #Data
	DROP TABLE #tmpCust
	DROP TABLE #TempMember
END
GO	
