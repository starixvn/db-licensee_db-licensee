ALTER PROCEDURE [dbo].[Lrf_LeagueSelRunning]
    @LicenseeID INT ,
    @LicenseeType VARCHAR(100) = NULL ,
	@UserID		INT,
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
	- 20130514@Jim:Restrict permission of Licensee Users by currency
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
	- 20150414@Jim: add more bettype Extra Time 1H 1X2 (feature #32844)
*/

    SELECT  @Bettypes = CASE @Bettypes
                          WHEN '0' THEN '1,3,7,8,5,15'
                          WHEN '1' THEN '1,3,7,8'
                          WHEN '5' THEN '5,15,167'
                          ELSE '1,3,7,8,5,15'
                        END 
	
	SELECT  currencyID,LicenseeID into #currency
	FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
	WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))
	
	DECLARE @TempAg AS TABLE ( CustId INT )
    INSERT  INTO @TempAg
            ( CustId
            )
            SELECT  DISTINCT CustID  
			FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc --WITH ( NOLOCK )
					INNER JOIN #currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
			WHERE    [Description] = COALESCE(@LicenseeType,  
										 [Description])
	----------------------
	DROP TABLE #currency
	----------------------
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
