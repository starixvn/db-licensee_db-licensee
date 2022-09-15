/*<info serverAlias="DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE  PROCEDURE [dbo].[SiteDB_Lrf_Forecast_SelHDP]    
    @matchid		INT ,
    @bettype		INT = 1,
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(12)= ''
AS /*
Created: 20220729@Victoria
Original: Lrf_Forecast_SelHDP
Task: Forecast for HDP bettype.
DB: DBSID.bodb02
Revisions:

	- 20220729@Victoria: Create SP[Redmine: #175297]
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
	FROM dbo.SiteDB_Lrf_f_GetExchangeRate(@Today, @Today, @BaseCurrency, '') e
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