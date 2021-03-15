/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER  PROCEDURE [dbo].[Lrf_Forecast_SelByLeague]
    @BaseOffsetHDP		INT ,
    @BaseOffsetOU		INT ,
    @BaseOffsetHTHDP	INT ,
    @BaseOffsetHTOU		INT ,
    @LeagueID			INT ,
	@AgentList			VARCHAR(MAX) ,
	@BaseCurrency		VARCHAR(3)= ''
AS 
/*
Created: 20101207@Henry
Task: Forecast for bettype according to league.
DB: DBBOF.bodb02
Original: [Age_Forecast_SelByLeague_Ag]
Revisions: 

	- 20110303@Jacob: Allow to choose all type of licensee AND all currency + suppport based currency	
	- 20110801@Henry: Remove PT + exclude BA ticket
	- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function 
	- 20150123@Jim: support base on Currency GBP
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20180802@Sophia: HA - remove ruben to use new index on DB042 [Redmine: #98631]
    - 20190102@Joseph: Incorporate changes for E-Sports phase 2b [Redmine: #106553]
	- 20190415@Percy: Get livehomescore/liveawayscore data from match table instead of odds table [RedmineID: #113303]
	- 20190611@Amanda: Add Base Currency parameter [Redmine: #112531]
	- 20210224@Mark: Change alias DB042 to DBBOF [Redmine: #150375]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT> 
*/

BEGIN
    SET NOCOUNT ON
    DECLARE @BetTypeHDP INT ,
        @BetTypeOU INT ,
        @VScoreHDP SMALLMONEY ,
        @VScoreOU SMALLMONEY ,
        @BetTypeHTHDP INT ,
        @BetTypeHTOU INT
    SELECT  @BetTypeHDP = 1 ,
            @BetTypeOU = 3 ,
            @BetTypeHTHDP = 7 ,
            @BetTypeHTOU = 8

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

