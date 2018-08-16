USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Lrf_Forecast1x2_SelByLeague]    Script Date: 04/29/2015 14:15:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_Forecast1x2_SelByLeague]    
    @leagueid	INT,
	@AgentList	VARCHAR(MAX)
AS /*
Created: 20101207@Henry
Task: Forecast for 1x2 bettype according to league.
DB: DB042.bodb02
Original: Age_Forecast1x2_SelByLeague_Ag
Revisions: 
	- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency	
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function 
	- 20150123@Jim: support base on Currency GBP
	- 20150414@Jim: add more bettype Extra Time 1H 1X2 (feature #32844)
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20180802@Sophia: HA - remove ruben to use new index on DB042 [Redmine: #98631]

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
	
	
    DECLARE @BetType1x2 SMALLINT ,
			@BetTypeHT1x2 SMALLINT,
			@BetTypeExHT1x2 SMALLINT
    SELECT  @BetType1x2 = 5 ,
            @BetTypeHT1x2 = 15,
			@BetTypeExHT1x2 = 167
	
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

    SELECT  x.MatchID ,
            x.homeid ,
            x.awayid ,
            x.liveindicator ,
            ISNULL(x.LiveHomeScore, 0) AS livehomescore ,
            ISNULL(x.LiveAwayScore, 0) AS liveawayscore ,
            x.ShowTime ,
            x.MatchCode ,
            isNeutral ,
			--FT.1X2
            SUM( x.awaywin - x.homelose - x.drawlose ) 'al' ,
            SUM( x.awaywinUSD - x.homeloseUSD - x.drawloseUSD ) 'alUSD' ,
            SUM( x.awaywinEUR - x.homeloseEUR - x.drawloseEUR ) 'alEUR' ,
			SUM( x.awaywinGBP - x.homeloseGBP - x.drawloseGBP ) 'alGBP' ,
            SUM( x.homewin - x.awaylose - x.drawlose ) 'hl' ,
            SUM( x.homewinUSD - x.awayloseUSD - x.drawloseUSD ) 'hlUSD' ,
            SUM( x.homewinEUR - x.awayloseEUR - x.drawloseEUR ) 'hlEUR' ,
			SUM( x.homewinGBP - x.awayloseGBP - x.drawloseGBP ) 'hlGBP' ,
            SUM( x.drawwin - x.awaylose - x.homelose ) 'dl' ,
            SUM( x.drawwinUSD - x.awayloseUSD - x.homeloseUSD ) 'dlUSD' ,
            SUM( x.drawwinEUR - x.awayloseEUR - x.homeloseEUR ) 'dlEUR' ,
			SUM( x.drawwinGBP - x.awayloseGBP - x.homeloseGBP ) 'dlGBP' ,
			--1H 1X2
            SUM( x.ht_awaywin - x.ht_drawlose - x.ht_homelose ) 'ht_al' ,
            SUM( x.ht_awaywinUSD - x.ht_drawloseUSD - x.ht_homeloseUSD ) 'ht_alUSD' ,
            SUM( x.ht_awaywinEUR - x.ht_drawloseEUR - x.ht_homeloseEUR ) 'ht_alEUR' ,
			SUM( x.ht_awaywinGBP - x.ht_drawloseGBP - x.ht_homeloseGBP ) 'ht_alGBP' ,
            SUM( x.ht_homewin - x.ht_drawlose - x.ht_awaylose ) 'ht_hl' ,
            SUM( x.ht_homewinUSD - x.ht_drawloseUSD - x.ht_awayloseUSD ) 'ht_hlUSD' ,
            SUM( x.ht_homewinEUR - x.ht_drawloseEUR - x.ht_awayloseEUR ) 'ht_hlEUR' ,
			SUM( x.ht_homewinGBP - x.ht_drawloseGBP - x.ht_awayloseGBP ) 'ht_hlGBP' ,
            SUM( x.ht_drawwin - x.ht_awaylose - x.ht_homelose ) 'ht_dl' ,
            SUM( x.ht_drawwinUSD - x.ht_awayloseUSD - x.ht_homeloseUSD ) 'ht_dlUSD' ,
            SUM( x.ht_drawwinEUR - x.ht_awayloseEUR - x.ht_homeloseEUR ) 'ht_dlEUR' ,
			SUM( x.ht_drawwinGBP - x.ht_awayloseGBP - x.ht_homeloseGBP ) 'ht_dlGBP' ,
			---Extra Time 1H 1X2
			SUM( x.x_awaywin - x.x_drawlose - x.x_homelose ) 'x_al' ,
			SUM( x.x_awaywinUSD - x.x_drawloseUSD - x.x_homeloseUSD ) 'x_alUSD' ,
            SUM( x.x_awaywinEUR - x.x_drawloseEUR - x.x_homeloseEUR ) 'x_alEUR' ,
			SUM( x.x_awaywinGBP - x.x_drawloseGBP - x.x_homeloseGBP ) 'x_alGBP' ,
            SUM( x.x_homewin	 - x.x_drawlose	   - x.x_awaylose )	   'x_hl' ,
            SUM( x.x_homewinUSD - x.x_drawloseUSD - x.x_awayloseUSD ) 'x_hlUSD' ,
            SUM( x.x_homewinEUR - x.x_drawloseEUR - x.x_awayloseEUR ) 'x_hlEUR' ,
			SUM( x.x_homewinGBP - x.x_drawloseGBP - x.x_awayloseGBP ) 'x_hlGBP' ,
            SUM( x.x_drawwin    - x.x_awaylose	   - x.x_homelose )	   'x_dl' ,
            SUM( x.x_drawwinUSD - x.x_awayloseUSD - x.x_homeloseUSD ) 'x_dlUSD' ,
            SUM( x.x_drawwinEUR - x.x_awayloseEUR - x.x_homeloseEUR ) 'x_dlEUR' ,
			SUM( x.x_drawwinGBP - x.x_awayloseGBP - x.x_homeloseGBP ) 'x_dlGBP',
			CASE WHEN x.bettype =167 THEN 1 ELSE 0 END  isExtra
			
    FROM    ( SELECT    m.MatchID ,
                        m.homeid ,
                        m.awayid ,
                        b.liveindicator ,
                        ISNULL(b.LiveHomeScore, 0) AS livehomescore ,
                        ISNULL(b.LiveAwayScore, 0) AS liveawayscore ,
                        M.ShowTime ,
                        M.MatchCode ,
                        ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral ,
						---FT.1X2
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
						 SUM(CASE WHEN betteam = '1'
								  AND bettype = @BetType1x2
							 THEN ( CASE WHEN odds < 0 THEN 1
										 ELSE odds - 1
									END ) * stake 
								  * e.GBP
							 ELSE 0
						END) homewinGBP ,
							
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
						SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) awaywinGBP ,
							
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
						SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) drawwinGBP ,	
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
						SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) homeloseGBP,	
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
                                        END ) * stake * e.USD
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
						SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) awayloseGBP ,
							
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
						SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) drawloseGBP ,
					--- 1H 1X2
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
						SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) ht_homewinGBP ,
							
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
						SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) ht_awaywinGBP ,
							
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
						SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) ht_drawwinGBP ,
							
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
						SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) ht_homeloseGBP ,
							
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
						SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) ht_awayloseGBP ,
							
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
                            END) ht_drawloseEUR,
							SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.GBP
                                 ELSE 0
                            END) ht_drawloseGBP,
					---	Extra Time 1H 1X2
						SUM(CASE WHEN betteam = '1'
								  AND bettype = @BetTypeExHT1x2
							 THEN ( CASE WHEN odds < 0 THEN 1
										 ELSE odds - 1
									END ) * stake 
							 ELSE 0
						END) x_homewin ,
						SUM(CASE WHEN betteam = '1'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
									  * e.USD
								 ELSE 0
							END) x_homewinUSD ,
						SUM(CASE WHEN betteam = '1'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
									  * e.EUR
								 ELSE 0
							END) x_homewinEUR ,
						 SUM(CASE WHEN betteam = '1'
								  AND bettype = @BetTypeExHT1x2
							 THEN ( CASE WHEN odds < 0 THEN 1
										 ELSE odds - 1
									END ) * stake 
								  * e.GBP
							 ELSE 0
						END) x_homewinGBP ,
							
						SUM(CASE WHEN betteam = '2'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
								 ELSE 0
							END) x_awaywin ,
						SUM(CASE WHEN betteam = '2'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
									  * e.USD
								 ELSE 0
							END) x_awaywinUSD ,
						SUM(CASE WHEN betteam = '2'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
									  * e.EUR
								 ELSE 0
							END) x_awaywinEUR ,
						SUM(CASE WHEN betteam = '2'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
									  * e.GBP
								 ELSE 0
							END) x_awaywinGBP ,
							
						SUM(CASE WHEN betteam = 'x'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
								 ELSE 0
							END) x_drawwin ,
						SUM(CASE WHEN betteam = 'x'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
									  * e.USD
								 ELSE 0
							END) x_drawwinUSD ,
						SUM(CASE WHEN betteam = 'x'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
									  * e.EUR
								 ELSE 0
							END) x_drawwinEUR ,
						SUM(CASE WHEN betteam = 'x'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN 1
											 ELSE odds - 1
										END ) * stake 
									  * e.GBP
								 ELSE 0
							END) x_drawwinGBP ,	
						SUM(CASE WHEN betteam = '1'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
								 ELSE 0
							END) x_homelose ,
						SUM(CASE WHEN betteam = '1'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
									  * e.USD
								 ELSE 0
							END) x_homeloseUSD ,
						SUM(CASE WHEN betteam = '1'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
									  * e.EUR
								 ELSE 0
							END) x_homeloseEUR ,
						SUM(CASE WHEN betteam = '1'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
									  * e.GBP
								 ELSE 0
							END) x_homeloseGBP,	
						SUM(CASE WHEN betteam = '2'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
								 ELSE 0
							END) x_awaylose ,
						SUM(CASE WHEN betteam = '2'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake * e.USD
								 ELSE 0
							END) x_awayloseUSD ,
						SUM(CASE WHEN betteam = '2'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
									  * e.EUR
								 ELSE 0
							END) x_awayloseEUR ,
						SUM(CASE WHEN betteam = '2'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
									  * e.GBP
								 ELSE 0
							END) x_awayloseGBP ,
							
						SUM(CASE WHEN betteam = 'x'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
								 ELSE 0
							END) x_drawlose ,
						SUM(CASE WHEN betteam = 'x'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
									  * e.USD
								 ELSE 0
							END) x_drawloseUSD ,
						SUM(CASE WHEN betteam = 'x'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
									  * e.EUR
								 ELSE 0
							END) x_drawloseEUR ,
						SUM(CASE WHEN betteam = 'x'
									  AND bettype = @BetTypeExHT1x2
								 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
											 ELSE 1
										END ) * stake 
									  * e.GBP
								 ELSE 0
							END) x_drawloseGBP
							,b.bettype
							
              FROM      bettrans b WITH ( NOLOCK )
                        INNER JOIN Match M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                              AND M.EventStatus = 'running'
                        INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
									ON e.exchangeid = b.currency
              WHERE     
						b.recommend IN ( SELECT custid
                                             FROM   @TempAg )
						AND b.bettype IN ( @Bettype1x2, @BettypeHT1x2 ,@BetTypeExHT1x2 )
                        
                        AND LeagueID = @LeagueID
                        AND b.statusID IN ( 0, 1 )                     
                        AND b.tpositiontaking <> 0
              GROUP BY  liveindicator ,
                        b.currency ,
                        m.MatchID ,
                        m.homeid ,
                        m.awayid ,
                        b.liveindicator ,
                        b.LiveHomeScore ,
                        b.LiveAwayScore ,
                        M.ShowTime ,
                        M.MatchCode ,
                        isNeutral,
						b.bettype
            ) x 
			GROUP By  x.MatchID ,
					x.homeid ,
					x.awayid ,
					x.liveindicator ,
					ISNULL(x.LiveHomeScore, 0)   ,
					ISNULL(x.LiveAwayScore, 0)  ,
					x.ShowTime ,
					x.MatchCode ,
					isNeutral,
					CASE WHEN x.bettype =167 THEN 1 ELSE 0 END
GO
GRANT EXECUTE ON [Lrf_Forecast1x2_SelByLeague] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Forecast1x2_SelByLeague] TO [vnteam]
GO					