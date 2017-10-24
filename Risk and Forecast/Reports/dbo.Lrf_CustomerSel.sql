/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CustomerSel]
	@LicenseeID		INT,
	@username		VARCHAR(50) = NULL,
	@PageSize		INT = 50,
	@PageIndex		INT = 1,
	@BAFilter		SMALLINT = 0,
	@CustStatus		varchar(50)= '',
	@TotalRows		INT = 0  OUTPUT,
	@SpecialLevel	INT = -1, --ALL
	@GroupCommID	INT = -1, --ALL
	@OddsGroups		VARCHAR(100) = '',
	@AgentList		VARCHAR(MAX)
AS

/*
	Created by: [2013@]
	Task: Member List 
	DB: DBEXT/bodb02
	Original: Acc_CustomerSelByAg

	Revisions:
		- 20110218@Jacob: Calculate the today balance, yesterday balance, outstanding
		- 20110305@Henry: Allow to choose all type of licensee AND all currency + suppport based currency
		- 20110513@Henry: change bettype to new range
		- 20110610@Henry: RETURN more columns for BA (BAStatus, LastUpdateBA, BAUpdatedBy) + Enhance Performance
		- 20110808@Henry: Support to filter: Open, Closed, Suspended customer
		- 20111222@Henry: Support to filter Special Level
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
		- 20120314@Kiwi: enhance performance
		- 20120326@Henry: replace "where username like '%' + @username + '%'" (index scan) by "where username like @username + '%'" (index seek).
		- 20120423@Henry: enhance performance by querying the username/username2 in LicenseeCustinfo instead of DB06.bodb02.dbo.Customer
		- 20120625@Henry: return column IsPowerBAUserTurnoff who Power BA User has turned off before
		- 20120801@Henry: return group commission information of members
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130118@Henry: fix bug @LastOffBy - Forgot to put param @LicenseeID
		- 20130514@Jim:  Restrict permission of Licensee Users by currency
		- 20130718@Jim: remove status Suspended
		- 20131026@Hannah: offer Live Casino commission
		- 20131126@Hannah: offer RNG Casino commission
		- 20140407@Florent: offer Keno product
		- 20140421@Florent: Fix bug oustanding of Keno sport
		- 20140604@Don: Improve performance in case of input param @username with value NULL (Redmine ID: 17190)
		- 20141112@Victor: use f_SelLicenseeCust instead of licenseecust (#Redmine 25864)
		- 20150120@Jim: add more column OddsGroup in the result
		- 20150130@Winnie Add base currency GBP
		- 20150626@Jim: support MicroGaming (feature #37034)
		- 20150917@Florent: Change datasource for AG Casino (#Redmine 43172)
		- 20151102@Victor: Add Odds Group filter to Customer List [Redmine: #46312]
		- 20151108@Jim: Separated MicroGaming into 2 product
		- 20160104@Bobby: Fixbug#50272 - Remove RNG Casino bettype 71
		- 20160404@Percy: Support Voidbridge single wallet [Redmine: #55057]
		- 20160805@Jim: LRF - Offer different member commission for parlay tickets [RedmineID:#61897]	
		- 20160913@Jim: LRF - Implement Colossus Bets [Redmine: #63785]	
		- 20161122@Francis: Use dynamic query to enhance performance [Redmine: #66801]
		- 20161226@Francis: Hotfix BA filter with username syntax error when building dynamic string
		- 20170228@Paul: Get @AgentList by web instead of @UserId, @CurrencyID, Remove @LicenseeType [Redmine: #71679]
		- 20171017@Johnson: offer comm for Allbet [Redmine: #82036]
	Param's Explanation:
		+ @BAFilter: support filter BA members (0: both BA + non BA, 1: BA Members only, 2: non-BA members)
		+ @SpecialLevel: default value = -1 (all)
		+ @OddsGroups: Member's Odds Group
	
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @currentDate DATETIME   
	SELECT  @currentDate = CONVERT(DATE, GETDATE())

	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #TempAg (custid INT)

	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;
 
	SET @Username = ISNULL(@Username, '')

	CREATE TABLE #Temp
	(
		custid					INT PRIMARY KEY,
		username				NVARCHAR (50),
		closed					BIT,
		suspended				BIT,
		nickname				NVARCHAR (50),
		BAStatus				BIT,
		SpecialLevel			INT,
		IsPowerBAUserTurnoff	BIT,
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
		Currency		INT,
		statusID		tinyint,
		actual_stake	money
	)

	CREATE TABLE #TempMember
	(
		CustID			INT PRIMARY KEY CLUSTERED,
		speciallevel	int,
		username2		VARCHAR(50),
		username		VARCHAR(50),
		ugroup			VARCHAR(3),
		closed			BIT,
		reject			BIT
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

	IF LEN(@Username) = 0
	BEGIN
		IF @BAFilter = 0 
		BEGIN	
			SELECT @strSQL = 'INSERT INTO #tmpCust(custid, closed, reject, ugroup)
			SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1)
			FROM #TempAg t 
				 INNER JOIN custInfo ci WITH(NOLOCK) ON t.custid = ci.recommend
				 INNER JOIN Customer c WITH (NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid 
			WHERE ci.roleid=1 
					AND
					(
						(''' + @CustStatus + ''' = '''')
						OR (''' + @CustStatus + ''' = ''Open'' AND ci.closed = 0)
						OR (''' + @CustStatus + ''' = ''Closed'' AND ci.closed = 1)
					)
					AND
					(
						(''' + @CustStatus + ''' IN ('''',''Closed''))
						OR (''' + @CustStatus + ''' = ''Open'' AND ISNULL(ci.reject, 0) = 0)
						OR (''' + @CustStatus + ''' = ''Suspended'' AND ISNULL(ci.reject, 0) = 1)
					)
					AND (''' + @OddsGroups + ''' = '''' OR RIGHT(c.ugroup,1) IN (' + @OddsGroupsC + '))'	
		
			--EXEC sp_executesql @strSQL
			EXEC (@strSQL)
		
			SELECT @strSQL = 'INSERT INTO #TempMember (CustID, speciallevel, username2, username, ugroup, closed, reject)
			SELECT c.CustID, lc.speciallevel, lc.username2, lc.username, c.ugroup, c.closed, c.reject
			FROM
				#tmpCust c
				INNER JOIN 
				(SELECT lci.custid, lci.speciallevel, lci.username, lci.username2 
				 FROM bodb_licensee.dbo.LicenseeCustInfo lci WITH(NOLOCK) 
				 INNER JOIN #TempAg t ON lci.recommend = t.custid
				 ) lc ON lc.custid = c.custid
				LEFT JOIN  bodb_licensee.dbo.LicenseeCustComm cc WITH(NOLOCK) ON c.custid = cc.custid AND cc.Licenseeid = '
				+ CONVERT(VARCHAR(10),@LicenseeID) + '
			WHERE 
				(' + CONVERT(VARCHAR(10),@SpecialLevel) + ' = -1 OR lc.SpecialLevel = ' +  CONVERT(VARCHAR(10),@SpecialLevel) + ')
				AND (' + CONVERT(VARCHAR(10),@GroupCommID) + ' = -1 OR ISNULL(cc.GroupCommID, 0) = ' + CONVERT(VARCHAR(10),@GroupCommID) + ')'
			
			--EXEC sp_executesql @strSQL
			EXEC (@strSQL)
		
			IF ISNULL(@TotalRows, 0) = 0
				SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c

			INSERT INTO #Temp (custid, username, closed, suspended, nickname, BAStatus, SpecialLevel, ugroup, RowNumber)
			SELECT t.custid, t.username, t.closed, t.suspended, t.nickname, CASE WHEN lb.CustID IS NULL THEN 0 ELSE 1 END AS BAStatus, t.speciallevel, t.ugroup, t.RowNumber  
			FROM
				(
					SELECT a.custid, a.username, a.closed, a.suspended, a.nickname, a.speciallevel, a.ugroup, a.RowNumber  
					FROM
					(
						SELECT 
							m.custid, 
							m.username, 
							m.closed,
							ISNULL(m.reject,0) AS suspended,
							SUBSTRING(m.username2,  CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
							m.SpecialLevel,
							m.ugroup,
							ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
						FROM
							#TempMember m
					) a 
					WHERE a.rownumber BETWEEN @rowstart AND @rowend
				) t
				LEFT JOIN bodb_Licensee.dbo.LicenseeBAHistory lb WITH(NOLOCK) ON LicenseeID = @LicenseeID AND t.CustID = lb.CustID AND lb.[Status] = 'Running'
		END
		ELSE IF @BAFilter = 1
		BEGIN
			SELECT @strSQL = 'INSERT INTO #TempMember (CustID, speciallevel, username2, username, ugroup, closed, reject)
							  SELECT ci.CustID, lc.speciallevel, lc.username2, lc.username, RIGHT(cu.ugroup, 1), ci.closed, ci.reject
							  FROM bodb_Licensee.dbo.LicenseeBAHistory lb WITH(NOLOCK)
								INNER JOIN CustInfo ci (NOLOCK) ON lb.custid = ci.custid
								INNER JOIN Customer cu WITH (NOLOCK) ON ci.CustID = cu.custid 
								INNER JOIN #TempAg t ON ci.recommend = t.custid
								INNER JOIN bodb_licensee.dbo.LicenseeCustInfo lc WITH(NOLOCK) ON ci.custid = lc.custid
								LEFT JOIN  bodb_licensee.dbo.LicenseeCustComm cc WITH(NOLOCK) ON ci.custid = cc.custid AND cc.Licenseeid = '
								+ CONVERT(VARCHAR(10),@LicenseeID) + '
							 WHERE lb.LicenseeID = ' + CONVERT(VARCHAR(10),@LicenseeID) + '
								   AND lb.[Status] = ''Running''
								   AND
								   (
										(''' + @CustStatus + ''' = '''')
										OR (''' + @CustStatus + ''' = ''Open'' AND ci.closed = 0)
										OR (''' + @CustStatus + ''' = ''Closed'' AND ci.closed = 1)
									)
									AND
									(
										(''' + @CustStatus + ''' IN ('''',''Closed''))
										OR (''' + @CustStatus + ''' = ''Open'' AND ISNULL(ci.reject, 0) = 0)
										OR (''' + @CustStatus + ''' = ''Suspended'' AND ISNULL(ci.reject, 0) = 1)
									)
									AND (''' + @OddsGroups + ''' = '''' OR RIGHT(cu.ugroup,1) IN (' + @OddsGroupsC + '))
									AND (' + CONVERT(VARCHAR(10),@SpecialLevel) + ' = -1 OR lc.SpecialLevel = ' +  CONVERT(VARCHAR(10),@SpecialLevel) + ')
									AND (' + CONVERT(VARCHAR(10),@GroupCommID) + ' = -1 OR ISNULL(cc.GroupCommID, 0) = ' + CONVERT(VARCHAR(10),@GroupCommID) + ')'
			
			--EXEC sp_executesql @strSQL
			EXEC (@strSQL)
		
			IF ISNULL(@TotalRows, 0) = 0
				SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c

			INSERT INTO #Temp (custid, username, closed, suspended, nickname, BAStatus, SpecialLevel, ugroup, RowNumber)
			SELECT * FROM 
			(
				SELECT 
					m.custid, 
					m.username, 
					m.closed,
					ISNULL(m.reject, 0) AS suspended,
					SUBSTRING(m.username2, CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
					1 AS BAStatus, 
					m.SpecialLevel, 
					m.ugroup,
					ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
				FROM
					#TempMember m 
			) a 
			WHERE a.rownumber BETWEEN @rowstart AND @rowend
		END 
		ELSE IF @BAFilter = 2
		BEGIN
			SELECT @strSQL = 'INSERT INTO #tmpCust(custid, closed, reject, ugroup)
			SELECT ci.custid, ci.closed, ci.reject, RIGHT(c.ugroup, 1)
			FROM #TempAg t 
				 INNER JOIN custInfo ci WITH(NOLOCK) ON t.custid = ci.recommend
				 INNER JOIN Customer c WITH (NOLOCK, INDEX = IX_custid, FORCESEEK) ON ci.custid = c.custid 
			WHERE ci.roleid=1 
					AND
					(
						(''' + @CustStatus + ''' = '''')
						OR (''' + @CustStatus + ''' = ''Open'' AND ci.closed = 0)
						OR (''' + @CustStatus + ''' = ''Closed'' AND ci.closed = 1)
					)
					AND
					(
						(''' + @CustStatus + ''' IN ('''',''Closed''))
						OR (''' + @CustStatus + ''' = ''Open'' AND ISNULL(ci.reject, 0) = 0)
						OR (''' + @CustStatus + ''' = ''Suspended'' AND ISNULL(ci.reject, 0) = 1)
					)
					AND (''' + @OddsGroups + ''' = '''' OR RIGHT(c.ugroup,1) IN (' + @OddsGroupsC + '))'	
		
			--EXEC sp_executesql @strSQL
			EXEC (@strSQL)

			SELECT @strSQL = 'INSERT INTO #TempMember (CustID, speciallevel, username2, username, ugroup, closed, reject)
			SELECT c.CustID, lc.speciallevel, lc.username2, lc.username, c.ugroup, c.closed, c.reject
			FROM
				#tmpCust c
				INNER JOIN 
				(SELECT lci.custid, lci.speciallevel, lci.username, lci.username2 
				 FROM bodb_licensee.dbo.LicenseeCustInfo lci WITH(NOLOCK) 
				 INNER JOIN #TempAg t ON lci.recommend = t.custid
				 ) lc ON lc.custid = c.custid
				LEFT JOIN bodb_Licensee.dbo.LicenseeBAHistory lb WITH(NOLOCK) ON lb.LicenseeID = ' + CONVERT(VARCHAR(10),@LicenseeID) + ' AND c.custid = lb.custid AND lb.[Status] = ''Running''
				LEFT JOIN  bodb_licensee.dbo.LicenseeCustComm cc WITH(NOLOCK) ON c.custid = cc.custid AND cc.Licenseeid = '
				+ CONVERT(VARCHAR(10),@LicenseeID) + '
			WHERE ISNULL (lb.CustID, 0) = 0
				AND (' + CONVERT(VARCHAR(10),@SpecialLevel) + ' = -1 OR lc.SpecialLevel = ' +  CONVERT(VARCHAR(10),@SpecialLevel) + ')
				AND (' + CONVERT(VARCHAR(10),@GroupCommID) + ' = -1 OR ISNULL(cc.GroupCommID, 0) = ' + CONVERT(VARCHAR(10),@GroupCommID) + ')'
		
			--EXEC sp_executesql @strSQL
			EXEC (@strSQL)
		
			IF ISNULL(@TotalRows, 0) = 0
				SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c
	
			INSERT INTO #Temp (custid, username, closed, suspended, nickname, BAStatus, SpecialLevel, ugroup, RowNumber)
			SELECT * FROM 
			(
				SELECT 
					m.custid, 
					m.username, 
					m.closed,
					ISNULL(m.reject,0) AS suspended,
					SUBSTRING(m.username2, CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
					0 AS BAStatus, 
					m.SpecialLevel, 
					m.ugroup,
					ROW_NUMBER() OVER (ORDER BY m.custid ASC) AS RowNumber 
				FROM
					#TempMember m 
			) a 
			WHERE a.rownumber BETWEEN @rowstart AND @rowend
		END
	END -- end LEN(username) = 0
	ELSE
	BEGIN
		SET @username = LTRIM(RTRIM(@username))
				
		SELECT @username = REPLACE(@username,'''','''''')
		
		IF @BAFilter = 0
		BEGIN
		SELECT @strSQL = 'INSERT INTO #TempMember (CustID, speciallevel, username2, username, ugroup, closed, reject)
				SELECT ci.custid, lc.SpecialLevel, lc.username2, lc.username, RIGHT(c.ugroup, 1), ci.closed, ci.reject
				FROM bodb_Licensee.dbo.LicenseeCustinfo lc WITH (NOLOCK) 
					INNER JOIN #TempAg t ON lc.recommend = t.custid
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.custid = lc.Custid
					INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.custid
					LEFT JOIN bodb_licensee.dbo.LicenseeCustComm cc ON cc.custid = lc.custid AND cc.Licenseeid = ' + CONVERT(VARCHAR(10),@LicenseeID) + '
				WHERE 
					(lc.username2 LIKE ' + '''%$' + @Username + '%''' + ' OR lc.username LIKE ''' + @Username + '%''' + ')
					AND
					(
						(''' + @CustStatus + ''' = '''')
						OR (''' + @CustStatus + ''' = ''Open'' AND ci.closed = 0)
						OR (''' + @CustStatus + ''' = ''Closed'' AND ci.closed = 1)
					)
					AND
					(
						(''' + @CustStatus + ''' IN ('''',''Closed''))
						OR (''' + @CustStatus + ''' = ''Open'' AND ISNULL(ci.reject, 0) = 0)
						OR (''' + @CustStatus + ''' = ''Suspended'' AND ISNULL(ci.reject, 0) = 1)
					)
					AND (''' + @OddsGroups + ''' = '''' OR RIGHT(c.ugroup,1) IN (' + @OddsGroupsC + '))
					AND (' + CONVERT(VARCHAR(10),@SpecialLevel) + ' = -1 OR lc.SpecialLevel = ' +  CONVERT(VARCHAR(10),@SpecialLevel) + ')
					AND (' + CONVERT(VARCHAR(10),@GroupCommID) + ' = -1 OR ISNULL(cc.GroupCommID, 0) = ' + CONVERT(VARCHAR(10),@GroupCommID) + ')'
		END
		ELSE
		BEGIN
			SELECT @strSQL = 'INSERT INTO #TempMember (CustID, speciallevel, username2, username, ugroup, closed, reject)
				SELECT ci.custid, lc.SpecialLevel, lc.username2, lc.username, RIGHT(c.ugroup, 1), ci.closed, ci.reject
				FROM bodb_Licensee.dbo.LicenseeCustinfo lc WITH (NOLOCK) 
					INNER JOIN #TempAg t ON lc.recommend = t.custid
					INNER JOIN dbo.Customer c WITH (NOLOCK) ON c.custid = lc.Custid
					INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON ci.custid = c.custid
					LEFT JOIN bodb_licensee.dbo.LicenseeCustComm cc ON cc.custid = lc.custid AND cc.Licenseeid = ' + CONVERT(VARCHAR(10),@LicenseeID) + '
					LEFT JOIN bodb_Licensee.dbo.LicenseeBAHistory lb WITH(NOLOCK) ON lb.LicenseeID = ' + CONVERT(VARCHAR(10),@LicenseeID) + 
					' AND ci.custid = lb.custid AND lb.[Status] = ''Running''
				WHERE 
					(lc.username2 LIKE ' + '''%$' + @Username + '%''' + ' OR lc.username LIKE ''' + @Username + '%''' + ')
					AND
					(
						(''' + @CustStatus + ''' = '''')
						OR (''' + @CustStatus + ''' = ''Open'' AND ci.closed = 0)
						OR (''' + @CustStatus + ''' = ''Closed'' AND ci.closed = 1)
					)
					AND
					(
						(''' + @CustStatus + ''' IN ('''',''Closed''))
						OR (''' + @CustStatus + ''' = ''Open'' AND ISNULL(ci.reject, 0) = 0)
						OR (''' + @CustStatus + ''' = ''Suspended'' AND ISNULL(ci.reject, 0) = 1)
					)
					AND (''' + @OddsGroups + ''' = '''' OR RIGHT(c.ugroup,1) IN (' + @OddsGroupsC + '))
					AND (' + CONVERT(VARCHAR(10),@SpecialLevel) + ' = -1 OR lc.SpecialLevel = ' +  CONVERT(VARCHAR(10),@SpecialLevel) + ')
					AND (' + CONVERT(VARCHAR(10),@GroupCommID) + ' = -1 OR ISNULL(cc.GroupCommID, 0) = ' + CONVERT(VARCHAR(10),@GroupCommID) + ')
					AND ((' + CONVERT(VARCHAR(10),@BAFilter) + ' = 1 AND ISNULL(lb.[Status],'''') = ''Running'')'
					+ ' OR ('+ CONVERT(VARCHAR(10),@BAFilter) + '= 2 AND ISNULL(lb.[Status],'''') != ''Running''))'
		END			
					
		--EXEC sp_executesql @strSQL
		EXEC (@strSQL)
										
		IF ISNULL(@TotalRows, 0) = 0
			SELECT @TotalRows = COUNT(c.custid) FROM #TempMember c
	
		INSERT INTO #Temp (custid, username, closed, suspended, nickname, BAStatus, SpecialLevel, ugroup, RowNumber)
		SELECT a.custid, a.username, a.closed, a.suspended, a.nickname, a.BAStatus, a.SpecialLevel, a.ugroup, a.RowNumber
		FROM 
			(
				SELECT m.custid, 
					m.username, 
					m.closed,
					ISNULL(m.reject, 0) AS suspended,
					SUBSTRING(m.username2,  CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
					CASE WHEN lb.CustID IS NULL THEN 0 ELSE 1 END AS BAStatus, 
					m.SpecialLevel,
					m.ugroup,
					ROW_NUMBER() OVER (ORDER BY ci.currency ASC, ci.custid ASC) AS RowNumber 
				FROM #TempMember m
				INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON m.CustID = ci.custid
				LEFT JOIN bodb_Licensee.dbo.LicenseeBAHistory lb WITH (nolock) ON LicenseeID = @LicenseeID AND m.custid = lb.custid AND lb.[Status] = 'Running'
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
			SELECT DISTINCT CustID FROM bodb_Licensee.dbo.LicenseeBAHistory lb WITH (nolock)
			WHERE LicenseeID = @LicenseeID AND Status = 'Done'
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
			SELECT @CustID = CustID FROM @TempBACust WHERE id = @i
		
			--Get last turn-off BA UserID
			SELECT TOP 1 @LastOffBy = OffBy
			FROM bodb_licensee.dbo.[LicenseeBAHistory] WITH (NOLOCK)
			WHERE
				[LicenseeID] = @LicenseeID AND
				[CustID] = @CustID AND
				[Status] = 'Done'
			ORDER BY ID DESC

			--Check whether the Last turn-off BA is Power BA user or not
			--If is Power BA User then only Power BA Users can turn-on again
			IF ISNULL(@LastOffBy, 0) <> 0 AND EXISTS (
				SELECT 1 FROM bodb_licensee.dbo.LicenseeUserFunctions WITH (NOLOCK)
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
	SELECT tl.custid, tl.currency, statusID, SUM(actual_stake) actual_stacke
	FROM
		dbo.translog tl WITH (NOLOCK)
		INNER JOIN #TempAg lc ON tl.recommend=lc.CustID
	WHERE
		statusID IN (0, 1)  --running and Waiting
		AND productID IN (202, 203,204)
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

	SELECT *
	INTO #ExchangeRate
	FROM Lrf_f_GetExchangeDaily(@currentDate, @currentDate)

	CREATE TABLE #data(
		custid int PRIMARY KEY,
		TotalBalance money,
		TotalBalanceUSD money,
		TotalBalanceEUR money,
		TotalBalanceGBP money,
		Outstanding money,
		OutstandingUSD money,
		OutstandingEUR money,
		OutstandingGBP money,
	)

	INSERT INTO #data(custid, TotalBalance, TotalBalanceUSD, TotalBalanceEUR, TotalBalanceGBP, Outstanding, OutstandingUSD, OutstandingEUR, OutstandingGBP)
	SELECT 
		t.custid,
		ISNULL(SUM(ISNULL(b.winlost-b.actual_stake + b.playercomm, 0)), 0) AS TotalBalance,
		CAST(ISNULL(SUM(e.USD*ISNULL(b.winlost-b.actual_stake + b.playercomm,0)),0) AS MONEY) AS TotalBalanceUSD,
		CAST(ISNULL(SUM(e.EUR*ISNULL(b.winlost-b.actual_stake + b.playercomm,0)),0) AS MONEY) AS TotalBalanceEUR,
		CAST(ISNULL(SUM(e.GBP*ISNULL(b.winlost-b.actual_stake + b.playercomm,0)),0) AS MONEY) AS TotalBalanceGBP,
		ISNULL(SUM(CASE WHEN ruben = 0 THEN ISNULL(b.actual_stake, 0)*(CASE WHEN b.bettype = 71 THEN 0 ELSE 1 END) ELSE 0 END), 0) AS Outstanding,
		CAST(ISNULL(SUM(e.USD * CASE WHEN ruben = 0 THEN ISNULL(b.actual_stake, 0)*(CASE WHEN b.bettype = 71 THEN 0 ELSE 1 END) ELSE 0 END), 0) AS MONEY) AS OutstandingUSD,
		CAST(ISNULL(SUM(e.EUR * CASE WHEN ruben = 0 THEN ISNULL(b.actual_stake, 0)*(CASE WHEN b.bettype = 71 THEN 0 ELSE 1 END) ELSE 0 END), 0) AS MONEY) AS OutstandingEUR,
		CAST(ISNULL(SUM(e.GBP * CASE WHEN ruben = 0 THEN ISNULL(b.actual_stake, 0)*(CASE WHEN b.bettype = 71 THEN 0 ELSE 1 END) ELSE 0 END), 0) AS MONEY) AS OutstandingGBP
	FROM
		#Temp t
		INNER JOIN bettrans b WITH(NOLOCK, INDEX=IX_custid_matchid_bettype) ON t.custid = b.custid
		LEFT JOIN #ExchangeRate e ON e.exchangeid = b.currency
	WHERE b.matchid >= 0
	GROUP BY t.custid

	SELECT
		t.custid,
		username,
		closed,
		suspended,
		nickname,
		BAStatus,
		SpecialLevel,
		IsPowerBAUserTurnoff,
		RowNumber,
		CAST((ISNULL(d.TotalBalance, 0)	- isnULL(tl.actual_stake,0))					 AS MONEY) AS TotalBalance ,
		CAST((ISNULL(d.TotalBalanceUSD, 0) - isnULL(tl.actual_stake,0) * ISNULL(e.USD,0))	 AS MONEY) AS TotalBalanceUSD ,	
		CAST((ISNULL(d.TotalBalanceEUR, 0) - isnULL(tl.actual_stake,0) * ISNULL(e.EUR,0))	 AS MONEY) AS TotalBalanceEUR,
		CAST((ISNULL(d.TotalBalanceGBP, 0) - isnULL(tl.actual_stake,0) * ISNULL(e.GBP,0))	 AS MONEY) AS TotalBalanceGBP,
		CAST((ISNULL(d.Outstanding, 0)		+ ISNULL(tl.actual_stake,0))					 AS MONEY) AS Outstanding,
		CAST((ISNULL(d.OutstandingEUR, 0)	+ ISNULL(tl.actual_stake,0) * ISNULL(e.EUR,0))	 AS MONEY) AS OutstandingEUR,
		CAST((ISNULL(d.OutstandingUSD, 0)	+ ISNULL(tl.actual_stake,0) * ISNULL(e.USD,0))	 AS MONEY) AS OutstandingUSD,
		CAST((ISNULL(d.OutstandingGBP, 0)	+ ISNULL(tl.actual_stake,0) * ISNULL(e.GBP,0))	 AS MONEY) AS OutstandingGBP,
		ISNULL(lg.color, '') AS GroupColor,
		ISNULL(lg.GroupName, '') AS GroupName,
		ISNULL(lc.SBComm, 0) AS SBComm,
		ISNULL(lc.RacingComm, 0) AS RacingComm,
		ISNULL(lc.NGComm, 0) AS NGComm,
		ISNULL(lc.LCComm, 0) AS LCComm,
		ISNULL(lc.RNGComm, 0) AS RNGComm,
		ISNULL(lc.ParlayComm, 0) AS ParlayComm,
		ISNULL(lc.AllbetComm,0) AS AllbetComm,
		ISNULL(lg.id, 0) AS GroupCommID,
		ISNULL(UPPER(t.ugroup), '') AS OddsGroup
	FROM #Temp t
		LEFT JOIN #Data d ON t.custid = d.custid
		LEFT JOIN
		(
			SELECT SUM(actual_stake) actual_stake, Custid, Currency
			FROM #OutstandingTranslog
			GROUP BY Custid, Currency
		)tl ON t.custid = tl.Custid
		LEFT JOIN #ExchangeRate e ON tl.Currency = e.exchangeid
		LEFT JOIN bodb_Licensee.dbo.LicenseeCustComm lc WITH (NOLOCK) ON t.custid=lc.custid AND lc.Licenseeid = @Licenseeid
		LEFT JOIN bodb_Licensee.dbo.LicenseeGroupComm lg WITH (NOLOCK) ON lc.GroupCommID = lg.id
	ORDER BY t.username

	DROP TABLE #TempAg
	DROP TABLE #Temp
	DROP TABLE #OutstandingTranslog
	DROP TABLE #Data
	DROP TABLE #ExchangeRate
	DROP TABLE #tmpCust
	DROP TABLE #TempMember
END
GO