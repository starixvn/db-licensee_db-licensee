ALTER PROCEDURE [dbo].[Lrf_ReCheckIn]     
	@On_UserID INT,    
	@IsKickedOut BIT = 0 OUTPUT    
AS    
SET NOCOUNT ON    


/*
	Task: ReCheckIN
	DB: DB052.bodb_Licensee
	Original SP: On_UserUpd
	
	Revisions:
		- 20101208@Johnny
		- 20120904@Henry: Fix SLOW problem

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
GRANT EXECUTE ON [dbo].[Lrf_ReCheckIn] TO [bodbLicenseeNet] 
GO
GRANT EXECUTE ON [dbo].[Lrf_ReCheckIn] TO [bodbAdminNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_ReCheckIn] TO [vnteam] 