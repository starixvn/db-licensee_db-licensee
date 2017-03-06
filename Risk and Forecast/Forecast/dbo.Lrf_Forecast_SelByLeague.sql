USE bodb02
GO

ALTER  PROCEDURE [dbo].[Lrf_Forecast_SelByLeague]    
    @BaseOffsetHDP		INT ,
    @BaseOffsetOU		INT ,
    @BaseOffsetHTHDP	INT ,
    @BaseOffsetHTOU		INT ,
    @LeagueID			INT ,
	@AgentList			VARCHAR(MAX)
AS /*
Created: 20101207@Henry
Task: Forecast for bettype according to league.
DB: DB052.bodb02
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

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT> 
*/


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
                          AND R.FOffset = -1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_M1_HDPUSD ,
            SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = -1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_M1_HDPEUR ,
				--GBP
			SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = -1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_M1_HDPGBP ,
				
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
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_0_HDPUSD ,
            SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_0_HDPEUR ,
				--GBP
			SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_0_HDPGBP ,
				
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
            SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_1_HDPUSD ,
            SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_1_HDPEUR ,
				--GBP
			SUM(CASE WHEN R.bettype = @BettypeHDP
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_1_HDPGBP ,
				
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
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                END) AS WinLost_0_OUUSD ,
            SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                END) AS WinLost_0_OUEUR ,
				--GBP
			SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                END) AS WinLost_0_OUGBP ,
				
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
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                END) AS WinLost_1_OUUSD ,
            SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                END) AS WinLost_1_OUEUR ,
				--GBP
			SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                END) AS WinLost_1_OUGBP ,
				
            SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 2 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                END) AS WinLost_2_OU ,
            SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 2
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                END) AS WinLost_2_OUUSD ,
            SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 2
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                END) AS WinLost_2_OUEUR ,
				---GBP
			SUM(CASE WHEN R.bettype = @BettypeOU
                          AND R.FOffset = 2
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                END) AS WinLost_2_OUGBP ,
				
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
                          AND R.FOffset = -1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_M1_HTHDPUSD ,
            SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = -1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_M1_HTHDPEUR ,
				---GBP
			SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = -1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_M1_HTHDPGBP ,
				
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
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_0_HTHDPUSD ,
            SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_0_HTHDPEUR ,
				--GBP
			SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_0_HTHDPGBP ,
				
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
            SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_1_HTHDPUSD ,
            SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_1_HTHDPEUR ,
				---GBP
			SUM(CASE WHEN R.bettype = @BettypeHTHDP
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                     ELSE 0
                END) AS WinLost_1_HTHDPGBP ,
				
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
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                END) AS WinLost_0_HTOUUSD ,
            SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                END) AS WinLost_0_HTOUEUR ,
				---GBP
			SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 0
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                END) AS WinLost_0_HTOUGBP ,
				
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
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                END) AS WinLost_1_HTOUUSD ,
            SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                END) AS WinLost_1_HTOUEUR ,
				---GBP
			SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 1
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                END) AS WinLost_1_HTOUGBP ,
				
            SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 2 THEN CASE R.WinLostStatus
                                                   WHEN 1 THEN R.AwayLose / 2
                                                   WHEN 2 THEN R.AwayLose
                                                   WHEN 3 THEN R.HomeLose / 2
                                                   WHEN 4 THEN R.HomeLose
                                                   ELSE 0
                                                 END
                END) AS WinLost_2_HTOU ,
            SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 2
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseUSD / 2
                            WHEN 2 THEN R.AwayLoseUSD
                            WHEN 3 THEN R.HomeLoseUSD / 2
                            WHEN 4 THEN R.HomeLoseUSD
                            ELSE 0
                          END
                END) AS WinLost_2_HTOUUSD ,
            SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 2
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseEUR / 2
                            WHEN 2 THEN R.AwayLoseEUR
                            WHEN 3 THEN R.HomeLoseEUR / 2
                            WHEN 4 THEN R.HomeLoseEUR
                            ELSE 0
                          END
                END) AS WinLost_2_HTOUEUR ,
				--GBP
			SUM(CASE WHEN R.bettype = @BettypeHTOU
                          AND R.FOffset = 2
                     THEN CASE R.WinLostStatus
                            WHEN 1 THEN R.AwayLoseGBP / 2
                            WHEN 2 THEN R.AwayLoseGBP
                            WHEN 3 THEN R.HomeLoseGBP / 2
                            WHEN 4 THEN R.HomeLoseGBP
                            ELSE 0
                          END
                END) AS WinLost_2_HTOUGBP ,
				
            ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
    FROM    ( SELECT    1 AS ForecastID , -- begin R
                        F.bettype ,
                        liveindicator ,
                        '' AS status ,
                        F.offset ,
                        homelose ,
                        awaylose ,
                        homeloseUSD ,
                        awayloseUSD ,
                        homeloseEUR ,
                        awayloseEUR ,
						homeloseGBP ,
                        awayloseGBP ,
						
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
                                    SUM(( x.homewinUSD - x.awayloseUSD )) AS AwayLoseUSD ,
                                    SUM(( x.homewinEUR - x.awayloseEUR )) AS AwayLoseEUR ,
									SUM(( x.homewinGBP - x.awayloseGBP )) AS AwayLoseGBP ,
                                    SUM(( x.awaywin - x.homelose )) AS HomeLose ,
                                    SUM(( x.awaywinUSD - x.homeloseUSD )) AS HomeLoseUSD ,
                                    SUM(( x.awaywinEUR - x.homeloseEUR )) AS HomeLoseEUR ,
									SUM(( x.awaywinGBP - x.homeloseGBP )) AS HomeLoseGBP ,
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
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS homewinUSD ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS homewinEUR ,
													-- GBP
													SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS homewinGBP ,
													
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS awaywinUSD ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS awaywinEUR ,
													-- GBP
													SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS awaywinGBP,
													
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS homeloseUSD ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS homeloseEUR ,
													--GBP
												SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS homeloseGBP,	
													
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS awaylose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS awayloseUSD ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS awayloseEUR ,
													--GBP
												SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS awayloseGBP ,	
													
                                                M.MatchID ,
                                                ISNULL(o.livehomescore, 0)
                                                - ISNULL(o.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(o.livehomescore, 0)
                                                + ISNULL(o.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
														ON e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                INNER JOIN Odds AS O WITH ( NOLOCK ) ON b.OddsID = O.OddsID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     b.recommend IN ( SELECT custid FROM @TempAg )
                                                AND b.bettype = @BetTypeHDP
                                                AND b.statusID IN ( 0, 1 )
                                                AND b.ruben = 0
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
                                    SUM(( x.homewinUSD - x.awayloseUSD )) AS AwayLoseUSD ,
                                    SUM(( x.homewinEUR - x.awayloseEUR )) AS AwayLoseEUR ,
									SUM(( x.homewinGBP - x.awayloseGBP )) AS AwayLoseGBP ,
									
                                    SUM(( x.awaywin - x.homelose )) AS HomeLose ,
                                    SUM(( x.awaywinUSD - x.homeloseUSD )) AS HomeLoseUSD ,
                                    SUM(( x.awaywinEUR - x.homeloseEUR )) AS HomeLoseEUR ,
									SUM(( x.awaywinGBP - x.homeloseGBP )) AS HomeLoseGBP , --here
                                    @BaseOffsetOU AS BaseOffset ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                          FROM      ( SELECT    b.liveindicator ,  -- begin X2
                                                b.currency ,
                                                b.hdp1 AS hdp ,
                                                0 AS score ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS homewinUSD ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS homewinEUR ,
													---GBP
												SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS homewinGBP ,
													
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS awaywinUSD ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS awaywinEUR ,
													--GBP
												SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS awaywinGBP ,	
													
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS homeloseUSD ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS homeloseEUR ,
													--GBP
													SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS homeloseGBP ,
													
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS awaylose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS awayloseUSD ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS awayloseEUR ,
													---GBP
												SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS awayloseGBP ,
													
                                                M.MatchID ,
                                                ISNULL(o.livehomescore, 0)
                                                - ISNULL(o.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(o.livehomescore, 0)
                                                + ISNULL(o.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
														ON  e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                              AND M.EventStatus = 'running'
                                                INNER JOIN Odds AS O WITH ( NOLOCK ) ON b.OddsID = O.OddsID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     b.recommend IN ( SELECT custid FROM @TempAg )
                                                AND b.bettype = @BetTypeOU
                                                AND b.statusID IN ( 0, 1 )
                                                AND b.ruben = 0
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
                                    SUM(( x.homewinUSD - x.awayloseUSD )) AS AwayLoseUSD ,
                                    SUM(( x.homewinEUR - x.awayloseEUR )) AS AwayLoseEUR ,
									SUM(( x.homewinGBP - x.awayloseGBP )) AS AwayLoseGBP ,
									
                                    SUM(( x.awaywin - x.homelose )) AS HomeLose ,
                                    SUM(( x.awaywinUSD - x.homeloseUSD )) AS HomeLoseUSD ,
                                    SUM(( x.awaywinEUR - x.homeloseEUR )) AS HomeLoseEUR ,
									SUM(( x.awaywinGBP - x.homeloseGBP )) AS HomeLoseGBP ,
									
                                    @BaseOffsetHTHDP AS BaseOffset ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                          FROM      ( SELECT --begin x3
				--			status, 
                                                b.currency ,
                                                b.hdp2 - b.hdp1 hdp ,
                                                b.livehomescore
                                                - b.liveawayscore AS score ,
                                                b.liveindicator ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS homewinUSD ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS homewinEUR ,
													--GBP
												SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS homewinGBP ,
													
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS awaywinUSD ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS awaywinEUR ,
													---GBP
												SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS awaywinGBP ,
													
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS homeloseUSD ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS homeloseEUR ,
												--GBP
												SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS homeloseGBP ,
													
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                         ELSE 0
                                                    END) AS awaylose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS awayloseUSD ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS awayloseEUR ,
													---GBP
												SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS awayloseGBP ,
													
                                                M.MatchID ,
                                                ISNULL(o.livehomescore, 0)
                                                - ISNULL(o.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(o.livehomescore, 0)
                                                + ISNULL(o.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
															ON e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                INNER JOIN Odds AS O WITH ( NOLOCK ) ON b.OddsID = O.OddsID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     b.recommend IN ( SELECT custid FROM @TempAg )
                                                AND b.bettype = @BetTypeHTHDP
                                                AND b.statusID IN ( 0, 1 )
                                                AND b.ruben = 0
                                                AND b.tpositiontaking <> 0
                                      GROUP BY 
				--			status, 
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
                                    SUM(( x.homewinUSD - x.awayloseUSD )) AS AwayLoseUSD ,
                                    SUM(( x.homewinEUR - x.awayloseEUR )) AS AwayLoseEUR ,
									SUM(( x.homewinGBP - x.awayloseGBP )) AS AwayLoseGBP ,
									
                                    SUM(( x.awaywin - x.homelose )) AS HomeLose ,
                                    SUM(( x.awaywinUSD - x.homeloseUSD )) AS HomeLoseUSD ,
                                    SUM(( x.awaywinEUR - x.homeloseEUR )) AS HomeLoseEUR ,
									SUM(( x.awaywinGBP - x.homeloseGBP )) AS HomeLoseGBP ,
									
                                    @BaseOffsetHTOU AS BaseOffset ,
                                    MatchID ,
                                    VScoreHDP ,
                                    VScoreOU
                          FROM      ( SELECT    b.liveindicator , -- begin x4
                                                b.currency ,
                                                b.hdp1 AS hdp ,
                                                0 AS score ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS homewin ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS homewinUSD ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS homewinEUR ,
												SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS homewinGBP ,
													
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS awaywin ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS awaywinUSD ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS awaywinEUR ,
												SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN 1
                                                              ELSE odds
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS awaywinGBP ,
													
													
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS homelose ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS homeloseUSD ,
                                                SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS homeloseEUR ,
													---GBP
												SUM(CASE WHEN betteam = 'h'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS homeloseGBP ,
													
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                         ELSE 0
                                                    END) AS awaylose ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.USD
                                                         ELSE 0
                                                    END) AS awayloseUSD ,
                                                SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.EUR
                                                         ELSE 0
                                                    END) AS awayloseEUR ,
												--- GBP
												SUM(CASE WHEN betteam = 'a'
                                                         THEN ( CASE
                                                              WHEN odds < 0
                                                              THEN ABS(odds)
                                                              ELSE 1
                                                              END ) * stake
                                                              
                                                              * e.GBP
                                                         ELSE 0
                                                    END) AS awayloseGBP ,	
													
                                                M.MatchID ,
                                                ISNULL(o.livehomescore, 0)
                                                - ISNULL(o.liveawayscore, 0) AS VScoreHDP ,
                                                ISNULL(o.livehomescore, 0)
                                                + ISNULL(o.liveawayscore, 0) AS VScoreOU
                                      FROM      bettrans AS b WITH ( NOLOCK )
                                                INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today,@Today))e 
															ON e.exchangeid = b.currency
                                                INNER JOIN Match AS M WITH ( NOLOCK ) ON b.MatchID = M.MatchID
                                                              AND M.EventStatus = 'running'
                                                INNER JOIN Odds AS O WITH ( NOLOCK ) ON b.OddsID = O.OddsID
                                                INNER JOIN League AS L WITH ( NOLOCK ) ON M.LeagueID = L.LeagueID
                                                              AND L.LeagueID = @LeagueID
                                      WHERE     b.recommend IN ( SELECT custid FROM @TempAg )
                                                AND b.bettype = @BetTypeHTOU
                                                AND b.statusID IN ( 0, 1 )
                                                AND b.ruben = 0
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



GO
GRANT EXECUTE ON [dbo].[Lrf_Forecast_SelByLeague] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Forecast_SelByLeague] TO [vnteam]
GO

