/*<info serverAlias="DB042-bodb02,DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LeagueSelRunning]
		@AgentList		VARCHAR(MAX),   
    	@Bettypes		VARCHAR(100) = '0',--0: all, 1:1,3,7,8; 5:5,15 
    	@IsIncludeTestLeague 	BIT = 0
AS     

/*
Created: 20101207@Henry
Original: [Age_LeagueSelRunning_Ag]
Task: SELECT running Leagues for 1,3,5,7,8, AND 15 bet types
DB: DB042.bodb02
Revisions: 
	- 20110513@Henry: change @Bettypes from VARCHAR(20) to VARCHAR(100)
	- 20121004@Jim: replace @currencyname input param by @currencyID
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150414@Jim: add more bettype Extra Time 1H 1X2 (feature #32844)
	- 20170227@Harper: LRF - Get data by @AgentList instead of @UserID [RedmineID: #71679]
	- 20190104@Joseph: Add param @IsIncludeTestLeague to exclude test leagues[Redmine: #107473]
	- 20220801@Victoria: Add DBSID-bodb02 to metadata [Redmine: #175297]

Param's Explanation:
	+ @AgentList: xml structure
					<ROOT>
					<Agent AgentId="12345" Currency="3"/>  
					<Agent AgentId="12345" Currency="5"/>  
					</ROOT> 
*/
	SET NOCOUNT ON

    SELECT  @Bettypes = CASE @Bettypes
                          WHEN '0' THEN '1,3,7,8,5,15'
                          WHEN '1' THEN '1,3,7,8'
                          WHEN '5' THEN '5,15,167'
                          ELSE '1,3,7,8,5,15,167'
                        END 
	
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

    	SELECT  match.leagueid ,
            	match.sporttype
    	FROM    league WITH ( NOLOCK )
            	INNER JOIN match WITH ( NOLOCK ) ON league.leagueid = match.leagueid
    	WHERE   (@IsIncludeTestLeague = 1 OR league.isTest = 0 )
    		AND match.eventstatus IN ( 'running' )
            	AND match.matchid IN (
            	SELECT DISTINCT
                    	matchid
            	FROM    bettrans b WITH ( NOLOCK )
            	WHERE   b.recommend IN ( SELECT custid
                                     FROM   @TempAg )
                    	AND bettype IN ( SELECT val
                                     FROM   dbo.strSplit_Key(@Bettypes, ',') )
                    	AND statusid IN ( 0, 1 ) )
    	GROUP BY match.leagueid ,
            	league.leaguename ,
            	match.sporttype
    	ORDER BY league.leaguename
GO