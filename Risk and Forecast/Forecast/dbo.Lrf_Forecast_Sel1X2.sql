/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [Lrf_Forecast_Sel1X2]    
    @matchid		INT ,
    @bettype		INT ,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(12)= ''
AS
 /*
Created by: [20101207@Henry]
Task: Forecast for 1x2 bettype
DB: DBBOF.bodb02
Original: [Age_Forecast_Sel1X2]
Revisions:
	
	
	- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function 
	- 20150123@Jim: support base on Currency GBP
	- 20150420@Jim: support betradar
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20180802@Sophia: HA - remove ruben to use new index on DB042 [Redmine: #98631]
	- 20190611@Amanda: Add Base Currency parameter [Redmine: #112531]
	- 20210224@Mark: Change alias DB042 to DBBOF [Redmine: #150375]
    - 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]


Param's explanation:
	--1:home
	--2:away
	--x:draw

	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT>
*/
BEGIN
    SET NOCOUNT ON
    DECLARE @BetType1x2 SMALLINT ,
			@BetTypeHT1x2 SMALLINT,
			@BetTypeExHT1x2 SMALLINT
    SELECT  @BetType1x2 = 5 ,
            @BetTypeHT1x2 = 15,
			@BetTypeExHT1x2 = 167

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
	
	DECLARE @ExchangeRate AS TABLE (ExchangeId INT, Rate FLOAT)

	INSERT INTO @ExchangeRate(ExchangeId, Rate)
	SELECT ExchangeId, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@Today, @Today, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeId)
	
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
            ( x.homewin - x.awaylose - x.drawlose ) 'hl' ,
            ( x.drawwin - x.awaylose - x.homelose ) 'dl' ,
            ---
			( x.ht_awaywin - x.ht_drawlose - x.ht_homelose ) 'ht_al' ,
            ( x.ht_homewin - x.ht_drawlose - x.ht_awaylose ) 'ht_hl' ,
            ( x.ht_drawwin - x.ht_awaylose - x.ht_homelose ) 'ht_dl' ,
			---
			( x.x_awaywin - x.x_drawlose - x.x_homelose ) 'x_al' ,
            ( x.x_homewin - x.x_drawlose - x.x_awaylose ) 'x_hl' ,
            ( x.x_drawwin - x.x_awaylose - x.x_homelose ) 'x_dl' ,
			--
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
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) homewin ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) awaywin ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) drawwin ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) homelose ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) awaylose ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetType1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) drawlose ,
							---1H 1X2
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) ht_homewin ,

                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) ht_awaywin ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) ht_drawwin ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) ht_homelose ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) ht_awaylose ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) ht_drawlose ,
							---	Extra Time 1H 1X2
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeExHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) x_homewin ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeExHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) x_awaywin ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeExHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds - 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) x_drawwin ,
                        SUM(CASE WHEN betteam = '1'
                                      AND bettype = @BetTypeExHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) x_homelose ,
                        SUM(CASE WHEN betteam = '2'
                                      AND bettype = @BetTypeExHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) x_awaylose ,
                        SUM(CASE WHEN betteam = 'x'
                                      AND bettype = @BetTypeExHT1x2
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds - 1)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) x_drawlose
							,b.bettype
              FROM      bettrans b WITH ( NOLOCK )
                        INNER JOIN Match M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                              AND M.EventStatus = 'running'
                        INNER JOIN @ExchangeRate e 
						ON e.exchangeid = b.currency
              WHERE     
						EXISTS (SELECT 1 from @TempAg ag WHERE ag.custid = b.recommend)
						AND b.bettype = @bettype
                        AND b.matchid = @MatchID
                        AND b.statusID IN ( 0, 1 )                     
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
						,b.bettype
            ) x
END

GO