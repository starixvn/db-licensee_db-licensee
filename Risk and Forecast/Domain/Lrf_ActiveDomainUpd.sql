/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_ActiveDomainUpd]
	@Id INT
AS
/*    
 Created : <Jacob.Phan>    
 Date : <12/20/2012>
    Task : Update Domain Status (Zone A, Zone B)
    DB  : DBCUST-bodb_Licensee
    Revisions:      
	- 20180925@Joseph: Migrate to DBCUST [Feature #99855]
*/

	SET NOCOUNT ON
	
	UPDATE LrfDomain WITH (ROWLOCK,UPDLOCK)
	SET IsActive = CASE WHEN Id = @Id THEN 1 ELSE 0 END

GO