USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel6]	
	@PageSize	INT=50,
	@PageIndex	INT=0,
	@TotalRows	INT=0 OUTPUT,
	@AgentList	VARCHAR(MAX)
AS 
/*
Created: 20101201@Henry
DB: DB042.bodb02
Task : Retrieve Total bets for bettype 6
Original:[Age_TotalBets_Sel6_Ag]
Revisions:
	- 201134@Alex:CONVERT Currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20140508@Kyan: Add new bettype 1HTotalGoal 126
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150124@Winnie: Add base currency GBP 
	- 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20180802@Sophia: HA - use new index on DB042 [Redmine: #98631]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT>
*/	
				 
SET NOCOUNT ON

DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

DECLARE @TempAg AS TABLE ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO @TempAg (custID, currency)
	SELECT AgentId, Currency
	FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

	EXEC sp_xml_removedocument @DocHandler
END TRY

BEGIN CATCH
	SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

	RETURN
END CATCH;

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
	total01GBP MONEY,
	--
	total01_ori MONEY,
	total01USD_ori MONEY,
	total01EUR_ori MONEY,
	total01GBP_ori MONEY,
	
	total23 MONEY,
	total23USD MONEY,
	total23EUR MONEY,
	total23GBP MONEY,
	--
	total23_ori MONEY,
	total23USD_ori MONEY,
	total23EUR_ori MONEY,
	total23GBP_ori MONEY,
	
	total46 MONEY,
	total46USD MONEY,
	total46EUR MONEY,
	total46GBP MONEY,
	--
	total46_ori MONEY,
	total46USD_ori MONEY,
	total46EUR_ori MONEY,
	total46GBP_ori MONEY,
	
	total7over MONEY,
	total7overUSD MONEY,
	total7overEUR MONEY,
	total7overGBP MONEY,
	--
	total7over_ori MONEY,
	total7overUSD_ori MONEY,
	total7overEUR_ori MONEY,
	total7overGBP_ori MONEY,
	
	fhtotal01 MONEY,
	fhtotal01USD MONEY,
	fhtotal01EUR MONEY,
	fhtotal01GBP MONEY,
	--
	fhtotal01_ori MONEY,
	fhtotal01USD_ori MONEY,
	fhtotal01EUR_ori MONEY,
	fhtotal01GBP_ori MONEY,
	
	fhtotal23 MONEY,
	fhtotal23USD MONEY,
	fhtotal23EUR MONEY,
	fhtotal23GBP MONEY,
	--
	fhtotal23_ori MONEY,
	fhtotal23USD_ori MONEY,
	fhtotal23EUR_ori MONEY,
	fhtotal23GBP_ori MONEY,
	
	fhtotal4over MONEY,
	fhtotal4overUSD MONEY,
	fhtotal4overEUR MONEY,
	fhtotal4overGBP MONEY,
	--
	fhtotal4over_ori MONEY,
	fhtotal4overUSD_ori MONEY,
	fhtotal4overEUR_ori MONEY,
	fhtotal4overGBP_ori MONEY,
	
	isNeutral BIT
)

