 ALTER PROCEDURE [dbo].[Lrf_CustomerUpdMemberComm_Direct]
	@CustID INT,
	@SBComm DECIMAL(9,8) ,
	@NGComm DECIMAL(9,8)=0,	
	@RacingComm DECIMAL(9,8)=0,
	@IsUpdateNG BIT = 0,
	@IsUpdateRacing BIT = 0
AS
/*
Created: 20130114@Henry
Task : Update Licensee's players commission in DBTRANS
DB: DBTRANS.bodb02
Original: 

Revisions:
	
   
Param's Explanation:

*/

UPDATE [dbo].Dep_CustSetting WITH (ROWLOCK, UPDLOCK)
SET playerdiscount = @SBComm 
WHERE custid = @CustID
	AND playerdiscount <> @SBComm  	
	
IF (@IsUpdateNG=1) -- update Number Game
BEGIN	
	UPDATE [dbo].Dep_CustSetting3rd WITH (ROWLOCK, UPDLOCK)
	SET playerdiscount = @NGComm 
	WHERE custid = @CustID
		AND playerdiscount <> @NGComm
		AND sporttype = 161  	
END

IF (@IsUpdateRacing=1) --update racing
BEGIN
	UPDATE [dbo].Dep_CustSetting3rd WITH (ROWLOCK, UPDLOCK)
	SET playerdiscount = @RacingComm 
	WHERE custid = @CustID
		AND playerdiscount <> @RacingComm
		AND sporttype IN (151,152,153)
END			
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMemberComm_Direct] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMemberComm_Direct] TO [bodbLicenseeNet] AS [dbo] 
GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerUpdMemberComm_Direct] TO [Dot_Member] AS [dbo]