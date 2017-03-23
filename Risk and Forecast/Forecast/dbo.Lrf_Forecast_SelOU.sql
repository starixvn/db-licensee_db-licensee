USE bodb02
GO

ALTER  PROCEDURE [dbo].[Lrf_Forecast_SelOU]    
    @matchid	INT ,
    @bettype	INT = 3,
	@AgentList	VARCHAR(MAX)
AS 

/*
Original: SP [Age_Forecast_SelOU]
Task: Forcast for OU bettypes.
DB: DB052.bodb02
Revisions: 
	- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency	
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
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

    SELECT  x.liveindicator ,
            x.status ,
            x.score + x.hdp offset ,
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
			SUM(( x.homewinGBP - x.awayloseGBP ) * 1) 'alGBP' ,
            SUM(( x.awaywin - x.homelose ) * 1) 'hl' ,
            SUM(( x.awaywinUSD - x.homeloseUSD ) * 1) 'hlUSD' ,
            SUM(( x.awaywinEUR - x.homeloseEUR ) * 1) 'hlEUR',
			SUM(( x.awaywinGBP - x.homeloseGBP ) * 1) 'hlGBP'
    FROM    ( SELECT    liveindicator ,
                        status ,
                        b.currency ,
                        hdp1 hdp ,
                        0 score ,
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
                            END) awaywinGBP,
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
						b.recommend IN ( SELECT custid
                                             FROM   @TempAg )
						AND bettype = @bettype
                        AND matchid = @matchid
                        AND b.statusID IN ( 0, 1 )
                        AND b.ruben = 0
                        AND b.tpositiontaking <> 0
              GROUP BY  liveindicator ,
                        status ,
                        b.currency ,
                        hdp1 ,
                        livehomescore + liveawayscore
            ) x
    GROUP BY x.status ,
            liveindicator ,
            x.score + x.hdp


GO

GRANT EXECUTE ON [dbo].[Lrf_Forecast_SelOU] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Forecast_SelOU] TO [vnteam]
GO
