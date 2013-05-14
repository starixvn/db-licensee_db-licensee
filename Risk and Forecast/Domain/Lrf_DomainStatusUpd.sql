ALTER PROCEDURE [dbo].[Lrf_DomainStatusUpd]
	@Id INT,
	@IsActive BIT = 1
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
	SET IsActive = @IsActive
	WHERE Id = @Id AND IsActive <> @IsActive

GO
GRANT EXECUTE ON [dbo].[Lrf_DomainStatusUpd] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_DomainStatusUpd] TO [vnteam] 



