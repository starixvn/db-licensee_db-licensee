CREATE PROCEDURE [dbo].[Lrf_IPOfficeSel]

AS
/*
 *	Created: 20120403@Jacob
 *	Task : Location restriction
 *	DB: DBTrans.IPDB
 *
 *	Revisions:	
	
*/
SET NOCOUNT ON

SELECT [IP], [Remark]
FROM [dbo].[IPOffice]
GO
GRANT EXECUTE ON [dbo].[Lrf_IPOfficeSel] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_IPOfficeSel] TO [vnteam]