--WinlostStatus: 
--	1: home win 1/2
--	2: home win 1
--	3: home lose 1/2
--	2: home lose 1
--	5: draw
    SELECT  R.MatchID ,
            m.homeid ,
            m.awayid ,
            R.liveindicator ,
            ISNULL(M.LiveHomeScore, 0) AS LiveHomeScore ,
            ISNULL(M.LiveAwayScore, 0) AS LiveAwayScore ,
            M.ShowTime ,
            M.MatchCode ,
            SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = -1 THEN CASE R.WinLostStatus
                                                    WHEN 1 THEN R.AwayLose / 2
                                                    WHEN 2 THEN R.AwayLose
                                                    WHEN 3 THEN R.HomeLose / 2
                                                    WHEN 4 THEN R.HomeLose
                                                    ELSE 0
                                                  END
                     ELSE 0
                END) AS WinLost_M1_HDP ,
				
            SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = 0 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                     ELSE 0
                END) AS WinLost_0_HDP ,
            SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = 1 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                     ELSE 0
                END) AS WinLost_1_HDP ,
            SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 0 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                END) AS WinLost_0_OU ,
            SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 1 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                END) AS WinLost_1_OU ,
            SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 2 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                END) AS WinLost_2_OU ,
            SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = -1 THEN CASE R.WinLostStatus
                                                    WHEN 1 THEN R.AwayLose / 2
                                                    WHEN 2 THEN R.AwayLose
                                                    WHEN 3 THEN R.HomeLose / 2
                                                    WHEN 4 THEN R.HomeLose
                                                    ELSE 0
                                                  END
                     ELSE 0
                END) AS WinLost_M1_HTHDP ,
            SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = 0 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                     ELSE 0
                END) AS WinLost_0_HTHDP ,
            SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = 1 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                     ELSE 0
                END) AS WinLost_1_HTHDP ,
            SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 0 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                END) AS WinLost_0_HTOU ,
            SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 1 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                END) AS WinLost_1_HTOU ,
            SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 2 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                END) AS WinLost_2_HTOU ,
            ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
    FROM    ( SELECT    1 AS ForecastID , -- begin R
                        F.bettype ,
                        liveindicator ,
                        '' AS status ,
                        F.offset ,
                        homelose ,
                        awaylose ,
						
                        BaseOffset + ForecastOffset.offset AS BaseOffset ,
                        CASE WHEN F.BetType IN ( @BetTypeHDP, @BetTypeHTHDP )
                             THEN CASE WHEN F.VScoreHDP + BaseOffset
                                            + ForecastOffset.offset - F.Offset > 0
                                            AND F.VScoreHDP + BaseOffset
                                            + ForecastOffset.offset - F.Offset < 0.5
                                       THEN 1
                                       WHEN F.VScoreHDP + BaseOffset
                                            + ForecastOffset.offset - F.Offset > 0.25
                                       THEN 2
                                       WHEN F.VScoreHDP + BaseOffset
                                            + ForecastOffset.offset - F.Offset < 0
                                            AND F.VScoreHDP + BaseOffset
                                            + ForecastOffset.offset - F.Offset > -0.5
                                       THEN 3
                                       WHEN F.VScoreHDP + BaseOffset
                                            + ForecastOffset.offset - F.Offset < -0.25
                                       THEN 4
                                       ELSE 5
                                  END
                             WHEN F.BetType IN ( @BetTypeOU, @BetTypeHTOU )
                             THEN CASE WHEN F.VScoreOU + BaseOffset
                                            + ForecastOffset.offset - F.Offset = 0.25
                                       THEN 1
                                       WHEN F.VScoreOU + BaseOffset
                                            + ForecastOffset.offset - F.Offset > 0.25
                                       THEN 2
                                       WHEN F.VScoreOU + BaseOffset
                                            + ForecastOffset.offset - F.Offset = -0.25
                                       THEN 3
                                       WHEN F.VScoreOU + BaseOffset
                                            + ForecastOffset.offset - F.Offset < -0.25
                                       THEN 4
                                       ELSE 5
                                  END
                        END AS WinlostStatus ,
                        F.MatchID ,
                        ForecastOffset.Offset AS fOffset
              FROM      ( SELECT    @BetTypeHDP AS bettype , -- begin F
                                    x.liveindicator ,
                                    -x.hdp + score AS offset ,
                                    SUM(( x.homewin - x.awaylose )) AS AwayLose ,
                                    SUM(( x.awaywin - x.homelose )) AS HomeLose ,
                                    @BaseOffsetHDP AS BaseOffset ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                          FROM      ( SELECT    b.currency , -- begin X1
                                                b.hdp2 - b.hdp1 AS hdp ,
                                                b.livehomescore
                                                - b.liveawayscore AS score ,
                                                b.liveindicator ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaylose ,	
                                                M.MatchID ,
                                                ISNULL(m.livehomescore, 0)
                                                - ISNULL(m.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(m.livehomescore, 0)
                                                + ISNULL(m.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN @ExchangeRate e 
														ON e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     EXISTS ( SELECT 1 FROM @TempAg ag WHERE ag.custid = b.recommend )
                                                AND b.bettype = @BetTypeHDP
                                                AND b.statusID IN ( 0, 1 )                                               
                                                AND b.tpositiontaking <>0
                                      GROUP BY  b.currency ,
                                                b.hdp2 - b.hdp1 ,
                                                b.livehomescore
                                                - b.liveawayscore ,
                                                b.liveindicator ,
                                                M.MatchID ,
                                                m.livehomescore ,
                                                m.liveawayscore
                                    UNION ALL 
                                    -- OddsES
                                    SELECT    b.currency , -- begin X1
                                                b.hdp2 - b.hdp1 AS hdp ,
                                                b.livehomescore
                                                - b.liveawayscore AS score ,
                                                b.liveindicator ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaylose ,
                                                M.MatchID ,
                                                ISNULL(o.livehomescore, 0)
                                                - ISNULL(o.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(o.livehomescore, 0)
                                                + ISNULL(o.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN @ExchangeRate e 
														ON e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                INNER JOIN OddsES AS O WITH ( NOLOCK ) ON b.OddsID = O.OddsID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     EXISTS ( SELECT 1 FROM @TempAg ag WHERE ag.custid = b.recommend )
                                                AND b.bettype = @BetTypeHDP
                                                AND b.statusID IN ( 0, 1 )                                               
                                                AND b.tpositiontaking <>0
                                      GROUP BY  b.currency ,
                                                b.hdp2 - b.hdp1 ,
                                                b.livehomescore
                                                - b.liveawayscore ,
                                                b.liveindicator ,
                                                M.MatchID ,
                                                o.livehomescore ,
                                                o.liveawayscore

                                    ) AS x -- end X1
                          GROUP BY  -x.hdp + score ,
                                    x.liveindicator ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                          UNION ALL
                          SELECT    @BetTypeOU AS bettype ,
                                    x.liveindicator ,
                                    x.hdp + score AS offset ,
                                    SUM(( x.homewin - x.awaylose )) AS AwayLose ,
									
                                    SUM(( x.awaywin - x.homelose )) AS HomeLose ,
                                    @BaseOffsetOU AS BaseOffset ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                          FROM      ( SELECT    b.liveindicator ,  -- begin X2
                                                b.currency ,
                                                b.hdp1 AS hdp ,
                                                0 AS score ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaylose ,
                                                M.MatchID ,
                                                ISNULL(m.livehomescore, 0)
                                                - ISNULL(m.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(m.livehomescore, 0)
                                                + ISNULL(m.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN @ExchangeRate e 
														ON  e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                              AND M.EventStatus = 'running'
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     EXISTS ( SELECT 1 FROM @TempAg ag WHERE ag.custid = b.recommend )
                                                AND b.bettype = @BetTypeOU
                                                AND b.statusID IN ( 0, 1 )
                                                AND b.tpositiontaking <> 0
                                      GROUP BY  b.currency ,
                                                b.hdp1 ,
                                                b.liveindicator ,
                                                M.MatchID ,
                                                m.livehomescore ,
                                                m.liveawayscore
                                    UNION ALL 
                                    -- OddsES
                                    SELECT    b.liveindicator ,  -- begin X2
                                                b.currency ,
                                                b.hdp1 AS hdp ,
                                                0 AS score ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaylose ,
                                                M.MatchID ,
                                                ISNULL(o.livehomescore, 0)
                                                - ISNULL(o.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(o.livehomescore, 0)
                                                + ISNULL(o.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN @ExchangeRate e 
														ON  e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                              AND M.EventStatus = 'running'
                                                INNER JOIN OddsES AS O WITH ( NOLOCK ) ON b.OddsID = O.OddsID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     EXISTS ( SELECT 1 FROM @TempAg ag WHERE ag.custid = b.recommend )
                                                AND b.bettype = @BetTypeOU
                                                AND b.statusID IN ( 0, 1 )
                                                AND b.tpositiontaking <> 0
                                      GROUP BY  b.currency ,
                                                b.hdp1 ,
                                                b.liveindicator ,
                                                M.MatchID ,
                                                o.livehomescore ,
                                                o.liveawayscore
                                    ) AS x --- end X2
                          GROUP BY  liveindicator ,
                                    x.score ,
                                    x.hdp ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
--FIRST HALF HERE----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                          UNION ALL
                          SELECT    @BetTypeHTHDP AS bettype ,
                                    x.liveindicator ,
                                    -x.hdp + score AS offset ,
                                    SUM(( x.homewin - x.awaylose )) AS AwayLose ,
									
                                    SUM(( x.awaywin - x.homelose )) AS HomeLose ,
									
                                    @BaseOffsetHTHDP AS BaseOffset ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                          FROM      ( SELECT --begin x3
                                                b.currency ,
                                                b.hdp2 - b.hdp1 hdp ,
                                                b.livehomescore
                                                - b.liveawayscore AS score ,
                                                b.liveindicator ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaylose ,
                                                M.MatchID ,
                                                ISNULL(m.livehomescore, 0)
                                                - ISNULL(m.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(m.livehomescore, 0)
                                                + ISNULL(m.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN @ExchangeRate e 
															ON e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     EXISTS ( SELECT 1 FROM @TempAg ag WHERE ag.custid = b.recommend )
                                                AND b.bettype = @BetTypeHTHDP
                                                AND b.statusID IN ( 0, 1 )                                                
                                                AND b.tpositiontaking <> 0
                                      GROUP BY 
                                                b.currency ,
                                                b.hdp2 - b.hdp1 ,
                                                b.livehomescore
                                                - b.liveawayscore ,
                                                b.liveindicator ,
                                                M.MatchID ,
                                                m.livehomescore ,
                                                m.liveawayscore
                                    UNION ALL
                                    -- OddsES
                                    SELECT --begin x3
                                                b.currency ,
                                                b.hdp2 - b.hdp1 hdp ,
                                                b.livehomescore
                                                - b.liveawayscore AS score ,
                                                b.liveindicator ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaylose ,
                                                M.MatchID ,
                                                ISNULL(o.livehomescore, 0)
                                                - ISNULL(o.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(o.livehomescore, 0)
                                                + ISNULL(o.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN @ExchangeRate e 
															ON e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                INNER JOIN OddsES AS O WITH ( NOLOCK ) ON b.OddsID = O.OddsID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     EXISTS ( SELECT 1 FROM @TempAg ag WHERE ag.custid = b.recommend )
                                                AND b.bettype = @BetTypeHTHDP
                                                AND b.statusID IN ( 0, 1 )                                                
                                                AND b.tpositiontaking <> 0
                                      GROUP BY 
                                                b.currency ,
                                                b.hdp2 - b.hdp1 ,
                                                b.livehomescore
                                                - b.liveawayscore ,
                                                b.liveindicator ,
                                                M.MatchID ,
                                                o.livehomescore ,
                                                o.liveawayscore
                                    ) AS x -- end x3
                          GROUP BY 
				--	x.status, 
                                    -x.hdp + score ,
                                    x.liveindicator ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                          UNION ALL
                          SELECT    @BetTypeHTOU AS bettype ,
                                    x.liveindicator , 
				--	x.status, 
                                    x.hdp + score AS offset ,
                                    SUM(( x.homewin - x.awaylose )) AS AwayLose ,
									
                                    SUM(( x.awaywin - x.homelose )) AS HomeLose ,
									
                                    @BaseOffsetHTOU AS BaseOffset ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                          FROM      ( SELECT    b.liveindicator , -- begin x4
                                                b.currency ,
                                                b.hdp1 AS hdp ,
                                                0 AS score ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaylose ,
													
                                                M.MatchID ,
                                                ISNULL(m.livehomescore, 0)
                                                - ISNULL(m.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(m.livehomescore, 0)
                                                + ISNULL(m.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN @ExchangeRate e 
															ON e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                              AND M.EventStatus = 'running'
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     EXISTS ( SELECT 1 FROM @TempAg ag WHERE ag.custid = b.recommend )
                                                AND b.bettype = @BetTypeHTOU
                                                AND b.statusID IN ( 0, 1 )                                              
                                                AND b.tpositiontaking <> 0
                                      GROUP BY  b.currency ,
                                                b.hdp1 ,
                                                b.liveindicator ,
                                                M.MatchID ,
                                                m.livehomescore ,
                                                m.liveawayscore
                                    
                                    UNION ALL
                                    -- OddsES
                                    SELECT    b.liveindicator , -- begin x4
                                                b.currency ,
                                                b.hdp1 AS hdp ,
                                                0 AS score ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN 1 ELSE odds END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE WHEN odds < 0 THEN ABS(odds) ELSE 1 END ) * stake * e.Rate
                                                         ELSE 0
                                                    END) AS awaylose ,	
													
                                                M.MatchID ,
                                                ISNULL(o.livehomescore, 0)
                                                - ISNULL(o.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(o.livehomescore, 0)
                                                + ISNULL(o.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN @ExchangeRate e 
															ON e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                              AND M.EventStatus = 'running'
                                                INNER JOIN OddsES AS O WITH ( NOLOCK ) ON b.OddsID = O.OddsID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     EXISTS ( SELECT 1 FROM @TempAg ag WHERE ag.custid = b.recommend )
                                                AND b.bettype = @BetTypeHTOU
                                                AND b.statusID IN ( 0, 1 )                                              
                                                AND b.tpositiontaking <> 0
                                      GROUP BY  b.currency ,
                                                b.hdp1 ,
                                                b.liveindicator ,
                                                M.MatchID ,
                                                o.livehomescore ,
                                                o.liveawayscore
                                    ) AS x -- end x4
                          GROUP BY  liveindicator ,
                                    x.score ,
                                    x.hdp ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                        ) AS F  --- end F
                        INNER JOIN ( SELECT 1 AS bettype ,
                                            -1 AS offset
                                     UNION ALL
                                     SELECT 1 AS bettype ,
                                            0 AS offset
                                     UNION ALL
                                     SELECT 1 AS bettype ,
                                            1 AS offset
                                     UNION ALL
                                     SELECT 3 AS bettype ,
                                            0 AS offset
                                     UNION ALL
                                     SELECT 3 AS bettype ,
                                            1 AS offset
                                     UNION ALL
                                     SELECT 3 AS bettype ,
                                            2 AS offset
                                     UNION ALL
                                     SELECT 7 AS bettype ,
                                            -1 AS offset
                                     UNION ALL
                                     SELECT 7 AS bettype ,
                                            0 AS offset
                                     UNION ALL
                                     SELECT 7 AS bettype ,
                                            1 AS offset
                                     UNION ALL
                                     SELECT 8 AS bettype ,
                                            0 AS offset
                                     UNION ALL
                                     SELECT 8 AS bettype ,
                                            1 AS offset
                                     UNION ALL
                                     SELECT 8 AS bettype ,
                                            2 AS offset
                                   ) AS ForecastOffset ON F.bettype = ForecastOffset.bettype
            ) AS R -- end R
            INNER JOIN Match AS M WITH ( NOLOCK ) ON R.MatchID = M.MatchID
    GROUP BY R.MatchID ,
            R.liveindicator ,
            m.homeid ,
            m.awayid ,
            M.LiveHomeScore ,
            M.LiveAwayScore ,
            M.ShowTime ,
            M.MatchCode ,
            m.isNeutral
    ORDER BY R.LiveIndicator DESC ,
            M.MatchCode
END

GO
 