set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  PROCEDURE [dbo].[Lrf_Statement_Mem_BetSummary]
    @CustID INT = NULL ,
    @FromDate DATETIME ,
    @ToDate DATETIME ,
    @Langkey VARCHAR(10) = 'en-US' ,
    @username VARCHAR(50) = NULL , -- for API
    @PageSize INT = 50 ,
    @PageIndex INT = 1 ,
    @TotalRows INT = 0 OUTPUT
AS 
    SET NOCOUNT ON

/*
Created: 20101215@Henry
Task : Statement Bet summary
DB: DB052.bodb02
Original: Age_Statement_Mem_BetSummary

Revisions:
   -- 20110304@Henry: suppport based currency
   -- 20111229@Jim: remove function : Lrf_f_GetChoice
   -- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
    -- 20140130@Winnie: Add base currency GBP 
Param's Explanation:

*/

	DECLARE @Today smalldatetime 
	SET @Today = convert(VARCHAR(10), CURRENT_TIMESTAMP, 120) 

    IF @custid IS NULL 
        SELECT  @custid = custid
        FROM    customer WITH ( NOLOCK )
        WHERE   username = @username


    DECLARE @RowStart INT ,
        @RowEnd INT  
    SELECT  @PageIndex = @PageIndex - 1 ,
            @RowStart = @PageSize * @PageIndex + 1 ,
            @RowEnd = @RowStart + @PageSize - 1

    DECLARE @Data AS TABLE
        (
          Eventdate DATETIME ,
          bettype SMALLINT ,
          matchcode NVARCHAR(50) ,
          homeid INT ,
          awayid INT ,
          status NVARCHAR(20) ,
          totalbet MONEY ,
          totalbetUSD MONEY ,
          totalbetEUR MONEY ,
		  totalbetGBP MONEY ,
          totalstake MONEY ,
          totalstakeUSD MONEY ,
          totalstakeEUR MONEY ,
		  totalstakeGBP MONEY ,
          winning MONEY ,
          winningUSD MONEY ,
          winningEUR MONEY ,
		  winningGBP MONEY ,
          betteam NVARCHAR(30) ,
          isneutral BIT
        )


    INSERT  INTO @Data
            SELECT  match.eventdate ,
                    bettrans.bettype ,
                    match.matchcode ,
                    match.homeid ,
                    match.awayid ,
                    bettrans.status ,
                    SUM(bettrans.stake) AS totalbet ,
                    SUM(bettrans.stake*e.USD) AS totalbetUSD ,
                    SUM(bettrans.stake*e.EUR) AS totalbetEUR ,
					SUM(bettrans.stake*e.GBP) AS totalbetGBP ,
                    SUM(CASE WHEN bettrans.odds < 0
                             THEN bettrans.stake * -bettrans.odds
                             ELSE bettrans.stake
                        END) AS totalstake ,
                    SUM(e.USD * CASE WHEN bettrans.odds < 0
                         THEN bettrans.stake * -bettrans.odds
                         ELSE bettrans.stake
                    END) AS totalstakeUSD ,
                    SUM(e.EUR * CASE WHEN bettrans.odds < 0
                         THEN bettrans.stake * -bettrans.odds
                         ELSE bettrans.stake
                    END) AS totalstakeEUR ,
					SUM(e.GBP * CASE WHEN bettrans.odds < 0
                         THEN bettrans.stake * -bettrans.odds
                         ELSE bettrans.stake
                    END) AS totalstakeGBP ,
                    SUM(bettrans.winlost) AS winning ,
                    SUM(bettrans.winlost*e.USD) AS winningUSD ,
                    SUM(bettrans.winlost*e.EUR) AS winningEUR ,
					SUM(bettrans.winlost*e.GBP) AS winningGBP ,
					bettrans.betteam,
                  --  dbo.Lrf_f_GetChoice(bettrans.betteam, bettrans.bettype,@Language) betteam ,
                    ISNULL(match.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
            FROM    bettrans WITH ( NOLOCK )
                    INNER JOIN match WITH ( NOLOCK ) ON bettrans.matchid = match.matchid
                    INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate))e 
                    ON e.ExchangeDate = (CASE WHEN winlostdate <= @Today THEN winlostdate  ELSE @Today  END) AND e.exchangeid = currency
            WHERE   bettrans.custid = @CustID
                    AND bettrans.transdate >= @FromDate
                    AND bettrans.transdate <= DATEADD(dd, 1, @ToDate)
                    AND bettrans.bettype IN ( 1, 2, 3, 7, 8 )
            GROUP BY bettrans.bettype ,
                    match.matchcode ,
                    match.homeid ,
                    match.awayid ,
                    bettrans.status ,
                    bettrans.betteam ,
                    match.eventdate ,
                    match.isNeutral



    IF @TotalRows = 0 
        BEGIN
            SELECT  @TotalRows = COUNT(bettype)
            FROM    @Data
	
        END


    SELECT  c.*
    FROM    ( SELECT    ROW_NUMBER() OVER ( ORDER BY eventdate ) AS RowNum ,
                        b.*
              FROM      @Data b
            ) c
    WHERE   c.RowNum BETWEEN @RowStart AND @RowEnd



GO


GRANT  EXECUTE  ON [dbo].[Lrf_Statement_Mem_BetSummary]  TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Statement_Mem_BetSummary] TO [VNTeam]
