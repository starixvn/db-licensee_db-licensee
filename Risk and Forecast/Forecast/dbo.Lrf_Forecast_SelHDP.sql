ALTER  PROCEDURE [dbo].[Lrf_Forecast_SelHDP]
    @LicenseeID INT ,
    @LicenseeType VARCHAR(100) = NULL ,
    @CurrencyID INT=0,
	@UserID		INT,
    @matchid INT ,
    @bettype INT = 1
AS /*
Created: 20101207@Henry
Original: Age_Forecast_SelHDP
Task: Forecast for HDP bettype.
DB: DB052.bodb02
Revisions:

	- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency	
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency 
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function 
	- 20150123@Jim: support base on Currency GBP
*/
    SET NOCOUNT ON

    DECLARE @Today SMALLDATETIME 
    SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120) 
	
	SELECT  currencyID,LicenseeID into #currency
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
	WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))
	
	DECLARE @TempAg AS TABLE ( CustId INT )
    INSERT  INTO @TempAg ( CustId)
	SELECT  DISTINCT CustID  
	FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc --WITH ( NOLOCK )  
			INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
	WHERE   [Description] = COALESCE(@LicenseeType,  
										 [Description])
	------------------
	DROP TABLE #currency
	--------------------
    SELECT  -x.hdp + score offset ,
            SUM(x.hometotal * 1) 'ht' ,
            SUM(x.hometotalUSD * 1) 'htUSD' ,
            SUM(x.hometotalEUR * 1) 'htEUR' ,
			SUM(x.hometotalGBP * 1) 'htGBP' ,
            SUM(x.awaytotal * 1) 'at' ,
            SUM(x.awaytotalUSD * 1) 'atUSD' ,
            SUM(x.awaytotalEUR * 1) 'atEUR' ,
			SUM(x.awaytotalGBP * 1) 'atGBP' ,
            SUM(( x.homewin - x.awaylose ) * 1) 'al' ,
            SUM(( x.homewinUSD - x.awayloseUSD ) * 1) 'alUSD' ,
            SUM(( x.homewinEUR - x.awayloseEUR ) * 1) 'alEUR' ,
			SUM(( x.homewinEUR - x.awayloseGBP ) * 1) 'alGBP' ,
            SUM(( x.awaywin - x.homelose ) * 1) 'hl' ,
            SUM(( x.awaywinUSD - x.homeloseUSD ) * 1) 'hlUSD' ,
            SUM(( x.awaywinEUR - x.homeloseEUR ) * 1) 'hlEUR',
			SUM(( x.awaywinEUR - x.homeloseGBP ) * 1) 'hlGBP'
    FROM    ( SELECT    b.currency ,
                        hdp2 - hdp1 hdp ,
                        livehomescore - liveawayscore score ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN stake 
                                 ELSE 0
                            END) hometotal ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN stake  * e.USD
                                 ELSE 0
                            END) hometotalUSD ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN stake  * e.EUR
                                 ELSE 0
                            END) hometotalEUR ,
						SUM(CASE WHEN betteam = 'h'
                                 THEN stake  * e.GBP
                                 ELSE 0
                            END) hometotalGBP ,
							
                        SUM(CASE WHEN betteam = 'a'
                                 THEN stake 
                                 ELSE 0
                            END) awaytotal ,
                        SUM(CASE WHEN betteam = 'a'
                                 THEN stake  * e.USD
                                 ELSE 0
                            END) awaytotalUSD ,
                        SUM(CASE WHEN betteam = 'a'
                                 THEN stake  * e.EUR
                                 ELSE 0
                            END) awaytotalEUR ,
						SUM(CASE WHEN betteam = 'a'
                                 THEN stake  * e.GBP
                                 ELSE 0
                            END) awaytotalGBP ,
							
                        SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                 ELSE 0
                            END) homewin ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) homewinUSD ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) homewinEUR ,
						SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) homewinGBP ,
							
                        SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                 ELSE 0
                            END) awaywin ,
                        SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) awaywinUSD ,
                        SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) awaywinEUR ,
						SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) awaywinGBP ,
						SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                 ELSE 0
                            END) homelose ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) homeloseUSD ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) homeloseEUR ,
						SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) homeloseGBP ,
								
                        SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                 ELSE 0
                            END) awaylose ,
                        SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                      * e.USD
                                 ELSE 0
                            END) awayloseUSD ,
                        SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                      * e.EUR
                                 ELSE 0
                            END) awayloseEUR,
						SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) awayloseGBP
							
              FROM      bettrans b WITH ( NOLOCK )
                        INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
									ON e.exchangeid = b.currency
              WHERE    
						 b.recommend IN ( SELECT custid FROM   @TempAg )
						AND bettype = @bettype
                        AND matchid = @matchid
                        AND b.statusID IN ( 0, 1 )
                        AND b.ruben = 0
                        AND b.tpositiontaking <> 0
              GROUP BY  b.currency ,
                        hdp2 - hdp1 ,
                        livehomescore - liveawayscore
            ) x
    GROUP BY -x.hdp + score


GO

GRANT EXECUTE ON [dbo].[Lrf_Forecast_SelHDP] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Forecast_SelHDP] TO [vnteam]
GO
