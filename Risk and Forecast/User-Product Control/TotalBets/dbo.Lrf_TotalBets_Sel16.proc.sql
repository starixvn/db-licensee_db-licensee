ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel16]
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
*/

SET NOCOUNT ON

DECLARE @Today SMALLDATETIME 
SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (CustID INT)
INSERT INTO @TempAg (CustID)
SELECT  DISTINCT CustID  
                FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc --WITH ( NOLOCK ) 
						INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE   [Description] = COALESCE(@LicenseeType,  
                                                     [Description])
-------------------------
DROP TABLE #currency
-----------------------

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

	totalHD MONEY,
	totalHDUSD MONEY,
	totalHDEUR MONEY,

	totalHA MONEY,
	totalHAUSD MONEY,
	totalHAEUR MONEY,

	totalDH MONEY,
	totalDHUSD MONEY,
	totalDHEUR MONEY,
	
	totalDD MONEY,
	totalDDUSD MONEY,
	totalDDEUR MONEY,

	totalDA MONEY,
	totalDAUSD MONEY,
	totalDAEUR MONEY,
	
	totalAH MONEY,
	totalAHUSD MONEY,
	totalAHEUR MONEY,

	totalAD MONEY,
	totalADUSD MONEY,
	totalADEUR MONEY,

	totalAA MONEY,
	totalAAUSD MONEY,
	totalAAEUR MONEY,

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

		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )) AS totalHD,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalHDUSD,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalHDEUR,

		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )) AS totalHA,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalHAUSD,
		SUM((CASE WHEN hdp1 = 1 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalHAEUR,
	
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )) AS totalDH,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalDHUSD,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalDHEUR,

		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )) AS totalDD,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalDDUSD,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalDDEUR,
	
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )) AS totalDA,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalDAUSD,
		SUM((CASE WHEN hdp1 = 0 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalDAEUR,
	
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )) AS totalAH,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalAHUSD,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 1 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalAHEUR,
	
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )) AS totalAD,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalADUSD,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 0 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalADEUR,
	
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )) AS totalAA,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.USD) AS totalAAUSD,
		SUM((CASE WHEN hdp1 = 2 AND hdp2 = 2 THEN (stake*odds)-stake ELSE -stake END )*e.EUR) AS totalAAEUR,
		isnull(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral
		
	FROM  bettrans b with (nolock)
		inner join match m with (nolock) on m.matchid = b.matchid 	
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
		ON e.exchangeid = b.currency
	WHERE    
		b.recommend IN (SELECT CustID FROM @TempAg) AND 
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

GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel16] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel16] TO [vnteam]



