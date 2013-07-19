set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER   PROCEDURE [dbo].[Lrf_CustomerSel]
	@LicenseeID INT,
	@UserID		  INT,	
	@CurrencyID INT=0,
	@LicenseeType VARCHAR(100) = NULL,
	@username VARCHAR(50) = NULL,
	@PageSize INT = 50,
	@PageIndex INT = 1,
	@BAFilter SMALLINT = 0,
	@CustStatus varchar(50)='' ,
	@TotalRows INT = 0  OUTPUT,
	@SpecialLevel INT = -1, --ALL
	@GroupCommID INT = -1 --ALL
	
AS

/*
	Created by: [20101203@Henry]
	Task: Member List 
	DB: DB052.BODB02 
	Original: Acc_CustomerSelByAg
	Revisions:
	-- 20110218@Jacob: Calculate the today balance, yesterday balance, outstanding
	-- 20110305@Henry: Allow to choose all type of licensee AND all currency + suppport based currency
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
	Param's Explanation:
	  + @BAFilter: support filter BA members (0: both BA + non BA, 1: BA Members only, 2: non-BA members)
	  + @SpecialLevel: default value = -1 (all)
	
*/

SET NOCOUNT ON
DECLARE @currentDate DATETIME   
SELECT @currentDate = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

		
DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK ) 
						INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID	
                WHERE    [Description] = COALESCE(@LicenseeType,  
                                                     [Description])  
	DROP TABLE #Currency 
SET @Username = isnull(@Username, '')

CREATE TABLE #Temp
(
	custid INT PRIMARY KEY,
	username NVARCHAR (50),
	closed BIT,
	nickname NVARCHAR (50),
	BAStatus BIT,
	SpecialLevel INT,
	IsPowerBAUserTurnoff BIT,
	RowNumber INT
)
DECLARE @TempMember AS TABLE(CustID INT PRIMARY KEY CLUSTERED, speciallevel int, username2 varchar(50))  

DECLARE @TempBACust AS TABLE (ID INT IDENTITY(1,1),CustID INT)
DECLARE @CustID INT, @i INT, @max INT,@LastOffBy INT


