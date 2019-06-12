/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel16]	
	@PageSize		INT=50,
	@PageIndex		INT=0,
	@TotalRows		INT=0 OUTPUT,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(3) = ''
AS
/*
Created: 20101201@Henry
Task: Retrieve Total Bet values for HT/FT.
DB: DB042.bodb02
Original: [Age_TotalBets_Sel16_Ag]

Revisions:
	- 201134@Alex:Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily 
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150123@Jim: support base on Currency GBP
	- 20150617@Jim:  Enhance Total Bets with sum values of running stakes  (Feature #36839)
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20180802@Sophia: HA - Status IN (0,1) to use new index on DB042 [Redmine: #98631]
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

CREATE TABLE #TempAg ( CustId INT,Currency INT )
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

	totalHH MONEY,
	--
	totalHH_ori MONEY,
	
	totalHD MONEY,
	--
	totalHD_ori MONEY,
	
	totalHA MONEY,
	--
	totalHA_ori MONEY,
	
	totalDH MONEY,
	---
	totalDH_ori MONEY,
	
	totalDD MONEY,
	--
	totalDD_ori MONEY,
	
	totalDA MONEY,
	----
	totalDA_ori MONEY,
	
	totalAH MONEY,
	---
	totalAH_ori MONEY,
	
	totalAD MONEY,
	--
	totalAD_ori MONEY,
	
	totalAA MONEY,
	--
	totalAA_ori MONEY,
	
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
		
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.Rate) AS totalHH,
		---
		SUM( CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake*e.Rate END ) AS totalHH_ori,

		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.Rate) AS totalHD,
		--
		SUM( CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN  stake*e.Rate END ) AS totalHD_ori,

		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.Rate) AS totalHA,
		--
		SUM( CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN  stake*e.Rate END ) AS totalHA_ori,
		
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.Rate) AS totalDH,
		--
		SUM( CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN  stake*e.Rate END ) AS totalDH_ori,
		
		
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.Rate) AS totalDD,
		--
		SUM( CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN  stake*e.Rate END ) AS totalDD_ori,
		
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.Rate) AS totalDA,
		--
		SUM( CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN   stake*e.Rate END ) AS totalDA_ori,
		
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.Rate) AS totalAH,
		--
		SUM( CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN  stake*e.Rate END ) AS totalAH_ori,
				
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.Rate) AS totalAD,
		--
		SUM( CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN  stake*e.Rate END ) AS totalAD_ori,
		
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.Rate) AS totalAA,
		--
		SUM( CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN  stake*e.Rate END ) AS totalAA_ori,

		isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		
	FROM  bettrans b with (nolock)
		INNER JOIN #tempAg ag ON b.recommend = ag.CustId AND b.currency = ag.Currency
		INNER JOIN match m with (nolock) on m.matchid = b.matchid 	
		INNER JOIN @ExchangeRate e ON e.exchangeid = b.currency
	WHERE    
		b.bettype = 16 AND
		b.statusID IN (0,1) AND
		m.matchid>0 AND
		m.eventstatus='running' AND
		b.tpositiontaking<>	0
	GROUP BY b.matchid,	
		m.homeid,
		m.awayid,	
		matchcode,
		m.isNeutral	
	ORDER BY m.matchcode
	


IF @TotalRows = 0  
BEGIN  
	SELECT @TotalRows = COUNT(matchid) FROM @Data
END

SELECT 
	c.*
FROM
(
	SELECT
		ROW_NUMBER() over (ORDER BY matchcode) AS RowNum ,
		* 
	FROM @Data
	
) c WHERE c.RowNum BETWEEN @RowStart AND @RowEnd

SELECT 
	 
	SUM(totalHH_ori) totalHH,
	--
	SUM(totalHD_ori) totalHD,
	
	SUM(totalHA_ori) totalHA,
	---
	SUM(totalDH_ori) totalDH,
	--
	SUM(totalDD_ori) totalDD,
	
	----
	SUM(totalDA_ori) totalDA,
	
	---
	SUM(totalAH_ori) totalAH,
	--
	SUM(totalAD_ori) totalAD,
	
	SUM(totalAA_ori) totalAA
FROM @Data

DROP TABLE #TempAg

GO



