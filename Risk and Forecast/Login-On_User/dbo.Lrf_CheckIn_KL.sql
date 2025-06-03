/*<info serverAlias="DBCUST-bodb_Licensee" executers="wsv_lap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_CheckIn_KL]
	@CustID INT,
	@NetSessionID VARCHAR(30),
	@ServerID INT,
	@On_UserID INT OUTPUT,
	@IP VARCHAR(15) = ''
AS

/*
	Task: CheckIN
	DB: DBCUST-bodb_Licensee
	Original SP:LoginDownline_OnUser
	
	Revisions:
		- 20101208@Johnny
		- 20180925@Joseph: Migrate to DBCUST [Feature #99855]

*/

--Open SubAccId if required
--if @@servername <> '5WRHH1S'--not kickout at local server for testing
--	update on_user with (ROWLOCK) SET IsKickedout=1 WHERE CustID = @CustID AND ServerID = @ServerID

	
--insert into on_user
--	(custid, NetSessionID, ServerID, IsKickedout, IP)
--values
--	(@custid, @NetSessionid, @ServerID, 0, @IP)

SELECT @On_UserID = SCOPE_IDENTITY()

GO