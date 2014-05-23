USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_TotalBets_Sel6]    Script Date: 05/23/2014 10:17:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel6]
	@LicenseeID INT,
	@CurrencyID INT=0,
	@UserID		INT,
	@licenseetype VARCHAR(100) = NULL,
	@PageSize INT=50,
	@PageIndex INT=0,
	@TotalRows INT=0 OUTPUT
AS
/*
Created: 20101201@Henry
DB: DB052.bodb02
Task : Retrieve Total bets for bettype 6
Original:[Age_TotalBets_Sel6_Ag]
Revisions:
	- 201134@Alex:CONVERT Currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20140508@Kyan: Add new bettype 1HTotalGoal 126
*/					 
SET NOCOUNT ON
DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (CustID INT)
INSERT INTO @TempAg (CustID)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc WITH ( NOLOCK )  
				INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
--------------------
DROP TABLE #currency
--------------------

DECLARE @RowCount INT, @RowStart INT, @RowEnd INT  
SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

DECLARE @Data AS TABLE
(
	matchid INT,
	homeID INT,
	awayID INT,
	matchcode nvarchar(50),
	total01 MONEY,
	total01USD MONEY,
	total01EUR MONEY,

	total23 MONEY,
	total23USD MONEY,
	total23EUR MONEY,
	
	total46 MONEY,
	total46USD MONEY,
	total46EUR MONEY,

	total7over MONEY,
	total7overUSD MONEY,
	total7overEUR MONEY,
	
	fhtotal01 MONEY,
	fhtotal01USD MONEY,
	fhtotal01EUR MONEY,

	fhtotal23 MONEY,
	fhtotal23USD MONEY,
	fhtotal23EUR MONEY,
	
	fhtotal4over MONEY,
	fhtotal4overUSD MONEY,
	fhtotal4overEUR MONEY,
	
	isNeutral BIT
)

INSERT INTO @Data
SELECT   
		bettrans.matchid,
		m.homeid,
		m.awayid,
		matchcode,
		
		-- FT Total Goals
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END))  AS total01,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS total01USD,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS total01EUR,
		
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END))  AS total23,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS total23USD,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS total23EUR,
		
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN (stake*odds)-stake ELSE -stake END END))  AS total46,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS total46USD,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS total46EUR,
		
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN (stake*odds)-stake ELSE -stake END END))  AS total7over,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS total7overUSD,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS total7overEUR,
		
		--1H Total Goals
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)) AS FHtotal01,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS FHtotal01USD,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS FHtotal01EUR,
		
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END))  AS FHtotal23,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS FHtotal23USD,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS FHtotal23EUR,
		
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN (stake*odds)-stake ELSE -stake END END))  AS FHtotal4over,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS FHtotal4overUSD,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS FHtotal4overEUR,
		
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		
	FROM  bettrans WITH (nolock)
		INNER JOIN match m with (nolock) ON m.matchid = bettrans.matchid 
 		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
		ON e.exchangeid = bettrans.currency
	WHERE    
		bettrans.recommend IN (SELECT CustID FROM @TempAg)
		--AND bettrans.bettype =6 
		AND bettrans.bettype in (6, 126) -- 6: Total Goal, 126: 1H Total Goal
		AND bettrans.statusID = 0
		AND bettrans.ruben = 0
		AND m.eventstatus = 'running'
		AND tpositiontaking<>0
	GROUP BY
		bettrans.matchid,
		m.homeid,
		m.awayid,
		matchcode,
		m.isNeutral
	ORDER BY m.matchcode
	
IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = count(matchid) FROM @Data
	
END

SELECT c.* FROM
(
	SELECT   
		ROW_NUMBER() over (ORDER BY matchcode) AS RowNum ,
		* 
	FROM @Data
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel6] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel6] TO [vnteam]

