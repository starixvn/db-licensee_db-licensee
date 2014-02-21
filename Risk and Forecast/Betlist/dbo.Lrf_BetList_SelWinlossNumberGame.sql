USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelWinlossNumberGame]    Script Date: 02/20/2014 23:31:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  Stored Procedure dbo.Lrf_BetList_SelWinlossNumberGame    Script Date: 4/8/2013 10:42:34 PM ******/

/****** Object:  Stored Procedure dbo.Lrf_BetList_SelWinlossNumberGame    Script Date: 12/26/2012 10:52:12 PM ******/
/****** Object:  Stored Procedure dbo.Lrf_BetList_SelWinlossNumberGame    Script Date: 11/28/2012 12:45:12 PM ******/



ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlossNumberGame]     
     @LicenseeID INT ,
     @LicenseeType VARCHAR(100) = NULL ,
     @CurrencyID INT=0 ,     
     @FromDate SMALLDATETIME,  
     @ToDate SMALLDATETIME,  
     @MoveBetsDay SMALLDATETIME ,
     @PageSize INT=1000,
     @PageIndex INT=1     
AS  

/*
Created: Jacob@20111110
Task : Betlist Number Game
DB: DB052.bodb02
Original: [Lrf_BetList_SelWinlossHR]
Revisions:        
    Get all Number Game ticket in a duration FromDate => ToDate
    -20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily  
    -20120614@Jim: optimize code 
    -20120711@Jim: get value betteam
    -20120724@Jim: add playercomm value
    -20120813@Jim: get bettrans.liveindicator value and add more oddstype column in the result     
    -20121004@Jim: replace @currencyname input param by @currencyID
*/


SET NOCOUNT ON  

DECLARE @TempAg AS TABLE (custid INT)
DECLARE @TempFromDate DATETIME 
DECLARE @TempToDate DATETIME
DECLARE @TempCount INT
DECLARE @RowStart INT, @RowEnd INT  


SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1

CREATE TABLE #Data (  
     sporttype TINYINT,  
     Custid INT,
     username nvarchar(50),       
     bettype SMALLINT,         
     transid BIGINT,  
     BetID BIGINT,
     race VARCHAR(50),  
     matchcode VARCHAR(50),  
     homeID INT,  
     awayID INT,  
     hdp1 SMALLMONEY,  
     hdp2 SMALLMONEY,  
     Modds SMALLMONEY,
     odds SMALLMONEY,  
     status nvarchar(50),  
     stake MONEY,  
     winlost MONEY,  
     licenseeWL MONEY,
     comm MONEY,
     playercomm MONEY,
     discount MONEY,
     transdate DATETIME,  
     betteam nvarchar(25),  
     apositiontaking SMALLMONEY,  
     liveindicator BIT,  
     livehomescore SMALLINT,  
     liveawayscore SMALLINT,  
     leagueID INT,  
     matchid INT,   
     IP VARCHAR(30),  
     betstatus VARCHAR(50),  
     isNeutral BIT ,
     winlostdate DATETIME,
     currency SMALLINT,
     oddstype tinyint
)  

INSERT INTO @TempAg (custid)
SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )  
                WHERE   LicenseeID = @LicenseeID  
                        AND  (@CurrencyID=0 OR (@CurrencyID <> 0 AND  Currency = @CurrencyID))
                        AND [Description] = COALESCE(@LicenseeType,  
                                                     [Description])

