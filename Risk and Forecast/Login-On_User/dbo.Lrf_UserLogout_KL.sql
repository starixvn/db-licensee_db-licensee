/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_UserLogout_KL]
	@On_UserID INT
AS
SET NOCOUNT ON

/*
	Task: User Logout
	DB: DBCUST-bodb_Licensee
	Original 
	
	Revisions:
		- 20101208@Johnny
		- 20180925@Joseph: Migrate to DBCUST [Feature #99855]

*/
RETURN
--Delete from On_User WHERE on_userid = @On_UserID
