USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_Rpt_CommByBettype_HR]    
    @FromDate	SMALLDATETIME ,
    @ToDate		SMALLDATETIME ,
    @MoveBetsDay SMALLDATETIME ,
    @PageSize	INT = 1000 ,
    @PageIndex	INT = 1,
	@AgentList	VARCHAR(MAX)
AS         
  
/*  
Created: Henry@20110207  
Task : Commission for Horse Racing  
DB: DB052.bodb02  
Original [Age_Rpt_CommByBettype_HR_Ag]  
Revisions:  
      - 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency
	  - 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	  - 20120614@Jim: optimize code 
	  - 20120727@Jim: add playercomm value 
	  - 20121004@Jim: replace @currencyname input param by @currencyID
	  - 20130618@Jim: Restrict permission of Licensee Users by currency	
	  - 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
	  - 20150123@Jim: support base on Currency GBP
	  - 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]

Param's Explanation: 
		+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT> 
*/  
	SET NOCOUNT ON 

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
  
	CREATE TABLE #Data 
        (
			winlostdate DATETIME,
			custID INT ,
			currency INT,
			tote_win MONEY ,
			tote_place MONEY ,
			tote_winplace MONEY,
			tote_playercomm MONEY
        )  
  
    DECLARE @TempFromDate DATETIME ,
        @TempToDate DATETIME ,
        @Today SMALLDATETIME ,
        @RowStart INT ,
        @RowEnd INT
    SELECT  @PageIndex = @PageIndex - 1 ,
            @RowStart = @PageSize * @PageIndex + 1 ,
            @RowEnd = @RowStart + @PageSize - 1 ,
            @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
  
  
    IF @Todate > @MoveBetsDay 
        BEGIN  
            IF @FromDate <= @MoveBetsDay 
                SET @TempFromDate = DATEADD(day, 1, @MoveBetsDay)  
            ELSE 
                SET @TempFromDate = @FromDate  
  
            INSERT  INTO #Data
                    ( 
					  winlostdate,
					  custID ,
					  currency,
                      tote_win ,
                      tote_place ,
                      tote_winplace,
					  tote_playercomm
					)
                    SELECT  
							b.winlostdate,
							b.custid ,
							b.currency,
                            SUM(CASE b.bettype
                                  WHEN 31 THEN ISNULL(b.comm, 0)
                                  ELSE 0
                                END) tote_win ,
                            
                            SUM(CASE b.bettype
                                  WHEN 32 THEN ISNULL(b.comm, 0)
                                  ELSE 0
                                END) tote_place ,
                            
                            SUM(CASE b.bettype
                                  WHEN 33 THEN ISNULL(b.comm, 0)
                                  ELSE 0
                                END) tote_winplace,-- 
							SUM( ISNULL(b.playercomm,0)) tote_playercomm
                            
                    FROM    bettrans b WITH ( NOLOCK )
							INNER JOIN @TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
                    WHERE  
							  b.winlostdate BETWEEN @TempFromDate AND @Todate
                            AND b.bettype IN ( 31, 32, 33 )
                            AND b.matchid > 0
                            AND b.ruben = 1
					GROUP BY b.winlostdate,b.custid,b.currency
                    
        END  
  
    IF @FromDate <= @MoveBetsDay 
        BEGIN  
            IF @ToDate >= @MoveBetsDay 
                SET @TempToDate = @MoveBetsDay  
            ELSE 
                SET @TempToDate = @ToDate  
  
              
            INSERT  INTO #Data
					( 
					winlostdate,
					custID ,
					currency,
					tote_win ,
					tote_place ,
					tote_winplace,--
					tote_PlayerComm 
					)
                    SELECT  
							b.winlostdate,
							b.custid ,
							b.currency,
                            SUM(CASE b.bettype
                                  WHEN 31 THEN ISNULL(b.comm, 0)
                                  ELSE 0
                                END) tote_win ,
                           
                            SUM(CASE b.bettype
                                  WHEN 32 THEN ISNULL(b.comm, 0)
                                  ELSE 0
                                END) tote_place ,
                            SUM(CASE b.bettype
                                  WHEN 33 THEN ISNULL(b.comm, 0)
                                  ELSE 0
                                END) tote_winplace,--
							SUM(  ISNULL(b.playercomm, 0)) tote_PlayerComm
                    FROM    bettrans14 b WITH ( NOLOCK )
							INNER JOIN @TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
                    WHERE   
						    b.winlostdate BETWEEN @FromDate AND @TempToDate
                            AND b.bettype IN ( 31, 32, 33 )
                            AND b.ruben = 1
					GROUP BY b.winlostdate,b.custid,b.currency
                    
                            
                    
        END  
	CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #Data (Currency)
	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

    SELECT  c.custid ,
            c.username ,
            c.nickname ,
            c.tote_win ,
            c.tote_winUSD ,
            c.tote_winEUR ,
			c.tote_winGBP ,
            c.tote_place ,
            c.tote_placeUSD ,
            c.tote_placeEUR ,
			c.tote_placeGBP ,
            c.tote_winplace ,
            c.tote_winplaceUSD ,
            c.tote_winplaceEUR ,--
			c.tote_winplaceGBP ,--
			c.tote_playercomm ,--
            ( c.tote_win + c.tote_place + c.tote_winplace ) AS tote_total ,
            ( c.tote_winUSD + c.tote_placeUSD + c.tote_winplaceUSD ) AS tote_totalUSD ,
            ( c.tote_winEUR + c.tote_placeEUR + c.tote_winplaceEUR ) AS tote_totalEUR,--
			( c.tote_winGBP + c.tote_placeGBP + c.tote_winplaceGBP ) AS tote_totalGBP,--
			( c.tote_playercomm ) AS tote_total_playercomm ,
            ( c.tote_playercommUSD ) AS tote_total_playercommUSD ,
            ( c.tote_playercommEUR ) AS tote_total_playercommEUR ,
			( c.tote_playercommGBP ) AS tote_total_playercommGBP 
    FROM    ( 
			  SELECT    ROW_NUMBER() OVER ( ORDER BY b.custid, username) AS RowNum ,
						b.custID ,
						c.Username ,
						SUBSTRING(c.username2,
                                      CHARINDEX('$', c.username2) + 1,
                                      LEN(c.username2) - CHARINDEX('$',
                                                              c.username2)) AS nickname ,
						SUM(tote_win) tote_win,
						SUM(tote_win * e.USD) tote_winUSD,
						SUM(tote_win * e.EUR) tote_winEUR,
						SUM(tote_win * e.GBP) tote_winGBP,
						SUM(tote_place) tote_place,
						SUM(tote_place * e.USD) tote_placeUSD,
						SUM(tote_place * e.EUR) tote_placeEUR,
						SUM(tote_place * e.GBP) tote_placeGBP,
						SUM(tote_winplace) tote_winplace,
						SUM(tote_winplace * e.USD) tote_winplaceUSD,
						SUM(tote_winplace * e.EUR) tote_winplaceEUR,
						SUM(tote_winplace * e.GBP) tote_winplaceGBP,
						--
						SUM(tote_playercomm) tote_playercomm,
						SUM(tote_playercomm * e.USD) tote_playercommUSD,
						SUM(tote_playercomm * e.EUR) tote_playercommEUR,
						SUM(tote_playercomm * e.GBP) tote_playercommGBP
						
              FROM      #Data b 
						INNER JOIN Customer c (nolock) ON b.custid = c.custid
						INNER JOIN  #TempExchange e
						ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
              
              group by b.custid, Username, username2
            ) c
    WHERE   c.RowNum BETWEEN @RowStart AND @RowEnd 
    
    
    SELECT  COUNT( distinct custID) AS TotalRows ,
            SUM(ISNULL(tote_win, 0)) AS Sumtote_win ,
            SUM(ISNULL(tote_win * e.USD, 0)) AS Sumtote_winUSD ,
            SUM(ISNULL(tote_win * e.EUR, 0)) AS Sumtote_winEUR ,
			SUM(ISNULL(tote_win * e.GBP, 0)) AS Sumtote_winGBP ,
            SUM(ISNULL(tote_place, 0)) AS Sumtote_place ,
            SUM(ISNULL(tote_place * e.USD, 0)) AS Sumtote_placeUSD ,
            SUM(ISNULL(tote_place * e.EUR, 0)) AS Sumtote_placeEUR ,
			SUM(ISNULL(tote_place * e.GBP, 0)) AS Sumtote_placeGBP ,
            SUM(ISNULL(tote_winplace, 0)) AS Sumtote_winplace ,
            SUM(ISNULL(tote_winplace * e.USD, 0)) AS Sumtote_winplaceUSD ,
            SUM(ISNULL(tote_winplace * e.EUR, 0)) AS Sumtote_winplaceEUR ,
			SUM(ISNULL(tote_winplace * e.GBP, 0)) AS Sumtote_winplaceGBP ,
            SUM(ISNULL(tote_win, 0) + ISNULL(tote_place, 0)
                + ISNULL(tote_winplace, 0)) AS sumtote_total ,
            SUM(ISNULL(tote_win * e.USD, 0) + ISNULL(tote_place * e.USD, 0)
                + ISNULL(tote_winplace * e.USD, 0)) AS sumtote_totalUSD ,
            SUM(ISNULL(tote_win * e.EUR, 0) + ISNULL(tote_place * e.EUR, 0)
                + ISNULL(tote_winplace * e.EUR, 0)) AS sumtote_totalEUR,--
			SUM(ISNULL(tote_win * e.GBP, 0) + ISNULL(tote_place * e.GBP, 0)
			+ ISNULL(tote_winplace * e.GBP, 0)) AS sumtote_totalGBP,--
			SUM(ISNULL(tote_playercomm, 0)) AS sumtote_total_playercomm ,
			SUM(ISNULL(tote_playercomm * e.USD, 0)) AS sumtote_total_playercommUSD,
            SUM(ISNULL(tote_playercomm * e.EUR, 0)) AS sumtote_total_playercommEUR,
			SUM(ISNULL(tote_playercomm * e.GBP, 0)) AS sumtote_total_playercommGBP
	FROM    #Data b  
			INNER JOIN  #TempExchange e
			ON e.ExchangeDate = b.winlostdate  AND e.exchangeid = b.currency
	DROP TABLE #Data 
	DROP TABLE #TempExchange 
GO
GRANT EXECUTE ON [dbo].[Lrf_Rpt_CommByBettype_HR] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Rpt_CommByBettype_HR] TO [vnteam]
GO