IF @Fromdate <= @MoveBetsDay 
BEGIN  

    IF @ToDate >= @MoveBetsDay
        SET @TempToDate = @MoveBetsDay
    ELSE
        SET  @TempToDate = @ToDate
        
     INSERT INTO #Data 
     SELECT TOP (@RowEnd)
      161,  
      b.custid,
      b.username,        
      b.bettype,            
      b.transid,  
      ISNULL(b.BetID,0),
      '' AS race,  
      m.matchcode,  
      0,  
      0,  
      b.hdp1,  
      b.hdp2,  
      modds,
      b.odds,  
      b.status,  
      b.stake,  
      (b.winlost-actual_stake),  
      (-1 * (b.winlost - b.actual_stake))  AS LicenseeWL,    
      comm,
      playercomm, 
      b.adiscount,
      b.transdate,  
      b.betteam,  
      b.apositiontaking,
      b.liveindicator,
      b.livehomescore,
      b.liveawayscore,    
      m.leagueID,  
      b.matchid,   
      b.IP AS IP,
      NULL,  
      CONVERT(BIT,0) AS IsNeutral,
      b.winlostdate,
      b.currency,
      b.oddstype
     FROM  
        bettrans14 b WITH (NOLOCK,INDEX(bettrans143))  
        INNER JOIN @TempAg t  ON b.recommend =t.custid 
        INNER JOIN match14 m WITH (NOLOCK) ON b.matchid=m.matchid         
     WHERE            
      b.bettype BETWEEN 81 AND 120 AND
      b.Winlostdate BETWEEN @FromDate AND @TempToDate AND
      b.statusID NOT IN (101, 102, 103)
     ORDER  BY b.transid
     
END  

SELECT @TempCount = COUNT(1) FROM #Data

IF @Todate > @MoveBetsDay  AND @TempCount < @RowEnd
BEGIN  

    IF @FromDate <= @MoveBetsDay 
        SET @TempFromDate =  DATEADD(DAY,1,@MoveBetsDay)
    ELSE
        SET @TempFromDate = @FromDate
        
     INSERT INTO #Data 
     SELECT TOP (@RowEnd) 
      161,  
      b.custid,
      b.username,        
      b.bettype,           
      b.transid, 
      ISNULL(b.BetID,0), 
      '' AS race,  
      m.matchcode,  
      0,  
      0,  
      b.hdp1,  
      b.hdp2,  
      modds,
      b.odds,  
      b.status,  
      b.stake,  
      (b.winlost-actual_stake),  
      (-1 * (b.winlost - b.actual_stake)) AS LicenseeWL,    
      comm,
      playercomm, 
      b.adiscount,
      b.transdate,  
      b.betteam, 
      b.apositiontaking,
      b.liveindicator,
      b.livehomescore,
      b.liveawayscore,  
      m.leagueID,  
      b.matchid,   
      b.IP AS IP,
        NULL,  
      CONVERT(BIT,0) AS IsNeutral,
      b.winlostdate,
      b.currency,
      b.oddstype
     FROM  
      bettrans b WITH (NOLOCK) 
      INNER JOIN @TempAg t  ON b.recommend =t.custid  
      INNER JOIN [match] m WITH (NOLOCK) ON b.matchid=m.matchid         
     WHERE              
      b.bettype BETWEEN 81 AND 120 AND
      b.Winlostdate BETWEEN @TempFromDate AND @ToDate AND        
      b.Ruben=1  AND
      b.statusID NOT IN (101, 102, 103)      
     ORDER  BY b.transid
END  
  
CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #Data (Currency)
SELECT * INTO #TempExchange
FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data) 
  
SELECT A.* 
FROM
(
    SELECT  
            ROW_NUMBER() over(ORDER BY transid) AS RowNum,
            b.* ,
            SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,           
            --USD
            stake*e.USD stakeUSD,
            winlost*e.USD winlostUSD,
            LicenseeWL*e.USD LicenseeWLUSD,
            comm*e.USD commUSD,
            playercomm*e.USD playercommUSD,
            --EUR
            stake*e.EUR stakeEUR,
            winlost*e.EUR winlostEUR,
            LicenseeWL*e.EUR LicenseeWLEUR,
            comm*e.EUR commEUR,
            playercomm*e.EUR playercommEUR
            
    FROM #Data b
    INNER JOIN Customer c (NOLOCK) ON b.custid = c.custid
    INNER JOIN  #TempExchange e
    ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

DROP TABLE #Data    
DROP TABLE #TempExchange
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlossNumberGame] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlossNumberGame] TO [vnteam]
