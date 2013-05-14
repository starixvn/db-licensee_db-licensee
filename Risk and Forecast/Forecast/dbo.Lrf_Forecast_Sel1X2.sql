ALTER PROCEDURE [Lrf_Forecast_Sel1X2]
    @LicenseeID INT ,
    @LicenseeType VARCHAR(100) = NULL ,
    @CurrencyID INT=0,
    @matchid INT ,
    @bettype INT
AS /*
Created by: [20101207@Henry]
Task: Forecast for 1x2 bettype
DB: DB052.bodb02
Original: [Age_Forecast_Sel1X2]
Revisions:
	
	
	- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID
Param's explanation:
	--1:home
	--2:away
	--x:draw
*/
    SET NOCOUNT ON
    DECLARE @BetType1x2 SMALLINT ,
        @BetTypeHT1x2 SMALLINT
    SELECT  @BetType1x2 = 5 ,
            @BetTypeHT1x2 = 15

    DECLARE @Today SMALLDATETIME 
    SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
		
	DECLARE @TempAg AS TABLE ( CustId INT )
    INSERT  INTO @TempAg ( CustId)
            SELECT  CustID  
			FROM    bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )  
			WHERE   LicenseeID = @LicenseeID  
					AND  (@CurrencyID=0 OR (@CurrencyID <> 0 AND  Currency = @CurrencyID))
					AND [Description] = COALESCE(@LicenseeType,  
												 [Description])

	
    SELECT  x.MatchID ,
            x.homeid ,
            x.awayid ,
            x.liveindicator ,
            ISNULL(x.LiveHomeScore, 0) AS livehomescore ,
            ISNULL(x.LiveAwayScore, 0) AS liveawayscore ,
            x.ShowTime ,
            x.MatchCode ,
            isNeutral ,
            ( x.awaywin - x.homelose - x.drawlose ) 'al' ,
            ( x.awaywinUSD - x.homeloseUSD - x.drawloseUSD ) 'alUSD' ,
            ( x.awaywinEUR - x.homeloseEUR - x.drawloseEUR ) 'alEUR' ,
            ( x.homewin - x.awaylose - x.drawlose ) 'hl' ,
            ( x.homewinUSD - x.awayloseUSD - x.drawloseUSD ) 'hlUSD' ,
            ( x.homewinEUR - x.awayloseEUR - x.drawloseEUR ) 'hlEUR' ,
            ( x.drawwin - x.awaylose - x.homelose ) 'dl' ,
            ( x.drawwinUSD - x.awayloseUSD - x.homeloseUSD ) 'dlUSD' ,
            ( x.drawwinEUR - x.awayloseEUR - x.homeloseEUR ) 'dlEUR' ,
            ( x.ht_awaywin - x.ht_drawlose - x.ht_homelose ) 'ht_al' ,
            ( x.ht_awaywinUSD - x.ht_drawloseUSD - x.ht_homeloseUSD ) 'ht_alUSD' ,
            ( x.ht_awaywinEUR - x.ht_drawloseEUR - x.ht_homeloseEUR ) 'ht_alEUR' ,
            ( x.ht_homewin - x.ht_drawlose - x.ht_awaylose ) 'ht_hl' ,
            ( x.ht_homewinUSD - x.ht_drawloseUSD - x.ht_awayloseUSD ) 'ht_hlUSD' ,
            ( x.ht_homewinEUR - x.ht_drawloseEUR - x.ht_awayloseEUR ) 'ht_hlEUR' ,
            ( x.ht_drawwin - x.ht_awaylose - x.ht_homelose ) 'ht_dl' ,
            ( x.ht_drawwinUSD - x.ht_awayloseUSD - x.ht_homeloseUSD ) 'ht_dlUSD' ,
            ( x.ht_drawwinEUR - x.ht_awayloseEUR - x.ht_homeloseEUR ) 'ht_dlEUR'
    FROM    ( SELECT    m.MatchID ,
                        m.homeid ,
                        m.awayid ,
                        b.liveindicator ,
                        ISNULL(b.LiveHomeScore, 0) AS livehomescore ,
                        ISNULL(b.LiveAwayScore, 0) AS liveawayscore ,
                        M.ShowTime ,
                        M.MatchCode ,
                        ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                 ELSE 0
                            END) homewin ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) homewinUSD ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) homewinEUR ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                 ELSE 0
                            END) awaywin ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) awaywinUSD ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) awaywinEUR ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                 ELSE 0
                            END) drawwin ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) drawwinUSD ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) drawwinEUR ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                 ELSE 0
                            END) homelose ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) homeloseUSD ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) homeloseEUR ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                 ELSE 0
                            END) awaylose ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) awayloseUSD ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) awayloseEUR ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                 ELSE 0
                            END) drawlose ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) drawloseUSD ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) drawloseEUR ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                 ELSE 0
                            END) ht_homewin ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) ht_homewinUSD ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) ht_homewinEUR ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                 ELSE 0
                            END) ht_awaywin ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) ht_awaywinUSD ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) ht_awaywinEUR ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                 ELSE 0
                            END) ht_drawwin ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) ht_drawwinUSD ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) ht_drawwinEUR ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                 ELSE 0
                            END) ht_homelose ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) ht_homeloseUSD ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) ht_homeloseEUR ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                 ELSE 0
                            END) ht_awaylose ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) ht_awayloseUSD ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) ht_awayloseEUR ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                 ELSE 0
                            END) ht_drawlose ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) ht_drawloseUSD ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) ht_drawloseEUR
              FROM      bettrans b WITH ( NOLOCK )
                        INNER JOIN Match M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                              AND M.EventStatus = 'running'
                        INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
						ON e.exchangeid = b.currency
              WHERE     
						b.recommend in (SELECT custid from @TempAg)
						AND b.bettype = @bettype
                        AND b.matchid = @MatchID
                        AND b.statusID IN ( 0, 1 )
                        AND b.ruben = 0
                        AND b.tpositiontaking <> 0
                        
              GROUP BY  liveindicator ,
                        m.MatchID ,
                        m.homeid ,
                        m.awayid ,
                        b.liveindicator ,
                        b.LiveHomeScore ,
                        b.LiveAwayScore ,
                        M.ShowTime ,
                        M.MatchCode ,
                        isNeutral
            ) x 
GO
GRANT EXECUTE ON [Lrf_Forecast_Sel1X2] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Forecast_Sel1X2] TO [vnteam]
GO




