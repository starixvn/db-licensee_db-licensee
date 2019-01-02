/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Forecast_OddsSelTopByMatch]
    @matchid INT ,
    @bettype INT = 1
AS /*
	Created: 20101207@Henry
	Task: Forecast at Lrf Site 
	DB: DB042.bodb02
	Original:Age_Forecast_OddsSelTopByMatch
	
	Revisions: 
                - 20190102@Joseph: Incorporate changes for E-Sports phase 2b [Redmine: #106553]
			
		
*/
    SET NOCOUNT ON
    SELECT TOP 1 
    hdp1 ,
            hdp2 ,
            odds1a ,
            odds2a ,
            livehomescore ,
            liveawayscore ,
            switch ,
            oddsstatus ,
            homeid ,
            awayid ,
            IsNeutral
    FROM(
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

        UNION ALL

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
        FROM    oddsES as odds WITH ( NOLOCK )
                LEFT JOIN match M WITH ( NOLOCK ) ON odds.matchid = M.matchid
        WHERE   bettype = @bettype
                AND odds.matchid = @matchid
    ) Odds
    Order by oddsid DESC

GO


