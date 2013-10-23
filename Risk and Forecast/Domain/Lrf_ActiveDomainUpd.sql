USE [bodb_licensee]
GO

ALTER PROCEDURE [dbo].[Lrf_ActiveDomainUpd]
	@Id INT
AS
/*    
 Created : <Jacob.Phan>    
 Date : <12/20/2012>
    Task : Update Domain Status (Zone A, Zone B)
    DB  : DB052.bodb_licensee
    Revisions:      
*/

	SET NOCOUNT ON
	
	UPDATE LrfDomain WITH (ROWLOCK,UPDLOCK)
	SET IsActive = CASE WHEN Id = @Id THEN 1 ELSE 0 END

GO
GRANT EXECUTE ON [dbo].[Lrf_ActiveDomainUpd] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_ActiveDomainUpd] TO [vnteam] 