ALTER PROCEDURE [dbo].[Lrf_SportSel]

AS
/*
Created: 20140331@Winnie
Task: https://redmine.nexcel.vn/issues/13401
DB: DB052.bodb_Licensee
Original: 
Revisions:

*/

SET NOCOUNT ON

SELECT DISTINCT sporttype,sportname  
FROM bodb02.dbo.sports WITH (NOLOCK)
WHERE sporttype < 99
ORDER BY sporttype, sportname

GO

GRANT EXECUTE ON [Lrf_SportSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_SportSel] TO [vnteam]
GO