INSERT INTO @Data
SELECT   
		b.matchid,
		m.homeid,
		m.awayid,
		matchcode,
		
		-- FT Total Goals
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END))  AS total01,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS total01USD,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS total01EUR,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.GBP)  AS total01GBP,
		--
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN  stake END END))  AS total01_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN  stake END END)*e.USD)  AS total01USD_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN  stake END END)*e.EUR)  AS total01EUR_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN  stake END END)*e.GBP)  AS total01GBP_ori,
		
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END))  AS total23,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS total23USD,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS total23EUR,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.GBP)  AS total23GBP,
		--
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN  stake END END))  AS total23_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN  stake END END)*e.USD)  AS total23USD_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN  stake END END)*e.EUR)  AS total23EUR_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN  stake END END)*e.GBP)  AS total23GBP_ori,
		
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN (stake*odds)-stake ELSE -stake END END))  AS total46,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS total46USD,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS total46EUR,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN (stake*odds)-stake ELSE -stake END END)*e.GBP)  AS total46GBP,
		--
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN  stake END END))  AS total46_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN  stake END END)*e.USD)  AS total46USD_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN  stake END END)*e.EUR)  AS total46EUR_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN  stake END END)*e.GBP)  AS total46GBP_ori,
		
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN (stake*odds)-stake ELSE -stake END END))  AS total7over,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS total7overUSD,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS total7overEUR,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.GBP)  AS total7overGBP,
		--
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN  stake END END))  AS total7over_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN  stake END END)*e.USD)  AS total7overUSD_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN  stake END END)*e.EUR)  AS total7overEUR_ori,
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN  stake END END)*e.GBP)  AS total7overGBP_ori,
		
		--1H Total Goals
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)) AS FHtotal01,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS FHtotal01USD,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS FHtotal01EUR,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.GBP)  AS FHtotal01GBP,
		--
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN  stake END END)) AS FHtotal01_ori,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN  stake END END)*e.USD)  AS FHtotal01USD_ori,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN  stake END END)*e.EUR)  AS FHtotal01EUR_ori,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN  stake END END)*e.GBP)  AS FHtotal01GBP_ori,
		
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END))  AS FHtotal23,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS FHtotal23USD,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS FHtotal23EUR,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.GBP)  AS FHtotal23GBP,
		--
		SUM(CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN  stake END END)  AS FHtotal23_ori, 
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN  stake END END)*e.USD)  AS FHtotal23USD_ori,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN  stake END END)*e.EUR)  AS FHtotal23EUR_ori,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN  stake END END)*e.GBP)  AS FHtotal23GBP_ori,
		
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN (stake*odds)-stake ELSE -stake END END))  AS FHtotal4over,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.USD)  AS FHtotal4overUSD,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.EUR)  AS FHtotal4overEUR,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.GBP)  AS FHtotal4overGBP,
		--
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN stake END END))  AS FHtotal4over_ori,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN stake END END)*e.USD)  AS FHtotal4overUSD_ori,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN stake END END)*e.EUR)  AS FHtotal4overEUR_ori,
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN stake END END)*e.GBP)  AS FHtotal4overGBP_ori,
		
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		
	FROM  bettrans b WITH (nolock)
		INNER JOIN match m with (nolock) ON m.matchid = b.matchid 
 		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e ON e.exchangeid = b.currency
		INNER JOIN @TempAg ag ON b.recommend = ag.CustId AND b.currency = ag.Currency
	WHERE b.bettype in (6, 126) -- 6: Total Goal, 126: 1H Total Goal
		AND b.statusID IN(0,1)
		AND m.eventstatus = 'running'
		AND tpositiontaking<>0
	GROUP BY
		b.matchid,
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
SELECT 
	 
	SUM(total01_ori) total01,
	SUM(total01USD_ori) total01USD,
	SUM(total01EUR_ori) total01EUR,
	SUM(total01GBP_ori) total01GBP,
	
	SUM(total23_ori) total23,
	SUM(total23USD_ori) total23USD,
	SUM(total23EUR_ori) total23EUR,
	SUM(total23GBP_ori) total23GBP,
	--
	SUM(total46_ori) total46,
	SUM(total46USD_ori) total46USD,
	SUM(total46EUR_ori) total46EUR,
	SUM(total46GBP_ori) total46GBP,
	--
	SUM(total7over_ori) total7over,
	SUM(total7overUSD_ori) total7overUSD,
	SUM(total7overEUR_ori) total7overEUR,
	SUM(total7overGBP_ori) total7overGBP,
	--
	SUM(fhtotal01_ori) fhtotal01 ,
	SUM(fhtotal01USD_ori) fhtotal01USD,
	SUM(fhtotal01EUR_ori) fhtotal01EUR,
	SUM(fhtotal01GBP_ori) fhtotal01GBP,
	--
	SUM(fhtotal23_ori) fhtotal23,
	SUM(fhtotal23USD_ori) fhtotal23USD,
	SUM(fhtotal23EUR_ori) fhtotal23EUR,
	SUM(fhtotal23GBP_ori) fhtotal23GBP,
	--
	SUM(fhtotal4over_ori) fhtotal4over,
	SUM(fhtotal4overUSD_ori) fhtotal4overUSD,
	SUM(fhtotal4overEUR_ori) fhtotal4overEUR,
	SUM(fhtotal4overGBP_ori) fhtotal4overGBP
FROM @Data

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel6] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel6] TO [vnteam]

