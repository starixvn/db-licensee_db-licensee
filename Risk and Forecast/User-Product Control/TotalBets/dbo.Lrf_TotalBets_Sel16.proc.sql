USE bodb02
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel16]	
	@PageSize	INT=50,
	@PageIndex	INT=0,
	@TotalRows	INT=0 OUTPUT,
	@AgentList	VARCHAR(MAX)
AS
/*
Created: 20101201@Henry
Task: Retrieve Total Bet values for HT/FT.
DB: DB052.bodb02
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

	totalHH MONEY,
	totalHHUSD MONEY,
	totalHHEUR MONEY,
	totalHHGBP MONEY,
	--
	totalHH_ori MONEY,
	totalHHUSD_ori MONEY,
	totalHHEUR_ori MONEY,
	totalHHGBP_ori MONEY,
	
	totalHD MONEY,
	totalHDUSD MONEY,
	totalHDEUR MONEY,
	totalHDGBP MONEY,
	--
	totalHD_ori MONEY,
	totalHDUSD_ori MONEY,
	totalHDEUR_ori MONEY,
	totalHDGBP_ori MONEY,
	
	totalHA MONEY,
	totalHAUSD MONEY,
	totalHAEUR MONEY,
	totalHAGBP MONEY,
	--
	totalHA_ori MONEY,
	totalHAUSD_ori MONEY,
	totalHAEUR_ori MONEY,
	totalHAGBP_ori MONEY,
	
	totalDH MONEY,
	totalDHUSD MONEY,
	totalDHEUR MONEY,
	totalDHGBP MONEY,
	---
	totalDH_ori MONEY,
	totalDHUSD_ori MONEY,
	totalDHEUR_ori MONEY,
	totalDHGBP_ori MONEY,
	
	totalDD MONEY,
	totalDDUSD MONEY,
	totalDDEUR MONEY,
	totalDDGBP MONEY,
	--
	totalDD_ori MONEY,
	totalDDUSD_ori MONEY,
	totalDDEUR_ori MONEY,
	totalDDGBP_ori MONEY,
	
	totalDA MONEY,
	totalDAUSD MONEY,
	totalDAEUR MONEY,
	totalDAGBP MONEY,
	----
	totalDA_ori MONEY,
	totalDAUSD_ori MONEY,
	totalDAEUR_ori MONEY,
	totalDAGBP_ori MONEY,
	
	totalAH MONEY,
	totalAHUSD MONEY,
	totalAHEUR MONEY,
	totalAHGBP MONEY,
	---
	totalAH_ori MONEY,
	totalAHUSD_ori MONEY,
	totalAHEUR_ori MONEY,
	totalAHGBP_ori MONEY,
	
	totalAD MONEY,
	totalADUSD MONEY,
	totalADEUR MONEY,
	totalADGBP MONEY,
	--
	totalAD_ori MONEY,
	totalADUSD_ori MONEY,
	totalADEUR_ori MONEY,
	totalADGBP_ori MONEY,
	
	totalAA MONEY,
	totalAAUSD MONEY,
	totalAAEUR MONEY,
	totalAAGBP MONEY,
	--
	totalAA_ori MONEY,
	totalAAUSD_ori MONEY,
	totalAAEUR_ori MONEY,
	totalAAGBP_ori MONEY,
	
	isNeutral BIT
)

INSERT INTO @Data
SELECT
		b.matchid,
		m.homeid,
		m.awayid,
		matchcode,
		
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )) AS totalHH,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalHHUSD,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalHHEUR,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.GBP) AS totalHHGBP,
		---
		SUM(CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN  stake   END ) AS totalHH_ori,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake END )*e.USD) AS totalHHUSD_ori,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake END )*e.EUR) AS totalHHEUR_ori,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 1 THEN stake END )*e.GBP) AS totalHHGBP_ori,
		
		
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )) AS totalHD,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalHDUSD,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalHDEUR,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.GBP) AS totalHDGBP,
		--
		SUM(CASE WHEN hdp1 = 1  AND hdp2 = 0 THEN  stake END ) AS totalHD_ori,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN  stake END )*e.USD) AS totalHDUSD_ori,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN  stake END )*e.EUR) AS totalHDEUR_ori,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN  -stake END )*e.GBP) AS totalHDGBP_ori,
		
		
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )) AS totalHA,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalHAUSD,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalHAEUR,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.GBP) AS totalHAGBP,
		--
		SUM(CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN  stake END ) AS totalHA_ori,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN  stake END )*e.USD) AS totalHAUSD_ori,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN  stake END )*e.EUR) AS totalHAEUR_ori,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN  stake END )*e.GBP) AS totalHAGBP_ori,
		
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )) AS totalDH,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalDHUSD,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalDHEUR,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.GBP) AS totalDHGBP,
		--
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN  stake END )) AS totalDH_ori,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN  stake END )*e.USD) AS totalDHUSD_ori,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN  stake END )*e.EUR) AS totalDHEUR_ori,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN  stake END )*e.GBP) AS totalDHGBP_ori,
		
		
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )) AS totalDD,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalDDUSD,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalDDEUR,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.GBP) AS totalDDGBP,
		--
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN  stake END )) AS totalDD_ori,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN  stake END )*e.USD) AS totalDDUSD_ori,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN  stake END )*e.EUR) AS totalDDEUR_ori,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN  stake END )*e.GBP) AS totalDDGBP_ori,
		
		
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )) AS totalDA,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalDAUSD,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalDAEUR,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.GBP) AS totalDAGBP,
		--
		SUM(CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN   stake END ) AS totalDA_ori,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN  stake END )*e.USD) AS totalDAUSD_ori,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN  stake END )*e.EUR) AS totalDAEUR_ori,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN  stake END )*e.GBP) AS totalDAGBP_ori,
		
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )) AS totalAH,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalAHUSD,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalAHEUR,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.GBP) AS totalAHGBP,
		--
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN  stake END )) AS totalAH_ori,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN  stake END )*e.USD) AS totalAHUSD_ori,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN  stake END )*e.EUR) AS totalAHEUR_ori,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN  stake END )*e.GBP) AS totalAHGBP_ori,
				
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )) AS totalAD,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalADUSD,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalADEUR,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.GBP) AS totalADGBP,
		--
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN  stake END )) AS totalAD_ori,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN  stake END )*e.USD) AS totalADUSD_ori,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN  stake END )*e.EUR) AS totalADEUR_ori,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN  stake END )*e.GBP) AS totalADGBP_ori,
		
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )) AS totalAA,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalAAUSD,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalAAEUR,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.GBP) AS totalAAGBP,
		--
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN  stake END )) AS totalAA_ori,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN  stake END )*e.USD) AS totalAAUSD_ori,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN  stake END )*e.EUR) AS totalAAEUR_ori,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN  stake END )*e.GBP) AS totalAAGBP_ori,
		
		
		isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		
	FROM  bettrans b with (nolock)
		INNER JOIN match m with (nolock) on m.matchid = b.matchid 	
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today)) e ON e.exchangeid = b.currency
		INNER JOIN @TempAg ag ON b.recommend = ag.CustId AND b.currency = ag.Currency
	WHERE    
		b.bettype = 16 AND
		b.statusID =0 AND
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
	SUM(totalHHUSD_ori) totalHHUSD,
	SUM(totalHHEUR_ori) totalHHEUR,
	SUM(totalHHGBP_ori) totalHHGBP,
	--
	SUM(totalHD_ori) totalHD,
	SUM(totalHDUSD_ori) totalHDUSD,
	SUM(totalHDEUR_ori) totalHDEUR,
	SUM(totalHDGBP_ori) totalHDGBP,
	
	SUM(totalHA_ori) totalHA,
	SUM(totalHAUSD_ori) totalHAUSD,
	SUM(totalHAEUR_ori) totalHAEUR,
	SUM(totalHAGBP_ori) totalHAGBP,
	---
	SUM(totalDH_ori) totalDH,
	SUM(totalDHUSD_ori) totalDHUSD,
	SUM(totalDHEUR_ori) totalDHEUR,
	SUM(totalDHGBP_ori) totalDHGBP,
	--
	SUM(totalDD_ori) totalDD,
	SUM(totalDDUSD_ori) totalDDUSD,
	SUM(totalDDEUR_ori) totalDDEUR,
	SUM(totalDDGBP_ori) totalDDGBP,
	
	----
	SUM(totalDA_ori) totalDA,
	SUM(totalDAUSD_ori) totalDAUSD,
	SUM(totalDAEUR_ori) totalDAEUR,
	SUM(totalDAGBP_ori) totalDAGBP,
	
	---
	SUM(totalAH_ori) totalAH,
	SUM(totalAHUSD_ori) totalAHUSD,
	SUM(totalAHEUR_ori) totalAHEUR,
	SUM(totalAHGBP_ori) totalAHGBP,
	--
	SUM(totalAD_ori) totalAD,
	SUM(totalADUSD_ori) totalADUSD,
	SUM(totalADEUR_ori) totalADEUR,
	SUM(totalADGBP_ori) totalADGBP ,
	
	SUM(totalAA_ori) totalAA,
	SUM(totalAAUSD_ori) totalAAUSD,
	SUM(totalAAEUR_ori) totalAAEUR,
	SUM(totalAAGBP_ori) totalAAGBP
FROM @Data

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel16] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel16] TO [vnteam]



