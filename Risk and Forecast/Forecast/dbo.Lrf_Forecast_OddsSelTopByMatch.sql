ALTER PROCEDURE [dbo].[Lrf_Forecast_OddsSelTopByMatch]
    @matchid INT ,
    @bettype INT = 1
AS /*
	Created: 20101207@Henry
	Task: Forecast at Lrf Site 
	DB: DB042.bodb02
	Original:Age_Forecast_OddsSelTopByMatch
	
	Revisions: 
			
		
*/
    SET NOCOUNT ON
    SELECT TOP 1
            hdp1 ,
            hdp2 ,
            odds1a ,
            odds2a ,
            odds.livehomescore ,
            odds.liveawayscore ,
            switch ,
            oddsstatus ,
            m.homeid ,
            m.awayid ,
            ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
    FROM    odds WITH ( NOLOCK )
            LEFT JOIN match M WITH ( NOLOCK ) ON odds.matchid = M.matchid
    WHERE   bettype = @bettype
            AND odds.matchid = @matchid
    ORDER BY oddsid DESC

GO

GRANT EXECUTE ON [dbo].[Lrf_Forecast_OddsSelTopByMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_Forecast_OddsSelTopByMatch] TO [vnteam]
GO

