/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO
 
ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel6]	
	@PageSize		INT=50,
	@PageIndex		INT=0,
	@TotalRows		INT=0 OUTPUT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3)= ''
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
	- 20190611@Amanda: Add Base Currency parameter [Redmine: #112531]

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

CREATE TABLE #tempAg ( CustId INT,Currency INT )
DECLARE @DocHandler INT

BEGIN TRY
	EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	INSERT INTO #tempAg (custID, currency)
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
	--
	total01_ori MONEY,
	
	total23 MONEY,
	--
	total23_ori MONEY,
	
	total46 MONEY,
	--
	total46_ori MONEY,
	
	total7over MONEY,
	--
	total7over_ori MONEY,
	
	fhtotal01 MONEY,
	--
	fhtotal01_ori MONEY,
	
	fhtotal23 MONEY,
	--
	fhtotal23_ori MONEY,
	
	fhtotal4over MONEY,
	--
	fhtotal4over_ori MONEY,
	
	isNeutral BIT
)

DECLARE @ExchangeRate AS TABLE (ExchangeId INT, Rate FLOAT)
DECLARE @SQL VARCHAR(200)

SELECT @SQL =	'SELECT ExchangeId, ' + CASE WHEN ISNULL(@BaseCurrency, '') <> '' THEN @BaseCurrency ELSE '1' END + ' AS Rate ' +
				'FROM Lrf_f_GetExchangeDaily(''' + CONVERT(VARCHAR(10), @Today, 120) + ''',''' + CONVERT(VARCHAR(10), @Today, 120) + ''') e ' +
				'WHERE EXISTS (SELECT TOP (1) 1 FROM #TempAg a WHERE a.Currency = e.ExchangeId)'
			
INSERT INTO @ExchangeRate(ExchangeId, Rate)
EXECUTE(@SQL)


INSERT INTO @Data
SELECT   
		b.matchid,
		m.homeid,
		m.awayid,
		matchcode,
		
		-- FT Total Goals
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.Rate)  AS total01,
		--
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '0-1'  THEN  stake END END)*e.Rate)  AS total01_ori,
		
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.Rate)  AS total23,
		--
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '2-3'  THEN  stake END END)*e.Rate)  AS total23_ori,
		
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN (stake*odds)-stake ELSE -stake END END)*e.Rate)  AS total46,
		--
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '4-6'  THEN  stake END END)*e.Rate)  AS total46_ori,
		
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.Rate)  AS total7over,
		--
		SUM((CASE bettype WHEN 6 THEN CASE betteam WHEN '7-over'  THEN  stake END END)*e.Rate)  AS total7over_ori,
		
		--1H Total Goals
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN (stake*odds)-stake ELSE -stake END END)*e.Rate) AS FHtotal01,
		--
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '0-1'  THEN  stake END END)*e.Rate) AS FHtotal01_ori,
		
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN (stake*odds)-stake ELSE -stake END END)*e.Rate)  AS FHtotal23,
		--
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '2-3'  THEN  stake END END)*e.Rate)  AS FHtotal23_ori,
		
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN (stake*odds)-stake ELSE -stake END END)*e.Rate)  AS FHtotal4over,
		--
		SUM((CASE bettype WHEN 126 THEN CASE betteam WHEN '4-over'  THEN stake END END)*e.Rate)  AS FHtotal4over_ori,
		
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		
	FROM  bettrans b WITH (nolock)
		INNER JOIN #tempAg ag ON b.recommend = ag.CustId AND b.currency = ag.Currency
		INNER JOIN match m with (nolock) ON m.matchid = b.matchid 
 		INNER JOIN @ExchangeRate e ON e.exchangeid = b.currency
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
	
	SUM(total23_ori) total23,
	--
	SUM(total46_ori) total46,
	--
	SUM(total7over_ori) total7over,
	--
	SUM(fhtotal01_ori) fhtotal01 ,
	--
	SUM(fhtotal23_ori) fhtotal23,
	--
	SUM(fhtotal4over_ori) fhtotal4over
FROM @Data

DROP TABLE #tempAg

GO

