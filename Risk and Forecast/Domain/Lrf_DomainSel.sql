ALTER PROCEDURE [dbo].[Lrf_DomainSel]
/*    
 Created : <Jacob.Phan>    
 Date : <12/20/2012>
    Task : Get all Lrf Domain (Zone A, Zone B)
    DB  : DB052.bodb_licensee
    Revisions:      
		- 20140812@Don: Add protocol into resultset's column [DomainName]
*/  


AS
	SET NOCOUNT ON
	
	SELECT [Id], [Protocol] + '://' + [DomainName] AS [DomainName], [IsActive]
	FROM LrfDomain WITH(NOLOCK)
	


GO
GRANT EXECUTE ON [dbo].[Lrf_DomainSel] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_DomainSel] TO [vnteam] 



