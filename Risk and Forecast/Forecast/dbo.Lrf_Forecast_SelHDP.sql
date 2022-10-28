/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER  PROCEDURE [dbo].[Lrf_Forecast_SelHDP]    
    @matchid		INT ,
    @bettype		INT = 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(12)= ''
AS /*
Created: 20101207@Henry
Original: Age_Forecast_SelHDP
Task: Forecast for HDP bettype.
DB: DBBOF.bodb02
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
	- 20190611@Amanda: Add Base Currency parameter [Redmine: #112531]
	- 20210224@Mark: Change alias DB042 to DBBOF [Redmine: #150375]
   - 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT> 
*/
BEGIN
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
	
	DECLARE @ExchangeRate AS TABLE (ExchangeId INT, Rate FLOAT)

	INSERT INTO @ExchangeRate(ExchangeId, Rate)
	SELECT ExchangeId, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@Today, @Today, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM @TempAg a WHERE a.Currency = e.ExchangeId)

    SELECT  -x.hdp + score offset ,
            SUM(x.hometotal * 1) 'ht' ,
            SUM(x.awaytotal * 1) 'at' ,
            SUM(( x.homewin - x.awaylose ) * 1) 'al' ,
            SUM(( x.awaywin - x.homelose ) * 1) 'hl'
    FROM    ( SELECT    b.currency ,
                        hdp2 - hdp1 hdp ,
                        livehomescore - liveawayscore score ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN stake  * e.Rate
                                 ELSE 0
                            END) hometotal ,
                        SUM(CASE WHEN betteam = 'a'
                                 THEN stake  * e.Rate
                                 ELSE 0
                            END) awaytotal ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) homewin ,
                        SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN 1
                                             ELSE odds
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) awaywin ,
                        SUM(CASE WHEN betteam = 'h'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) homelose ,
                        SUM(CASE WHEN betteam = 'a'
                                 THEN ( CASE WHEN odds < 0 THEN ABS(odds)
                                             ELSE 1
                                        END ) * stake 
                                      * e.Rate
                                 ELSE 0
                            END) awaylose
              FROM      bettrans b WITH ( NOLOCK )
                        INNER JOIN @ExchangeRate e 
									ON e.exchangeid = b.currency
              WHERE    
						EXISTS ( SELECT 1 FROM @TempAg ag WHERE ag.custid = b.recommend)
						AND bettype = @bettype
                        AND matchid = @matchid
                        AND b.statusID IN ( 0, 1 )
                        AND b.tpositiontaking <> 0
              GROUP BY  b.currency ,
                        hdp2 - hdp1 ,
                        livehomescore - liveawayscore
            ) x
    GROUP BY -x.hdp + score
END

GO