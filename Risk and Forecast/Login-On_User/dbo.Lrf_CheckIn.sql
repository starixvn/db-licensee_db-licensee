CREATE PROCEDURE [dbo].[Lrf_CheckIn]
	@CustID INT,
	@NetSessionID VARCHAR(30),
	@ServerID INT,
	@On_UserID INT OUTPUT,
	@IP VARCHAR(15) = ''
AS

/*
	Task: CheckIN
	DB: DB052.bodb_Licensee
	Original SP:LoginDownline_OnUser
	
	Revisions:
		- 20101208@Johnny

*/

--Open SubAccId if required
--if @@servername <> '5WRHH1S'--not kickout at local server for testing
	update on_user with (ROWLOCK) SET IsKickedout=1 WHERE CustID = @CustID AND ServerID = @ServerID

	
insert into on_user
	(custid, NetSessionID, ServerID, IsKickedout, IP)
values
	(@custid, @NetSessionid, @ServerID, 0, @IP)

SELECT @On_UserID = SCOPE_IDENTITY()


GO
GRANT EXECUTE ON [dbo].[Lrf_CheckIn] TO [bodbLicenseeNet] 
GO
GRANT EXECUTE ON [dbo].[Lrf_CheckIn] TO [bodbAdminNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CheckIn] TO [vnteam] 