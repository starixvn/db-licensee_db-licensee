CREATE FUNCTION [dbo].[f_VSHorseRacingByBettype]
    ()
    RETURNS @tblBettype TABLE
         (
           Bettype INT 
         )
AS

/*
Created: 20140908@Jim
Task : Get bettype for Virtual Horse Racing
DB: DBEXT/bodb02
Revisions:
    
Param's Explanation:
    
*/

BEGIN
        
    INSERT INTO @tblBettype (Bettype)
    SELECT typeId AS Bettype
    FROM dbo.bettype WITH (NOLOCK)
    WHERE typeId IN (1231, 1232, 1233, 1237, 1238)
    RETURN
    
END

GO 
 GRANT VIEW DEFINITION ON [dbo].[f_VSHorseRacingByBettype] TO [vnteam]
GO 
 GRANT SELECT ON [dbo].[f_VSHorseRacingByBettype] TO [bodbLicenseeNet]
GO 
