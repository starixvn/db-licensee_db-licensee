ALTER PROCEDURE [dbo].[Lrf_LeagueSelRunning]
    @LicenseeID INT ,
    @LicenseeType VARCHAR(100) = NULL ,
    @CurrencyID INT=0,
    @Bettypes VARCHAR(100) = '0'--0: all, 1:1,3,7,8; 5:5,15 
AS 
    SET NOCOUNT ON

/*
Created: 20101207@Henry
Original: [Age_LeagueSelRunning_Ag]
Task: SELECT running Leagues for 1,3,5,7,8, AND 15 bet types
DB: DB052.bodb02
Revisions: 
	- 20110513@Henry: change @Bettypes from VARCHAR(20) to VARCHAR(100)
	- 20121004@Jim: replace @currencyname input param by @currencyID
*/

    SELECT  @Bettypes = CASE @Bettypes
                          WHEN '0' THEN '1,3,7,8,5,15'
                          WHEN '1' THEN '1,3,7,8'
                          WHEN '5' THEN '5,15'
                          ELSE '1,3,7,8,5,15'
                        END 

	DECLARE @TempAg AS TABLE ( CustId INT )
    INSERT  INTO @TempAg
            ( CustId
            )
            SELECT  CustID  
			FROM    bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )  
			WHERE   LicenseeID = @LicenseeID  
			AND  (@CurrencyID=0 OR (@CurrencyID <> 0 AND  Currency = @CurrencyID))
			AND [Description] = COALESCE(@LicenseeType,  
										 [Description])
	
    SELECT  match.leagueid ,
            match.sporttype
    FROM    league WITH ( NOLOCK )
            INNER JOIN match WITH ( NOLOCK ) ON league.leagueid = match.leagueid
    WHERE   match.eventstatus IN ( 'running' )
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

GRANT EXECUTE ON [dbo].[Lrf_LeagueSelRunning] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LeagueSelRunning] TO [vnteam]
GO
