/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_ReCheckIn]     
	@On_UserID INT,    
	@IsKickedOut BIT = 0 OUTPUT    
AS    
SET NOCOUNT ON    

/*
	Task: ReCheckIN
	DB: DBCUST-bodb_Licensee
	Original SP: On_UserUpd
	
	Revisions:
		- 20101208@Johnny
		- 20120904@Henry: Fix SLOW problem
		- 20180925@Joseph: Migrate to DBCUST [Feature #99855]

*/
   
Declare @OUTPUT TABLE (IsKickedOut bit)
Declare @_On_UserID INT

SET @_On_UserID = @On_UserID

update on_user with (ROWLOCK)
set reload_time = getdate() 
OUTPUT DELETED.IsKickedOut INTO @OUTPUT
where on_userid = @_On_UserID


IF @@ROWCOUNT = 0
	SELECT @IsKickedOut = 1
ELSE IF EXISTS (SELECT 1 FROM @OUTPUT WHERE IsKickedOut = 1)
	SELECT @IsKickedOut = 1
ELSE
	SET @IsKickedOut = 0    
    

GO