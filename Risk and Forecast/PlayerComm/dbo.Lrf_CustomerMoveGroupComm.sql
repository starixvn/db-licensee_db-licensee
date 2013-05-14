set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_CustomerMoveGroupComm]
	@LicenseeID INT,
	@strCustID VARCHAR(MAX),--member
	@UserID INT,
	@GroupCommID INT,
	@IsUpdateNG BIT = 0,
	@IsUpdateRacing BIT = 0,
	@IP VARCHAR(40),
	@Langkey VARCHAR(20) = 'en-US',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg varchar(8000) = '' OUTPUT
AS

/*
Created: 20120726@Henry
Task : Update Commission of Player
DB: DB052.bodb_Licensee

Revisions:
	-20130412@jim:support multiple language
Param's Explanation:
*/ 

EXEC [Lrf_CustomerUpdMemberComm] @LicenseeID=@LicenseeID,@strCustID=@strCustID,@UserID=@UserID,@GroupCommID=@GroupCommID,@IsUpdateNG=@IsUpdateNG,@IsUpdateRacing=@IsUpdateRacing,@Langkey=@Langkey,@IP=@IP,@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT

GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerMoveGroupComm] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerMoveGroupComm] TO [vnteam] 

