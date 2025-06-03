/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_ReCheckIn_KL]     
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
   
SET @IsKickedOut = 0       
GO