IF LEN(@Username)=0
BEGIN
	IF @BAFilter=0 
	BEGIN
		INSERT INTO @TempMember (CustID,speciallevel,username2)
		SELECT c.CustID , lc.speciallevel,lc.username2
		FROM CustInfo c (NOLOCK) 
			INNER JOIN @TempAg t ON c.recommend = t.custid
			INNER JOIN bodb_licensee.dbo.LicenseeCustInfo lc WITH (NOLOCK) ON c.custid = lc.custid
			LEFT JOIN bodb_licensee.dbo.LicenseeCustComm cc ON c.custid = cc.custid AND cc.Licenseeid=@LicenseeID
		WHERE 
			c.roleid=1 
			AND ((@CustStatus='') OR (@CustStatus IN ('Open') AND closed=0) OR (@CustStatus='Closed' AND closed = 1))
			AND ((@CustStatus IN('','Closed')) OR (@CustStatus = 'Open' AND ISNULL(reject,0)=0) )
			AND (@SpecialLevel=-1 OR (@SpecialLevel<>-1 AND lc.SpecialLevel=@SpecialLevel)  )
			AND (@GroupCommID=-1 OR (@GroupCommID<>-1 AND ISNULL(cc.GroupCommID,0)=@GroupCommID ))
		IF ISNULL(@TotalRows,0) = 0
		BEGIN
			SELECT @TotalRows = COUNT(c.custid)
			FROM @TempMember c 
		END

		INSERT INTO #Temp (custid, username,closed,nickname, BAStatus,SpecialLevel, RowNumber)
		SELECT * FROM 
		(
			SELECT 
				ci.custid, 
				ci.username, 
				ci.closed,
				SUBSTRING(m.username2,  CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
				CASE WHEN lb.CustID IS NULL THEN 0 ELSE 1 END AS BAStatus,
				m.SpecialLevel,
				ROW_NUMBER() OVER (ORDER BY ci.custid asc) AS RowNumber 
			FROM
				@TempMember m 
				INNER JOIN CustInfo ci (NOLOCK) ON m.custid = ci.custid
				LEFT JOIN bodb_Licensee.dbo.LicenseeBAHistory lb with (nolock) ON LicenseeID=@LicenseeID AND ci.CustID = lb.CustID AND lb.Status= 'Running'
		) a 
		WHERE 
			a.rownumber BETWEEN @rowstart AND @rowend
	END
	ELSE IF @BAFilter=1
	BEGIN
		INSERT INTO @TempMember (CustID,speciallevel,username2)
		SELECT ci.CustID , lc.speciallevel,lc.username2
		FROM bodb_Licensee.dbo.LicenseeBAHistory lb with (nolock)
			INNER JOIN CustInfo ci (NOLOCK) ON lb.custid = ci.custid
			INNER JOIN @TempAg t ON ci.recommend = t.custid
			INNER JOIN bodb_licensee.dbo.LicenseeCustInfo lc WITH (NOLOCK) ON ci.custid = lc.custid
			LEFT JOIN bodb_licensee.dbo.LicenseeCustComm cc ON ci.custid = cc.custid AND cc.Licenseeid=@LicenseeID
		WHERE 
			lb.LicenseeID=@LicenseeID
			AND lb.Status= 'Running'
			AND ((@CustStatus='') OR (@CustStatus IN ('Open') AND closed=0) OR (@CustStatus='Closed' AND closed = 1))
			AND ((@CustStatus IN('','Closed')) OR (@CustStatus = 'Open' AND ISNULL(reject,0)=0))
			AND (@SpecialLevel=-1 OR (@SpecialLevel<>-1 AND lc.SpecialLevel=@SpecialLevel)  )
			AND (@GroupCommID=-1 OR (@GroupCommID<>-1 AND ISNULL(cc.GroupCommID,0)=@GroupCommID ))
		IF ISNULL(@TotalRows,0) = 0
		BEGIN
			SELECT @TotalRows = COUNT(c.custid)
			FROM @TempMember c
		END
		INSERT INTO #Temp (custid, username,closed, nickname, BAStatus,SpecialLevel, RowNumber)
		SELECT * FROM 
		(
			SELECT 
				ci.custid, 
				ci.username, 
				ci.closed,
				SUBSTRING(m.username2,  CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
				1 AS BAStatus, 
				m.SpecialLevel, 
				ROW_NUMBER() OVER (ORDER BY ci.custid asc) AS RowNumber 
			FROM
				@TempMember m 
				INNER JOIN CustInfo ci (NOLOCK) ON m.custid = ci.custid
		) a 
		WHERE 
			a.rownumber BETWEEN @rowstart AND @rowend

	END 
	ELSE IF @BAFilter = 2
	BEGIN
		INSERT INTO @TempMember (CustID,speciallevel,username2) 
		SELECT c.CustID , lc.speciallevel,lc.username2
		FROM CustInfo c (NOLOCK) 
			INNER JOIN @TempAg t ON c.recommend = t.custid
			INNER JOIN bodb_licensee.dbo.LicenseeCustInfo lc WITH (NOLOCK) ON c.custid = lc.custid
			LEFT JOIN bodb_Licensee.dbo.LicenseeBAHistory lb WITH (NOLOCK) ON LicenseeID=@LicenseeID AND c.custid = lb.custid AND lb.Status= 'Running'
			LEFT JOIN bodb_licensee.dbo.LicenseeCustComm cc ON c.custid = cc.custid AND cc.Licenseeid=@LicenseeID
		WHERE 
			c.roleid=1 
			AND ((@CustStatus='') OR (@CustStatus IN ('Open') AND closed=0) OR (@CustStatus='Closed' AND closed = 1))
			AND ((@CustStatus IN('','Closed')) OR (@CustStatus = 'Open' AND ISNULL(reject,0)=0) )
			AND ISNULL(lb.CustID ,0)=0
			AND (@SpecialLevel=-1 OR (@SpecialLevel<>-1 AND lc.SpecialLevel=@SpecialLevel)  )
			AND (@GroupCommID=-1 OR (@GroupCommID<>-1 AND ISNULL(cc.GroupCommID,0)=@GroupCommID ))
		
		IF ISNULL(@TotalRows,0) = 0
		BEGIN
			SELECT @TotalRows = COUNT(c.custid)
			FROM @TempMember c
		END		
	
		INSERT INTO #Temp (custid, username,closed,nickname, BAStatus,SpecialLevel, RowNumber)
		SELECT * FROM 
		(
			SELECT 
				ci.custid, 
				ci.username, 
				ci.closed,
				SUBSTRING(m.username2,  CHARINDEX('$',m.username2)+1, LEN(m.username2)-CHARINDEX('$',m.username2)) AS nickname,
				0 AS BAStatus, 
				m.SpecialLevel, 
				ROW_NUMBER() OVER (ORDER BY ci.custid asc) AS RowNumber 
			FROM
				@TempMember m 
				INNER JOIN CustInfo ci (NOLOCK) ON m.custid = ci.custid
				
		) a 
		WHERE 
			a.rownumber BETWEEN @rowstart AND @rowend
	END

END
ELSE
BEGIN
	SET @username = LTRIM(RTRIM(@username))
	
	INSERT INTO @TempMember
	SELECT c.CustID ,null,null 
	FROM bodb_Licensee.dbo.LicenseeCustinfo c WITH (NOLOCK) 
		INNER JOIN @TempAg t ON c.recommend = t.custid
		LEFT JOIN bodb_licensee.dbo.LicenseeCustComm cc ON c.custid = cc.custid AND cc.Licenseeid=@LicenseeID
	WHERE 
		(c.username2 LIKE + '%$' + @Username + '%' OR c.username LIKE @Username + '%')
		AND (@GroupCommID=-1 OR (@GroupCommID<>-1 AND ISNULL(cc.GroupCommID,0)=@GroupCommID ))
	
						
	IF ISNULL(@TotalRows,0) = 0
	BEGIN
		IF @BAFilter=0
		BEGIN
			SELECT 
				@TotalRows = COUNT(ci.custid)
			FROM 
				custinfo ci (nolock)  INNER JOIN @TempMember t ON ci.custid = t.custid
				INNER JOIN bodb_licensee.dbo.LicenseeCustInfo lc WITH (NOLOCK) ON ci.custid = lc.custid
			WHERE 
				((@CustStatus='') OR (@CustStatus IN ('Open') AND closed=0) OR (@CustStatus='Closed' AND closed = 1))
				AND ((@CustStatus IN('','Closed')) OR (@CustStatus = 'Open' AND ISNULL(reject,0)=0))
				AND (@SpecialLevel=-1 OR (@SpecialLevel<>-1 AND lc.SpecialLevel=@SpecialLevel)  )
		END
		ELSE
		BEGIN
			SELECT 
				@TotalRows = COUNT(ci.custid)
			FROM 
				custinfo ci (nolock)  INNER JOIN @TempMember t ON ci.custid = t.custid
				INNER JOIN bodb_licensee.dbo.LicenseeCustInfo lc WITH (NOLOCK) ON ci.custid = lc.custid
				LEFT JOIN 
						bodb_Licensee.dbo.LicenseeBAHistory lb WITH (nolock) ON LicenseeID = @LicenseeID AND ci.custid = lb.custid AND lb.Status= 'Running'
			WHERE 
				((@CustStatus='') OR (@CustStatus IN ('Open') AND closed=0) OR (@CustStatus='Closed' AND closed = 1))
				AND ((@CustStatus IN('','Closed')) OR (@CustStatus = 'Open' AND ISNULL(reject,0)=0))
				AND ((@BAFilter=0) OR (@BAFilter=1 AND isnull(lb.Status,'') = 'Running') OR (@BAFilter=2 AND isnull(lb.Status,'') <> 'Running'))
				AND (@SpecialLevel=-1 OR (@SpecialLevel<>-1 AND lc.SpecialLevel=@SpecialLevel)  )
		END
	END
	
	

	INSERT INTO #Temp (custid, username,closed, nickname, BAStatus,SpecialLevel, RowNumber)
	SELECT * FROM 
	(
		SELECT 
			ci.custid, 
			ci.username, 
			ci.closed,
			SUBSTRING(lc.username2,  CHARINDEX('$',lc.username2)+1, LEN(lc.username2)-CHARINDEX('$',lc.username2)) AS nickname,
			CASE WHEN lb.CustID is NULL THEN 0 ELSE 1 END AS BAStatus, 
			lc.SpecialLevel, 
			ROW_NUMBER() OVER (ORDER BY ci.currency asc, ci.custid asc) AS RowNumber 
		FROM
			custinfo ci (nolock)  INNER JOIN @TempMember t ON ci.custid = t.custid
			INNER JOIN bodb_licensee.dbo.LicenseeCustInfo lc WITH (NOLOCK) ON ci.custid = lc.custid
			LEFT JOIN 
				bodb_Licensee.dbo.LicenseeBAHistory lb WITH (nolock) ON LicenseeID = @LicenseeID AND ci.custid = lb.custid AND lb.Status= 'Running'
			LEFT JOIN
				bodb_Licensee.dbo.Users u with (nolock) ON lb.OnBy = u.userid		
		WHERE 
			((@CustStatus='') OR (@CustStatus IN ('Open') AND closed=0) OR (@CustStatus='Closed' AND closed = 1))
			AND ((@CustStatus IN('','Closed')) OR (@CustStatus = 'Open' AND ISNULL(reject,0)=0))
			AND ((@BAFilter=0) OR (@BAFilter=1 AND isnull(lb.Status,'') = 'Running') OR (@BAFilter=2 AND isnull(lb.Status,'') <> 'Running'))
			AND (@SpecialLevel=-1 OR (@SpecialLevel<>-1 AND lc.SpecialLevel=@SpecialLevel)  )
			
	) a 
	WHERE 
		a.rownumber BETWEEN @rowstart AND @rowend

END

CREATE NONCLUSTERED INDEX IDX_Custid ON #Temp(custid)

--Case 1: BA is ON
UPDATE #Temp SET IsPowerBAUserTurnoff = 0
WHERE BAStatus = 1

--Case 2: BA is OFF
--Case 2.1: never turn-off BA
UPDATE #Temp SET IsPowerBAUserTurnoff = 0
WHERE BAStatus = 0 AND CustID NOT IN (
	SELECT DISTINCT CustID FROM bodb_Licensee.dbo.LicenseeBAHistory lb WITH (nolock)
	WHERE LicenseeID = @LicenseeID AND Status= 'Done'
)

--Case 2.2 turned on BA before
INSERT INTO @TempBACust (CustID)
SELECT CustID FROM #Temp
WHERE BAStatus =0 AND IsPowerBAUserTurnoff IS NULL

IF (SELECT count (*) FROM @TempBACust) > 0
BEGIN
	SELECT @i=0
	SELECT @max = max(id) FROM @TempBACust
	WHILE @i < @MAX
	BEGIN
		SET @i = @i + 1
		SET @LastOffBy = 0
		SELECT @CustID = CustID FROM @TempBACust WHERE id = @i
		
		--Get last turn-off BA UserID
		SELECT Top 1 @LastOffBy = OffBy FROM bodb_licensee.dbo.[LicenseeBAHistory] WITH (NOLOCK)
		WHERE
				[LicenseeID] = @LicenseeID AND
				[CustID] = @CustID AND
				[Status] = 'Done'
		ORDER BY ID DESC

		--Check whether the Last turn-off BA is Power BA user or not
		--If is Power BA User then only Power BA Users can turn-on again
		IF ISNULL(@LastOffBy,0) <> 0 AND EXISTS (
			SELECT 1 FROM bodb_licensee.dbo.LicenseeUserFunctions WITH (NOLOCK) WHERE FunctionID = 54
			AND UserID = ISNULL(@LastOffBy,0)
			AND LicenseeID=@LicenseeID
		) 
		BEGIN
			UPDATE #Temp SET IsPowerBAUserTurnoff = 1 WHERE CustID = @CustID
		END
	END			
END

--Case 3 update the rest
UPDATE #Temp SET IsPowerBAUserTurnoff = 0 WHERE IsPowerBAUserTurnoff IS NULL


SELECT 
	t.*
	,ISNULL(SUM(ISNULL(b.winlost-b.actual_stake + b.playercomm,0)),0)  AS TotalBalance
	,CAST(ISNULL(SUM(e.USD*ISNULL(b.winlost-b.actual_stake + b.playercomm,0)),0) AS MONEY) AS TotalBalanceUSD
	,CAST(ISNULL(SUM(e.EUR*ISNULL(b.winlost-b.actual_stake + b.playercomm,0)),0) AS MONEY) AS TotalBalanceEUR
	,ISNULL(SUM(CASE WHEN ruben=0 THEN ISNULL(actual_stake,0) ELSE 0 END),0) AS Outstanding
	,CAST(ISNULL(SUM(e.USD*CASE WHEN ruben=0 THEN ISNULL(actual_stake,0) ELSE 0 END),0) AS MONEY) AS OutstandingUSD
	,CAST(ISNULL(SUM(e.EUR*CASE WHEN ruben=0 THEN ISNULL(actual_stake,0) ELSE 0 END),0) AS MONEY) AS OutstandingEUR
	,ISNULL(lg.color,'') AS GroupColor
	,ISNULL(lg.GroupName,'') AS GroupName
	,ISNULL(lc.SBComm,0) AS SBComm
	,ISNULL(lc.RacingComm,0) AS RacingComm
	,ISNULL(lc.NGComm,0) AS NGComm
	,ISNULL(lg.id,0) AS GroupCommID

FROM #Temp t
	LEFT JOIN bettrans b WITH(NOLOCK,INDEX=IX_custid_matchid_bettype) ON t.custid = b.custid
	LEFT JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@currentDate,@currentDate))e  
			ON e.exchangeid = b.currency
	LEFT JOIN bodb_Licensee.dbo.LicenseeCustComm lc WITH (NOLOCK) ON t.custid=lc.custid AND lc.Licenseeid = @Licenseeid
	LEFT JOIN bodb_Licensee.dbo.LicenseeGroupComm lg WITH (NOLOCK) ON lc.GroupCommID = lg.id
GROUP BY t.custid, t.username, t.nickname, t.BAStatus, t.RowNumber,t.closed, t.SpecialLevel, t.IsPowerBAUserTurnoff,lg.color,lg.groupname,lc.SBComm,lc.RacingComm,lc.NGComm,lg.id
ORDER BY t.username

DROP TABLE #Temp

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerSel] TO [vnteam]

